import 'package:cloud_firestore/cloud_firestore.dart';
import '../../error/failures.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance {
    // Enable offline persistence
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  /// Sets data to a document, merging with existing data.
  /// Handles offline caching natively through Firestore.
  Future<void> setData({
    required String path,
    required Map<String, dynamic> data,
    bool merge = true,
  }) async {
    try {
      final reference = _firestore.doc(path);
      await reference.set(data, SetOptions(merge: merge));
    } catch (e) {
      throw ServerFailure('Failed to set data at \$path: \$e');
    }
  }

  /// Adds a document to a collection and returns the generated ID.
  Future<String> addData({
    required String path,
    required Map<String, dynamic> data,
  }) async {
    try {
      final reference = _firestore.collection(path);
      final docRef = await reference.add(data);
      return docRef.id;
    } catch (e) {
      throw ServerFailure('Failed to add data at \$path: \$e');
    }
  }

  /// Streams a single document in real-time.
  Stream<Map<String, dynamic>?> documentStream({required String path}) {
    try {
      final reference = _firestore.doc(path);
      final snapshots = reference.snapshots();
      return snapshots.map((snapshot) => snapshot.data());
    } catch (e) {
      throw ServerFailure('Failed to create stream for \$path: \$e');
    }
  }

  /// Streams a collection based on a query.
  Stream<List<Map<String, dynamic>>> collectionStream({
    required String path,
    Query Function(Query query)? queryBuilder,
  }) {
    try {
      Query query = _firestore.collection(path);
      if (queryBuilder != null) {
        query = queryBuilder(query);
      }
      final snapshots = query.snapshots();
      return snapshots.map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Inject document ID
          return data;
        }).toList();
      });
    } catch (e) {
      throw ServerFailure('Failed to create stream for collection \$path: \$e');
    }
  }

  /// Deletes a document.
  Future<void> deleteData({required String path}) async {
    try {
      final reference = _firestore.doc(path);
      await reference.delete();
    } catch (e) {
      throw ServerFailure('Failed to delete data at \$path: \$e');
    }
  }
}
