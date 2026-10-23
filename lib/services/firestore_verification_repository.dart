import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account.dart';
import '../models/sign_up_data.dart';
import 'verification_repository.dart';

/// Verification in Cloud Firestore:
/// - `verificationRequests/{uid}`: written by the athlete, read by them and
///   reviewers.
/// - `verifiedAthletes/{uid}`: written by reviewers, readable by members
///   (so anyone can show the ✓). Deleted with the account.
class FirestoreVerificationRepository implements VerificationRepository {
  FirestoreVerificationRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _verified(String uid) =>
      _db.collection('verifiedAthletes').doc(uid);
  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('verificationRequests');

  @override
  Future<bool> isVerified(String uid) async {
    try {
      return (await _verified(uid).get()).exists;
    } on FirebaseException {
      return false;
    }
  }

  @override
  Future<VerificationRequest?> myRequest(Account me) async {
    final data = (await _requests.doc(me.uid).get()).data();
    return data == null ? null : _requestFrom(me.uid, data);
  }

  @override
  Future<void> requestVerification(
    Account me,
    AthleteCategory programme, {
    String note = '',
  }) => _requests.doc(me.uid).set({
    'athleteId': me.athleteId,
    'name': me.profile.name,
    'sport': me.profile.sportName,
    'programme': programme.name,
    'note': note.trim(),
    'createdAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> withdrawRequest(Account me) => _requests.doc(me.uid).delete();

  @override
  Future<bool> canVerify(String uid) async {
    Future<bool> listed(String collection) async {
      try {
        return (await _db.collection(collection).doc(uid).get()).exists;
      } on FirebaseException {
        return false;
      }
    }

    final results = await Future.wait([
      listed('moderators'),
      listed('organisers'),
    ]);
    return results.any((r) => r);
  }

  @override
  Future<List<VerificationRequest>> pendingRequests() async {
    final snapshot = await _requests.orderBy('createdAt').get();
    return [for (final d in snapshot.docs) _requestFrom(d.id, d.data())];
  }

  @override
  Future<void> approve(VerificationRequest request, Account reviewer) async {
    final batch = _db.batch()
      ..set(_verified(request.uid), {
        'programme': request.programme.name,
        'verifiedBy': reviewer.uid,
        'verifiedAt': FieldValue.serverTimestamp(),
      })
      ..delete(_requests.doc(request.uid));
    await batch.commit();
  }

  @override
  Future<void> decline(VerificationRequest request) =>
      _requests.doc(request.uid).delete();

  static VerificationRequest _requestFrom(String uid, Map<String, dynamic> d) =>
      VerificationRequest(
        uid: uid,
        athleteId: d['athleteId'] as String? ?? '',
        name: d['name'] as String? ?? '',
        sport: d['sport'] as String?,
        programme: AthleteCategory.values.firstWhere(
          (c) => c.name == d['programme'],
          orElse: () => AthleteCategory.national,
        ),
        note: d['note'] as String? ?? '',
        createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}
