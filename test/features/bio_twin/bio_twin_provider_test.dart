import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:longevity/features/bio_twin/bio_twin_provider.dart';
import 'package:longevity/features/bio_twin/domain/repositories/bio_twin_repository.dart';
import 'package:longevity/features/bio_twin/domain/entities/bio_twin_entity.dart';
import 'package:longevity/core/error/failures.dart';

class FakeBioTwinRepository implements BioTwinRepository {
  final bool shouldFail;

  FakeBioTwinRepository({this.shouldFail = false});

  @override
  Future<Either<Failure, BioTwinEntity>> compileAndCacheBioTwin(double chronoAge, Map<String, dynamic> biometrics) async {
    if (shouldFail) {
      return Left(ServerFailure('API failed'));
    }
    return Right(BioTwinEntity(
      id: 'test-id',
      compiledAt: DateTime.now(),
      chronologicalAge: chronoAge,
      biologicalAge: 30.0,
      ageGap: 5.0,
      reversalRateMonthsPerYear: 2.5,
      trajectory: 'reversing',
      hallmarkScores: const [],
      keyBioMarkers: const [],
      sixMonthProjection: const [],
    ));
  }

  @override
  Future<Either<Failure, BioTwinEntity>> getLatestCompiledTwin() async {
    return Left(CacheFailure('No cache'));
  }
}

void main() {
  group('BioTwinNotifier Tests', () {
    test('initial state is correct', () {
      final repository = FakeBioTwinRepository();
      final notifier = BioTwinNotifier(repository: repository);

      expect(notifier.state.isLoading, false);
      expect(notifier.state.result, isNull);
      expect(notifier.state.error, isNull);
    });

    test('compileTwin updates state correctly on success', () async {
      final repository = FakeBioTwinRepository();
      final notifier = BioTwinNotifier(repository: repository);

      final future = notifier.compileTwin(chronoAge: 35.0, biometrics: {});
      
      // While running, isLoading should be true
      expect(notifier.state.isLoading, true);
      
      await future;

      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, isNull);
      expect(notifier.state.result, isNotNull);
      expect(notifier.state.result!.biologicalAge, 30.0);
    });

    test('compileTwin updates state correctly on failure', () async {
      final repository = FakeBioTwinRepository(shouldFail: true);
      final notifier = BioTwinNotifier(repository: repository);

      await notifier.compileTwin(chronoAge: 35.0, biometrics: {});

      expect(notifier.state.isLoading, false);
      expect(notifier.state.result, isNull);
      expect(notifier.state.error, 'API failed');
    });
  });
}
