import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/subscription_tier.dart';

class _CachedSub {
  final UserSubscription? subscription;
  final DateTime fetchedAt;
  _CachedSub(this.subscription, this.fetchedAt);
}

/// Reads `subscriptions/{userId}` for background services (sentinels, orchestrators)
/// that do not have access to [SubscriptionProvider].
class SubscriptionEntitlementResolver {
  SubscriptionEntitlementResolver._();
  static final SubscriptionEntitlementResolver instance =
      SubscriptionEntitlementResolver._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, _CachedSub> _cache = {};
  static const Duration _ttl = Duration(seconds: 45);

  void invalidate(String userId) => _cache.remove(userId);

  Future<UserSubscription?> getSubscription(String userId) async {
    if (userId.isEmpty) return null;
    final now = DateTime.now();
    final hit = _cache[userId];
    if (hit != null && now.difference(hit.fetchedAt) < _ttl) {
      return hit.subscription;
    }
    try {
      final doc = await _db.collection('subscriptions').doc(userId).get();
      if (!doc.exists || doc.data() == null) {
        _cache[userId] = _CachedSub(null, now);
        return null;
      }
      final data = Map<String, dynamic>.from(doc.data()!);
      data.putIfAbsent('userId', () => userId);
      final sub = UserSubscription.fromJson(data);
      _cache[userId] = _CachedSub(sub, now);
      return sub;
    } catch (e) {
      debugPrint('⚠️ SubscriptionEntitlementResolver: $e');
      return null;
    }
  }

  /// Active Ultra: correct tier, active flag, not past [UserSubscription.endDate].
  Future<bool> isActiveUltra(String userId) async {
    final s = await getSubscription(userId);
    if (s == null) return false;
    return s.tier == SubscriptionTier.ultra && s.isActive && !s.hasExpired;
  }

  Future<bool> isFreeTier(String userId) async {
    final s = await getSubscription(userId);
    if (s == null) return true;
    return s.isFree;
  }

  /// Premium or Ultra with active, non-expired subscription.
  Future<bool> isActivePremium(String userId) async {
    final s = await getSubscription(userId);
    if (s == null) return false;
    return s.isPremium;
  }

  /// Premium+: glucose nexus, wearables, family hub, GlucoCoach.
  Future<bool> hasGlucoseNexusPro(String userId) async {
    final s = await getSubscription(userId);
    if (s == null) return false;
    if (!s.isActive || s.hasExpired) return false;
    return s.tier == SubscriptionTier.premium || s.tier == SubscriptionTier.ultra;
  }

  /// Premium or Ultra with active, non-expired subscription.
  Future<bool> hasGlucoCoach(String userId) async {
    final s = await getSubscription(userId);
    if (s == null) return false;
    if (!s.isActive || s.hasExpired) return false;
    return s.tier == SubscriptionTier.premium || s.tier == SubscriptionTier.ultra;
  }

  /// Starter+ paid tiers (excludes expired/inactive).
  Future<bool> hasPaidTier(String userId) async {
    final s = await getSubscription(userId);
    if (s == null) return false;
    if (!s.isActive || s.hasExpired) return false;
    return s.tier != SubscriptionTier.free;
  }

  /// Background glucose watch + GlucoCoach LLM — Premium+ only.
  Future<bool> canUseBackgroundHealthAgent(String userId) async {
    return hasGlucoCoach(userId);
  }
}
