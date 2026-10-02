import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../features/social/domain/models/tribe_member.dart';

class TribeFirestoreService {
  final FirebaseFirestore _firestore;

  TribeFirestoreService(this._firestore);

  /// Streams the top 50 members ranked by best pace of aging
  Stream<List<TribeMember>> streamGlobalLeaderboard() {
    return _firestore
        .collection('users')
        .orderBy('paceOfAging', descending: false) // Lower pace is better
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TribeMember.fromJson(doc.data())).toList();
    });
  }

  /// Streams members of a specific private tribe
  Stream<List<TribeMember>> streamTribeLeaderboard(String tribeId) {
    return _firestore
        .collection('tribes')
        .doc(tribeId)
        .collection('members')
        .orderBy('ageGap', descending: false) // Most negative age gap (biological younger than chrono)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TribeMember.fromJson(doc.data())).toList();
    });
  }

  /// Broadcasts a user's latest metrics to their tribe
  Future<void> updateMyMetrics(String userId, double bioAge, double chronoAge, double pace) async {
    await _firestore.collection('users').doc(userId).update({
      'currentBioAge': bioAge,
      'currentChronoAge': chronoAge,
      'paceOfAging': pace,
      'lastSync': FieldValue.serverTimestamp(),
    });
  }
}
