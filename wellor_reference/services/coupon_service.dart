import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Result of a coupon code validation
class CouponValidationResult {
  final bool isValid;
  final String? couponId;
  final String? creatorId;
  final String? creatorName;
  final String code;
  final String discountType; // 'percent' or 'fixed'
  final double discountValue;
  final String? errorMessage;

  const CouponValidationResult({
    required this.isValid,
    this.couponId,
    this.creatorId,
    this.creatorName,
    required this.code,
    this.discountType = 'percent',
    this.discountValue = 0,
    this.errorMessage,
  });

  /// Calculate discounted price
  double getDiscountedPrice(double originalPrice) {
    if (!isValid) return originalPrice;
    if (discountType == 'percent') {
      return (originalPrice * (1 - discountValue / 100)).clamp(0, originalPrice);
    } else {
      return (originalPrice - discountValue).clamp(0, originalPrice);
    }
  }

  /// Human-readable discount description
  String get discountDescription {
    if (discountType == 'percent') {
      return '${discountValue.toInt()}% off';
    }
    return '\$${discountValue.toStringAsFixed(2)} off';
  }
}

/// Service for validating and applying coupon codes, shared between app and Partner Hub
class CouponService {
  static final CouponService _instance = CouponService._();
  factory CouponService() => _instance;
  CouponService._();

  final _firestore = FirebaseFirestore.instance;

  /// Validate a coupon code against Firestore
  Future<CouponValidationResult> validateCoupon(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      return CouponValidationResult(
        isValid: false,
        code: normalizedCode,
        errorMessage: 'Please enter a coupon code',
      );
    }

    try {
      // 1. Check couponCodes collection (Partner Hub generated coupons)
      final couponQuery = await _firestore
          .collection('couponCodes')
          .where('code', isEqualTo: normalizedCode)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (couponQuery.docs.isNotEmpty) {
        final doc = couponQuery.docs.first;
        final data = doc.data();

        // Check max uses
        final maxUses = data['maxUses'] as int?;
        final currentUses = (data['currentUses'] as num?)?.toInt() ?? 0;
        if (maxUses != null && currentUses >= maxUses) {
          return CouponValidationResult(
            isValid: false,
            code: normalizedCode,
            errorMessage: 'This coupon has reached its maximum uses',
          );
        }

        // Check expiry (coupon codes don't expire per requirements, but support it if set)
        final expiryDate = data['expiryDate'] as Timestamp?;
        if (expiryDate != null && expiryDate.toDate().isBefore(DateTime.now())) {
          return CouponValidationResult(
            isValid: false,
            code: normalizedCode,
            errorMessage: 'This coupon has expired',
          );
        }

        // Check if current user already used this coupon
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final usageCheck = await _firestore
              .collection('couponRedemptions')
              .where('userId', isEqualTo: user.uid)
              .where('couponId', isEqualTo: doc.id)
              .limit(1)
              .get();
          if (usageCheck.docs.isNotEmpty) {
            return CouponValidationResult(
              isValid: false,
              code: normalizedCode,
              errorMessage: 'You have already used this coupon',
            );
          }
        }

        // Get creator name
        final creatorId = data['creatorId'] as String?;
        String? creatorName;
        if (creatorId != null) {
          final creatorDoc = await _firestore.collection('creators').doc(creatorId).get();
          if (creatorDoc.exists) {
            creatorName = creatorDoc.data()?['displayName'] as String?;
          }
        }

        return CouponValidationResult(
          isValid: true,
          couponId: doc.id,
          creatorId: creatorId,
          creatorName: creatorName,
          code: normalizedCode,
          discountType: data['discountType'] as String? ?? 'percent',
          discountValue: (data['discountValue'] as num?)?.toDouble() ?? 10,
        );
      }

      // 2. Fallback: Check creator's primary couponCode field
      final creatorQuery = await _firestore
          .collection('creators')
          .where('couponCode', isEqualTo: normalizedCode)
          .limit(1)
          .get();

