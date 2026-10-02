class TribeMember {
  final String userId;
  final String displayName;
  final String avatarUrl;
  final double currentBioAge;
  final double currentChronoAge;
  final double paceOfAging;
  final int streakDays;

  const TribeMember({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.currentBioAge,
    required this.currentChronoAge,
    required this.paceOfAging,
    required this.streakDays,
  });

  double get ageGap => currentBioAge - currentChronoAge;

  factory TribeMember.fromJson(Map<String, dynamic> json) {
    return TribeMember(
      userId: json['userId'],
      displayName: json['displayName'],
      avatarUrl: json['avatarUrl'] ?? '',
      currentBioAge: (json['currentBioAge'] as num).toDouble(),
      currentChronoAge: (json['currentChronoAge'] as num).toDouble(),
      paceOfAging: (json['paceOfAging'] as num).toDouble(),
      streakDays: json['streakDays'] as int,
    );
  }
}
