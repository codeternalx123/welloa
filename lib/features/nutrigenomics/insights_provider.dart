import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'insights_models.dart';

class PharmacogenomicState {
  final bool isLoading;
  final PharmacogenomicResult? result;
  final String? error;

  const PharmacogenomicState({this.isLoading = false, this.result, this.error});

  PharmacogenomicState copyWith({bool? isLoading, PharmacogenomicResult? result, String? error}) {
    return PharmacogenomicState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      error: error,
    );
  }
}

class PharmacogenomicNotifier extends StateNotifier<PharmacogenomicState> {
  PharmacogenomicNotifier() : super(const PharmacogenomicState());

  Future<void> runGeneticSynthesis() async {
    state = state.copyWith(isLoading: true, error: null);
    await Future.delayed(const Duration(seconds: 2));

    final profile = [
      EnzymeProfile(geneName: 'CYP1A2', genotype: '*1F/*1F', metabolizerStatus: 'Rapid', impactDescription: 'Rapid metabolizer of caffeine and certain polyphenols. Faster clearance requires higher or more frequent routine for therapeutic effect.'),
      EnzymeProfile(geneName: 'CYP3A4', genotype: '*22/*22', metabolizerStatus: 'Poor', impactDescription: 'Significantly reduced enzyme activity. High risk of toxicity with quercetin and curcumin; requires drastic intake reduction.'),
      EnzymeProfile(geneName: 'COMT', genotype: 'Val158Met (A/A)', metabolizerStatus: 'Slow', impactDescription: 'Slow clearance of catecholamines. High sensitivity to stress and stimulants like EGCG (Green Tea Extract).'),
    ];

    final guidanceList = [
      PhytochemicalInsights(
        compoundName: 'Quercetin',
        standardIntakeMg: 500.0,
        personalizedIntakeMg: 150.0,
        responsibleEnzyme: 'CYP3A4',
        adjustmentRationale: '70% intake reduction required due to CYP3A4 Poor Metabolizer status to prevent hepatotoxicity and prolonged systemic accumulation.',
        riskLevel: 'Monitor',
      ),
      PhytochemicalInsights(
        compoundName: 'Caffeine / Chlorogenic Acid',
        standardIntakeMg: 100.0,
        personalizedIntakeMg: 200.0,
        responsibleEnzyme: 'CYP1A2',
        adjustmentRationale: 'Intake doubled. Rapid metabolizer status clears the compound too quickly to achieve optimal hormetic AMPK activation at standard intakes.',
        riskLevel: 'Safe',
      ),
      PhytochemicalInsights(
        compoundName: 'EGCG (Green Tea Extract)',
        standardIntakeMg: 400.0,
        personalizedIntakeMg: 0.0,
        responsibleEnzyme: 'COMT',
        adjustmentRationale: 'CAUTION ADVISED. Slow COMT clearance combined with EGCG will severely disrupt catecholamine breakdown, leading to sustained anxiety and HRV suppression.',
        riskLevel: 'Caution Advised',
      ),
    ];

    final result = PharmacogenomicResult(
      id: const Uuid().v4(),
      analyzedAt: DateTime.now(),
      geneticProfile: profile,
      tailoredGuidances: guidanceList,
    );

    state = state.copyWith(isLoading: false, result: result);
  }
}

final pharmacogenomicProvider = StateNotifierProvider<PharmacogenomicNotifier, PharmacogenomicState>((ref) => PharmacogenomicNotifier());
