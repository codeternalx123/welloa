import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:longevity/core/services/cloud/cloud_sync_service.dart';
import 'package:longevity/core/network/network_info.dart';
import 'package:longevity/core/services/cloud/firestore_service.dart';
import 'package:longevity/core/database/daos/bio_twin_dao.dart';
import 'package:longevity/features/bio_twin/data/models/bio_twin_model.dart';

class MockNetworkInfo extends Mock implements NetworkInfo {}
class MockFirestoreService extends Mock implements FirestoreService {}
class MockBioTwinDao extends Mock implements BioTwinDao {}

void main() {
  late CloudSyncService syncService;
  late MockNetworkInfo mockNetworkInfo;
  late MockFirestoreService mockFirestoreService;
  late MockBioTwinDao mockBioTwinDao;

  setUp(() {
    mockNetworkInfo = MockNetworkInfo();
    mockFirestoreService = MockFirestoreService();
    mockBioTwinDao = MockBioTwinDao();

    syncService = CloudSyncService(
      networkInfo: mockNetworkInfo,
      firestoreService: mockFirestoreService,
      bioTwinDao: mockBioTwinDao,
    );
  });

  final tBioTwinModel = BioTwinModel(
    id: 'test_id',
    compiledAt: DateTime.now(),
    chronologicalAge: 30.0,
    biologicalAge: 28.0,
    ageGap: 2.0,
    reversalRateMonthsPerYear: 1.5,
    hallmarkScores: const [],
    keyBioMarkers: const [],
    trajectory: 'improving',
    sixMonthProjection: const [],
  );

  group('CloudSyncService', () {
    test('should not query DAO or Firestore when offline', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => false);

      await syncService.forceSync();

      verify(() => mockNetworkInfo.isConnected).called(1);
      verifyNever(() => mockBioTwinDao.getLatestBioTwin());
      verifyNever(() => mockFirestoreService.setData(path: any(named: 'path'), data: any(named: 'data')));
    });

    test('should query DAO but do nothing if DAO returns null', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockBioTwinDao.getLatestBioTwin()).thenAnswer((_) async => null);

      await syncService.forceSync();

      verify(() => mockNetworkInfo.isConnected).called(1);
      verify(() => mockBioTwinDao.getLatestBioTwin()).called(1);
      verifyNever(() => mockFirestoreService.setData(path: any(named: 'path'), data: any(named: 'data')));
    });

    test('should fetch latest BioTwin from DAO and push to Firestore when online', () async {
      when(() => mockNetworkInfo.isConnected).thenAnswer((_) async => true);
      when(() => mockBioTwinDao.getLatestBioTwin()).thenAnswer((_) async => tBioTwinModel);
      when(() => mockFirestoreService.setData(path: any(named: 'path'), data: any(named: 'data')))
          .thenAnswer((_) async => Future.value());

      await syncService.forceSync();

      verify(() => mockNetworkInfo.isConnected).called(1);
      verify(() => mockBioTwinDao.getLatestBioTwin()).called(1);
      verify(() => mockFirestoreService.setData(
            path: 'users/current_user_id/bio_twins/\${tBioTwinModel.id}',
            data: tBioTwinModel.toJson(),
          )).called(1);
    });
  });
}
