import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_provider.dart';
import '../../features/home/presentation/widgets/upgrade_modal_bottom_sheet.dart';

final aiTrialProvider = Provider<AiTrialService>((ref) {
  final tier = ref.watch(profileProvider.select((p) => p.tier));
  return AiTrialService(tier);
});

class AiTrialService {
  final SubscriptionTier currentTier;
  
  AiTrialService(this.currentTier);

  Future<bool> canUseAIFeature(BuildContext context, {String featureKey = 'general'}) async {
    // If premium or ultra, always allow
    if (currentTier != SubscriptionTier.freemium) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final usedCount = prefs.getInt('ai_trial_used_$featureKey') ?? 0;
    
    final maxTrials = featureKey == 'nutrition' ? 3 : 1;

    if (usedCount < maxTrials) {
      // Consume the trial
      await prefs.setInt('ai_trial_used_$featureKey', usedCount + 1);
      
      if (context.mounted && featureKey == 'nutrition') {
        final remaining = maxTrials - (usedCount + 1);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nutrition AI: $remaining trial(s) remaining.', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.cyanAccent.shade700));
      }
      return true;
    } else {
      // Trial used up, show upgrade modal
      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const UpgradeModalBottomSheet(),
        );
      }
      return false;
    }
  }
}