      if (creatorQuery.docs.isNotEmpty) {
        final creatorDoc = creatorQuery.docs.first;
        final creatorData = creatorDoc.data();
        final commissionRate = (creatorData['commissionRate'] as num?)?.toDouble() ?? 20;
        // Creator's primary coupon gives a discount equal to half their commission rate (min 5%, max 20%)
        final discount = (commissionRate / 2).clamp(5.0, 20.0);

        // Check if current user already used this coupon
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final usageCheck = await _firestore
              .collection('couponRedemptions')
              .where('userId', isEqualTo: user.uid)
              .where('couponCode', isEqualTo: normalizedCode)
              .limit(1)
              .get();
          if (usageCheck.docs.isNotEmpty) {
            return CouponValidationResult(
              isValid: false,
              code: normalizedCode,
              errorMessage: 'You have already used this coupon',
            );
          }
        }

        return CouponValidationResult(
          isValid: true,
          creatorId: creatorDoc.id,
          creatorName: creatorData['displayName'] as String?,
          code: normalizedCode,
          discountType: 'percent',
          discountValue: discount,
        );
      }

      return CouponValidationResult(
        isValid: false,
        code: normalizedCode,
        errorMessage: 'Invalid coupon code',
      );
    } catch (e) {
      debugPrint('Coupon validation error: $e');
      return CouponValidationResult(
        isValid: false,
        code: normalizedCode,
        errorMessage: 'Could not validate coupon. Check your connection.',
      );
    }
  }

  /// Record a coupon redemption after successful payment
  Future<void> recordRedemption({
    required CouponValidationResult coupon,
    required String planId,
    required String planName,
    required double originalPrice,
    required double discountedPrice,
    required String billingPeriod,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !coupon.isValid) return;

    try {
      final now = Timestamp.now();

      // 1. Record the redemption
      await _firestore.collection('couponRedemptions').add({
        'userId': user.uid,
        'userEmail': user.email,
        'couponId': coupon.couponId,
        'couponCode': coupon.code,
        'creatorId': coupon.creatorId,
        'planId': planId,
        'planName': planName,
        'originalPrice': originalPrice,
        'discountedPrice': discountedPrice,
        'discountAmount': originalPrice - discountedPrice,
        'discountType': coupon.discountType,
        'discountValue': coupon.discountValue,
        'billingPeriod': billingPeriod,
        'redeemedAt': now,
      });

      // 2. Increment coupon usage
      if (coupon.couponId != null) {
        await _firestore.collection('couponCodes').doc(coupon.couponId).update({
          'currentUses': FieldValue.increment(1),
          'revenue': FieldValue.increment(discountedPrice),
        });
      }

      // 3. Record commission for the creator
      if (coupon.creatorId != null) {
        // Get creator's commission rate
        final creatorDoc = await _firestore.collection('creators').doc(coupon.creatorId!).get();
        final commissionRate = (creatorDoc.data()?['commissionRate'] as num?)?.toDouble() ?? 20;
        final commissionAmount = discountedPrice * (commissionRate / 100);

        await _firestore.collection('commissionLedger').add({
          'creatorId': coupon.creatorId,
          'userId': user.uid,
          'userEmail': user.email,
          'type': 'earned',
          'amount': commissionAmount,
          'planId': planId,
          'planName': planName,
          'billingPeriod': billingPeriod,
          'couponCode': coupon.code,
          'attributionMethod': 'coupon',
          'status': 'pending',
          'createdAt': now,
        });

        // 4. Update creator's pending balance
        await _firestore.collection('creators').doc(coupon.creatorId!).update({
          'pendingBalance': FieldValue.increment(commissionAmount),
          'totalReferrals': FieldValue.increment(1),
          'activeReferrals': FieldValue.increment(1),
        });

        // 5. Record attribution event
        await _firestore.collection('attributionEvents').add({
          'creatorId': coupon.creatorId,
          'userId': user.uid,
          'email': user.email,
          'method': 'coupon',
          'couponCode': coupon.code,
          'planId': planId,
          'amount': discountedPrice,
          'commission': commissionAmount,
          'createdAt': now,
        });
      }

      debugPrint('✅ Coupon redemption recorded: ${coupon.code}');
    } catch (e) {
      debugPrint('Error recording coupon redemption: $e');
    }
  }
}
