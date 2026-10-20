import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/privacy_config.dart';
import '../models/account.dart';
import '../models/display_mode.dart';
import '../models/sign_up_data.dart';
import 'profile_repository.dart';

/// Profiles in Cloud Firestore (Singapore region, asia-southeast1).
///
/// Two collections, enforced by `firestore.rules`:
/// - `users/{uid}`: the full private profile, readable only by its owner.
/// - `athleteIds/{athleteId}`: the public ID card, with no date of birth,
///   readable one ID at a time and never listable.
///
/// Email, phone and passwords are not stored here; Firebase Auth holds them.
class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _cards =>
      _db.collection('athleteIds');

  @override
  Future<Account?> load(String uid) async {
    final data = (await _users.doc(uid).get()).data();
    if (data == null) return null;
    final profile = _profileFrom(data)
      ..dateOfBirth = (data['dateOfBirth'] as Timestamp).toDate()
      ..method = _enum(SignUpMethod.values, data['signUpMethod'])
      ..consentGivenAt =
          (data['consent']?['acceptedAt'] as Timestamp?)?.toDate()
      ..displayMode =
          _enum(DisplayMode.values, data['displayMode']) ?? DisplayMode.standard;
    return Account(
      uid: uid,
      athleteId: data['athleteId'] as String,
      profile: profile,
      joinedAt: _date(data['createdAt']),
    );
  }

  @override
  Future<Account> create(String uid, SignUpData profile) async {
    final dob = profile.dateOfBirth!;
    final dobUtc = DateTime.utc(dob.year, dob.month, dob.day);
    for (var attempt = 0; attempt < 5; attempt++) {
      final athleteId = newAthleteId();
      final created = await _db.runTransaction<bool>((tx) async {
        final card = _cards.doc(athleteId);
        if ((await tx.get(card)).exists) return false;
        tx.set(card, {
          'ownerUid': uid,
          ..._publicFields(profile),
          'joinedAt': FieldValue.serverTimestamp(),
        });
        tx.set(_users.doc(uid), {
          ..._publicFields(profile),
          'topics': [for (final t in profile.topics) t.name],
          'displayMode': profile.displayMode.name,
          'signUpMethod': profile.method?.name,
          'dateOfBirth': Timestamp.fromDate(dobUtc),
          'adultFrom': Timestamp.fromDate(adultFromBirthDate(dobUtc)),
          'athleteId': athleteId,
          'createdAt': FieldValue.serverTimestamp(),
          'consent': {
            'version': privacyNoticeVersion,
            'acceptedAt': Timestamp.fromDate(
              profile.consentGivenAt ?? DateTime.now(),
            ),
          },
        });
        return true;
      });
      if (created) {
        return Account(
          uid: uid,
          athleteId: athleteId,
          profile: profile,
          joinedAt: DateTime.now(),
        );
      }
    }
    throw StateError('Could not find a free athlete ID');
  }

  @override
  Future<void> update(Account account) async {
    final profile = account.profile;
    final batch = _db.batch()
      ..update(_users.doc(account.uid), {
        ..._publicFields(profile),
        'topics': [for (final t in profile.topics) t.name],
        'displayMode': profile.displayMode.name,
      })
      ..update(_cards.doc(account.athleteId), _publicFields(profile));
    await batch.commit();
  }

  @override
  Future<Account?> findById(String athleteId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _cards.doc(athleteId).get();
    } on FirebaseException catch (e) {
      // The rules deny adults access to under-18 cards; treat it exactly
      // like a missing ID so the app reveals nothing.
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
    final data = snapshot.data();
    if (data == null) return null;
    return Account(
      uid: data['ownerUid'] as String,
      athleteId: athleteId,
      profile: _profileFrom(data),
      joinedAt: _date(data['joinedAt']),
    );
  }

  @override
  Future<void> delete(Account account) async {
    final batch = _db.batch()
      ..delete(_cards.doc(account.athleteId))
      ..delete(_users.doc(account.uid));
    await batch.commit();
  }

  /// Fields shown on the ID card, stored in both collections.
  static Map<String, Object?> _publicFields(SignUpData p) => {
        'role': p.role!.name,
        'name': p.name,
        'sport': p.sport,
        'customSport': p.customSport,
        'level': p.level?.name,
        'category': p.category?.name,
      };

  static SignUpData _profileFrom(Map<String, dynamic> data) {
    final profile = SignUpData()
      ..role = _enum(UserRole.values, data['role'])
      ..name = data['name'] as String? ?? ''
      ..sport = data['sport'] as String?
      ..customSport = data['customSport'] as String? ?? ''
      ..level = _enum(CompetitionLevel.values, data['level'])
      ..category = _enum(AthleteCategory.values, data['category']);
    for (final name in (data['topics'] as List?) ?? const []) {
      final topic = _enum(Topic.values, name);
      if (topic != null) profile.topics.add(topic);
    }
    return profile;
  }

  static T? _enum<T extends Enum>(List<T> values, Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  // Server timestamps read back as null until the write reaches the server.
  static DateTime _date(Object? value) =>
      (value as Timestamp?)?.toDate() ?? DateTime.now();
}
