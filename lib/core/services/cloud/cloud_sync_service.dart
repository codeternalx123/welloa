import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../network/network_info.dart';
import 'firestore_service.dart';
import '../../database/daos/bio_twin_dao.dart';

class CloudSyncService {
  final NetworkInfo networkInfo;
  final FirestoreService firestoreService;
  final BioTwinDao bioTwinDao;

  Timer? _syncTimer;

  CloudSyncService({
    required this.networkInfo,
    required this.firestoreService,
    required this.bioTwinDao,
  });

  /// Starts a periodic background check to sync local database to Firestore
  void startSyncQueue() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 15), (timer) async {
      await _processSyncQueue();
    });
    debugPrint('CloudSyncService: Sync queue started.');
  }

  void stopSyncQueue() {
    _syncTimer?.cancel();
  }

  Future<void> _processSyncQueue() async {
    final isConnected = await networkInfo.isConnected;
    if (!isConnected) {
      debugPrint('CloudSyncService: Offline. Skipping sync.');
      return;
    }

    try {
      debugPrint('CloudSyncService: Online. Processing sync queue...');
      
      // Example: Sync latest BioTwin to cloud
      final latestTwin = await bioTwinDao.getLatestBioTwin();
      if (latestTwin != null) {
        // Assume userId is fetched securely via Auth Layer
        const userId = 'current_user_id'; 
        await firestoreService.setData(
          path: 'users/\$userId/bio_twins/\${latestTwin.id}',
          data: latestTwin.toJson(), // Requires BioTwinModel to have toJson() implemented or mapped
        );
        debugPrint('CloudSyncService: Synced BioTwin \${latestTwin.id} to Firestore.');
      }
      
    } catch (e) {
      debugPrint('CloudSyncService: Error during sync: \$e');
    }
  }

  /// Forces an immediate sync to the cloud
  Future<void> forceSync() async {
    await _processSyncQueue();
  }
}
