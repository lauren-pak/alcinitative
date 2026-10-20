import 'package:athlete_app/models/account.dart';
import 'package:athlete_app/models/sign_up_data.dart';
import 'package:athlete_app/services/auth_service.dart';
import 'package:athlete_app/services/profile_repository.dart';

/// In-memory stand-in for Firebase Auth.
class FakeAuthService implements AuthService {
  static const validCode = '123456';

  final _emailAccounts = <String, ({String uid, String password})>{};
  final _phoneAccounts = <String, String>{};
  int _nextUid = 0;
  AuthUser? _current;

  /// What "Continue with Google" returns; null means Google isn't set up.
  AuthUser? googleUser;
  bool recentSignIn = true;
  int deletedUsers = 0;

  @override
  AuthUser? get currentUser => _current;

  @override
  bool get signedInRecently => recentSignIn;

  String _newUid() => 'uid${_nextUid++}';

  @override
  Future<AuthUser> signUpWithEmail(String email, String password) async {
    if (_emailAccounts.containsKey(email)) {
      throw const AuthException(
        'This email already has an account. Log in instead.',
      );
    }
    final uid = _newUid();
    _emailAccounts[email] = (uid: uid, password: password);
    return _current =
        AuthUser(uid: uid, method: SignUpMethod.email, email: email);
  }

  @override
  Future<AuthUser> logInWithEmail(String email, String password) async {
    final account = _emailAccounts[email];
    if (account == null || account.password != password) {
      throw const AuthException('Email or password is incorrect');
    }
    return _current =
        AuthUser(uid: account.uid, method: SignUpMethod.email, email: email);
  }

  @override
  Future<String> sendPhoneCode(String phoneNumber) async => phoneNumber;

  @override
  Future<AuthUser> confirmPhoneCode(String verificationId, String code) async {
    if (code != validCode) {
      throw const AuthException("That code isn't right. Try again.");
    }
    final uid = _phoneAccounts.putIfAbsent(verificationId, _newUid);
    return _current =
        AuthUser(uid: uid, method: SignUpMethod.phone, phone: verificationId);
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    if (googleUser == null) {
      throw const AuthException(
        "Google sign-in isn't set up for this app yet. "
        'Use your phone number or email for now.',
      );
    }
    return _current = googleUser;
  }

  @override
  Future<void> signOut() async => _current = null;

  @override
  Future<void> deleteCurrentUser() async {
    final uid = _current?.uid;
    _emailAccounts.removeWhere((_, a) => a.uid == uid);
    _phoneAccounts.removeWhere((_, u) => u == uid);
    _current = null;
    deletedUsers++;
  }
}

/// In-memory stand-in for Firestore. [findById] mirrors the under-18 rule in
/// `firestore.rules`, which is the real enforcement.
class InMemoryProfileRepository implements ProfileRepository {
  InMemoryProfileRepository(this._auth);

  final AuthService _auth;
  final accounts = <String, Account>{};

  @override
  Future<Account?> load(String uid) async => accounts[uid];

  @override
  Future<Account> create(String uid, SignUpData profile) async {
    String id;
    do {
      id = newAthleteId();
    } while (accounts.values.any((a) => a.athleteId == id));
    return accounts[uid] = Account(
      uid: uid,
      athleteId: id,
      profile: profile,
      joinedAt: DateTime.now(),
    );
  }

  @override
  Future<void> update(Account account) async => accounts[account.uid] = account;

  @override
  Future<Account?> findById(String athleteId) async {
    final now = DateTime.now();
    final viewer = accounts[_auth.currentUser?.uid];
    for (final a in accounts.values) {
      if (a.athleteId != athleteId) continue;
      final hidden = a.profile.isMinorOn(now) &&
          a != viewer &&
          !(viewer?.profile.isMinorOn(now) ?? false);
      return hidden ? null : a;
    }
    return null;
  }

  @override
  Future<void> delete(Account account) async => accounts.remove(account.uid);
}
