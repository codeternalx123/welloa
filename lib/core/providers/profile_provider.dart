import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SubscriptionTier {
  freemium,
  premium,
  ultra,
}

class UserProfile {
  final int age;
  final double weight;
  final SubscriptionTier tier;

  const UserProfile({
    this.age = 30,
    this.weight = 70.0,
    this.tier = SubscriptionTier.freemium,
  });

  UserProfile copyWith({
    int? age,
    double? weight,
    SubscriptionTier? tier,
  }) {
    return UserProfile(
      age: age ?? this.age,
      weight: weight ?? this.weight,
      tier: tier ?? this.tier,
    );
  }
}

class ProfileNotifier extends StateNotifier<UserProfile> {
  ProfileNotifier() : super(const UserProfile());

  void updateAge(int newAge) {
    state = state.copyWith(age: newAge);
  }

  void updateWeight(double newWeight) {
    state = state.copyWith(weight: newWeight);
  }

  void updateTier(SubscriptionTier newTier) {
    state = state.copyWith(tier: newTier);
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, UserProfile>((ref) {
  return ProfileNotifier();
});
