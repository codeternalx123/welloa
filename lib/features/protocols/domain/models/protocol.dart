import 'supplement.dart';

class LongevityProtocol {
  final String id;
  final String name;
  final String objective;
  final List<Supplement> supplements;
  final bool isCircadianSynced;

  const LongevityProtocol({
    required this.id,
    required this.name,
    required this.objective,
    required this.supplements,
    this.isCircadianSynced = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'objective': objective,
        'supplements': supplements.map((e) => e.toJson()).toList(),
        'isCircadianSynced': isCircadianSynced ? 1 : 0,
      };

  factory LongevityProtocol.fromJson(Map<String, dynamic> json) {
    return LongevityProtocol(
      id: json['id'],
      name: json['name'],
      objective: json['objective'],
      supplements: (json['supplements'] as List)
          .map((e) => Supplement.fromJson(e as Map<String, dynamic>))
          .toList(),
      isCircadianSynced: (json['isCircadianSynced'] == 1 || json['isCircadianSynced'] == true),
    );
  }
}
