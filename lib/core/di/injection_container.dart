import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/claude_service.dart';
import '../../features/bio_twin/data/datasources/bio_twin_local_data_source.dart';
import '../../features/bio_twin/data/datasources/bio_twin_remote_data_source.dart';
import '../../features/bio_twin/data/repositories/bio_twin_repository_impl.dart';
import '../../features/bio_twin/domain/repositories/bio_twin_repository.dart';
import '../../features/bio_arbitrage/domain/repositories/bio_arbitrage_repository.dart';
import '../../features/aeg_graph/data/datasources/aeg_local_data_source.dart';
import '../../features/food_scan/data/datasources/food_scan_local_data_source.dart';
import '../database/database_helper.dart';
import '../database/daos/bio_twin_dao.dart';
import '../database/daos/aeg_graph_dao.dart';
import '../database/daos/food_scan_dao.dart';

import 'package:health/health.dart';
import '../services/health/health_sync_service.dart';
import '../services/health/background_sync_worker.dart';
import '../permissions/permission_manager.dart';
import '../network/network_info.dart';
import '../services/cloud/firestore_service.dart';
import '../services/cloud/cloud_sync_service.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../network/circuit_breaker.dart';
import '../services/ai_cache_service.dart';
import '../database/daos/supplement_dao.dart';
import '../services/circadian_sync_service.dart';
import '../services/protocol_engine.dart';
import '../services/ai_debate_engine.dart';

// Database Layer
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

final bioTwinDaoProvider = Provider<BioTwinDao>((ref) {
  return BioTwinDao(dbHelper: ref.watch(databaseHelperProvider));
});

final aegGraphDaoProvider = Provider<AEGGraphDao>((ref) {
  return AEGGraphDao(dbHelper: ref.watch(databaseHelperProvider));
});

final foodScanDaoProvider = Provider<FoodScanDao>((ref) {
  return FoodScanDao(dbHelper: ref.watch(databaseHelperProvider));
});

final supplementDaoProvider = Provider<SupplementDao>((ref) {
  return SupplementDao(dbHelper: ref.watch(databaseHelperProvider));
});

// Cloud & Sync Layer
final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfoImpl();
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  return CloudSyncService(
    networkInfo: ref.watch(networkInfoProvider),
    firestoreService: ref.watch(firestoreServiceProvider),
    bioTwinDao: ref.watch(bioTwinDaoProvider),
  );
});

// Auth Layer
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl();
});

// Platform Services
final healthProvider = Provider<Health>((ref) {
  return Health();
});
final healthFactoryProvider = healthProvider;

final permissionManagerProvider = Provider<PermissionManager>((ref) {
  return PermissionManager(health: ref.watch(healthProvider));
});

// AI Resilience Layer
final circuitBreakerProvider = Provider<CircuitBreaker>((ref) {
  return CircuitBreaker(maxFailures: 3, resetTimeout: const Duration(minutes: 5));
});

final aiCacheServiceProvider = Provider<AiCacheService>((ref) {
  return AiCacheService(cacheTTL: const Duration(hours: 24));
});

// Core Services
final claudeServiceProvider = Provider<ClaudeService>((ref) {
  return ClaudeService(
    circuitBreaker: ref.watch(circuitBreakerProvider),
    aiCacheService: ref.watch(aiCacheServiceProvider),
  );
});

final healthSyncServiceProvider = Provider<HealthSyncService>((ref) {
  return HealthSyncService(
    health: ref.watch(healthProvider),
    permissionManager: ref.watch(permissionManagerProvider),
  );
});

final backgroundSyncWorkerProvider = Provider<BackgroundSyncWorker>((ref) {
  return BackgroundSyncWorker(
    health: ref.watch(healthProvider),
    healthSyncService: ref.watch(healthSyncServiceProvider),
  );
});

final circadianSyncServiceProvider = Provider<CircadianSyncService>((ref) {
  return CircadianSyncService(health: ref.watch(healthProvider));
});

final protocolEngineProvider = Provider<ProtocolEngine>((ref) {
  return ProtocolEngine();
});

final aiDebateEngineProvider = Provider<AiDebateEngine>((ref) {
  return AiDebateEngine(claudeService: ref.watch(claudeServiceProvider));
});

// Data Sources - Bio Twin
final bioTwinLocalDataSourceProvider = Provider<BioTwinLocalDataSource>((ref) {
  return BioTwinLocalDataSourceImpl(dao: ref.watch(bioTwinDaoProvider));
});

final bioTwinRemoteDataSourceProvider = Provider<BioTwinRemoteDataSource>((ref) {
  final aiService = ref.watch(claudeServiceProvider);
  return BioTwinRemoteDataSourceImpl(aiService: aiService);
});

// Data Sources - AEG Graph
final aegLocalDataSourceProvider = Provider<AEGLocalDataSource>((ref) {
  return AEGLocalDataSourceImpl(dao: ref.watch(aegGraphDaoProvider));
});

// Data Sources - Food Scan
final foodScanLocalDataSourceProvider = Provider<FoodScanLocalDataSource>((ref) {
  return FoodScanLocalDataSourceImpl(dao: ref.watch(foodScanDaoProvider));
});

// Repositories - Bio Twin
final bioTwinRepositoryProvider = Provider<BioTwinRepository>((ref) {
  return BioTwinRepositoryImpl(
    remoteDataSource: ref.watch(bioTwinRemoteDataSourceProvider),
    localDataSource: ref.watch(bioTwinLocalDataSourceProvider),
  );
});

// Repositories - Bio Arbitrage
final bioArbitrageRepositoryProvider = Provider<BioArbitrageRepository>((ref) {
  return BioArbitrageRepositoryImpl();
});
