import 'package:flutter_riverpod/flutter_riverpod.dart';

class DnaData {
  final String mthfr;
  final String actn3;
  final String apoe4;
  final String fto;

  DnaData({
    this.mthfr = 'Impaired',
    this.actn3 = 'Sprinter',
    this.apoe4 = 'Variant Found',
    this.fto = 'High Responder',
  });

  DnaData copyWith({
    String? mthfr,
    String? actn3,
    String? apoe4,
    String? fto,
  }) {
    return DnaData(
      mthfr: mthfr ?? this.mthfr,
      actn3: actn3 ?? this.actn3,
      apoe4: apoe4 ?? this.apoe4,
      fto: fto ?? this.fto,
    );
  }
}

class DnaDataNotifier extends StateNotifier<DnaData> {
  DnaDataNotifier() : super(DnaData());

  void updateDnaData(String mthfr, String actn3, String apoe4, String fto) {
    state = state.copyWith(mthfr: mthfr, actn3: actn3, apoe4: apoe4, fto: fto);
  }
}

final dnaDataProvider = StateNotifierProvider<DnaDataNotifier, DnaData>((ref) {
  return DnaDataNotifier();
});
