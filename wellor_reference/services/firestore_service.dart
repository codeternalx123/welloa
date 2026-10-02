import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// UNICORN GRADE: Centralized Data Orchestration Service.
/// Features: Atomic Batching, Type-Safe Generic CRUD, and Intelligent Caching.
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  static FirestoreService get instance => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Expose FirebaseFirestore instance for advanced usage
  FirebaseFirestore get db => _db;
  CollectionReference<Map<String, dynamic>> collection(String path) => _db.collection(path);
  WriteBatch batch() => _db.batch();
  
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction) transactionHandler,
  ) async {
    return _db.runTransaction(transactionHandler);
  }

  // ============================================
  // CORE CONFIGURATION
  // ============================================

  /// Initializes Firestore with optimized 2026 settings.
  void initialize() {
    _db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // ============================================
  // TYPE-SAFE GENERIC CRUD (The Lead Dev Moat)
  // ============================================

  /// Fetches a single document transformed into a clean Model.
  Future<T?> getDocument<T>({
    required String collectionPath,
    required String docId,
    required T Function(Map<String, dynamic> data) fromMap,
  }) async {
    try {
      final doc = await _db.collection(collectionPath).doc(docId).get();
      if (doc.exists && doc.data() != null) {
        return fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Firestore Fetch Error [$collectionPath/$docId]: $e');
      rethrow;
    }
  }

  /// Streams a collection with real-time reactive transformation.
  Stream<List<T>> streamCollection<T>({
    required String path,
    required T Function(Map<String, dynamic> data) fromMap,
    Query Function(Query query)? queryBuilder,
  }) {
    Query query = _db.collection(path);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  /// High-performance Upsert (Update or Insert) with Merge.
  Future<void> setData({
    required String path,
    required Map<String, dynamic> data,
    bool merge = true,
  }) async {
    final reference = _db.doc(path);
    debugPrint('💾 Firestore Write: $path');
    await reference.set(data, SetOptions(merge: merge));
  }

  // ============================================
  // ATOMIC TRANSACTIONS (The Safety Net)
  // ============================================

  /// Executes multiple operations as a single atomic unit.
  /// Critical for updating metabolic logs and user balances simultaneously.
  Future<void> performBatchUpdate(List<BatchOperation> operations) async {
    final batch = _db.batch();

    for (var op in operations) {
      final ref = _db.doc(op.path);
      switch (op.type) {
        case BatchType.set:
          batch.set(ref, op.data!, SetOptions(merge: true));
          break;
        case BatchType.update:
          batch.update(ref, op.data!);
          break;
        case BatchType.delete:
          batch.delete(ref);
          break;
      }
    }

    await batch.commit();
    debugPrint('⚡ Firestore: Atomic Batch of ${operations.length} committed.');
  }

  // ============================================
  // UTILITIES
  // ============================================

  String generateId(String collectionPath) => _db.collection(collectionPath).doc().id;
}

// ============================================
// MODELS FOR ATOMIC OPERATIONS
// ============================================

enum BatchType { set, update, delete }

class BatchOperation {
  final String path;
  final Map<String, dynamic>? data;
  final BatchType type;

  BatchOperation.set(this.path, this.data) : type = BatchType.set;
  BatchOperation.update(this.path, this.data) : type = BatchType.update;
  BatchOperation.delete(this.path) : data = null, type = BatchType.delete;
}