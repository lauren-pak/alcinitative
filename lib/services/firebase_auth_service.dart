import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/sign_up_data.dart';
import 'auth_service.dart';
import 'google_auth.dart';

class FirebaseAuthService implements AuthService {
  final _auth = FirebaseAuth.instance;

  /// Waits until Firebase has restored any saved sign-in.
  Future<void> init() => _auth.authStateChanges().first;

  @override
  AuthUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : _toAuthUser(user);
  }

  @override
  bool get signedInRecently {
    final last = _auth.currentUser?.metadata.lastSignInTime;
    return last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 5);
  }

  AuthUser _toAuthUser(User user, {String? displayName}) {
    final providers = user.providerData.map((p) => p.providerId).toSet();
    final method = providers.contains('google.com')
        ? SignUpMethod.google
        : providers.contains('phone')
        ? SignUpMethod.phone
        : SignUpMethod.email;
    return AuthUser(
      uid: user.uid,
      method: method,
      email: user.email,
      phone: user.phoneNumber,
      displayName: displayName ?? user.displayName,
    );
  }

  Future<AuthUser> _signIn(
    Future<UserCredential> Function() action, {
    String? displayName,
  }) async {
    try {
      final result = await action();
      return _toAuthUser(result.user!, displayName: displayName);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  @override
  Future<AuthUser> signUpWithEmail(String email, String password) => _signIn(
    () =>
        _auth.createUserWithEmailAndPassword(email: email, password: password),
  );

  @override
  Future<AuthUser> logInWithEmail(String email, String password) => _signIn(
    () => _auth.signInWithEmailAndPassword(email: email, password: password),
  );

  @override
  Future<String> sendPhoneCode(String phoneNumber) {
    final verificationId = Completer<String>();
    _auth
        .verifyPhoneNumber(
          phoneNumber: phoneNumber,
          // Android can read the code automatically; we still let the user
          // type it, so one code path works on both platforms.
          verificationCompleted: (_) {},
          verificationFailed: (e) {
            if (!verificationId.isCompleted) {
              verificationId.completeError(AuthException(_message(e)));
            }
          },
          codeSent: (id, _) {
            if (!verificationId.isCompleted) verificationId.complete(id);
          },
          codeAutoRetrievalTimeout: (_) {},
        )
        .catchError((Object e) {
          if (!verificationId.isCompleted) {
            verificationId.completeError(
              e is FirebaseAuthException ? AuthException(_message(e)) : e,
            );
          }
        });
    return verificationId.future;
  }

  @override
  Future<AuthUser> confirmPhoneCode(String verificationId, String code) =>
      _signIn(
        () => _auth.signInWithCredential(
          PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: code,
          ),
        ),
      );

  @override
  Future<AuthUser?> signInWithGoogle() async {
    final google = await GoogleAuth.signIn();
    if (google == null) return null;
    return _signIn(
      () => _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: google.idToken),
      ),
      displayName: google.name,
    );
  }

  @override
  Future<void> signOut() async {
    await GoogleAuth.signOut();
    await _auth.signOut();
  }

  @override
  Future<void> deleteCurrentUser() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
    await GoogleAuth.signOut();
  }

  static String _message(FirebaseAuthException e) => switch (e.code) {
    'email-already-in-use' =>
      'This email already has an account. Log in instead.',
    'invalid-email' => 'Enter a valid email address',
    'weak-password' => 'Choose a stronger password',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Email or password is incorrect',
    'invalid-verification-code' => "That code isn't right. Try again.",
    'session-expired' || 'code-expired' =>
      'That code has expired. Tap "Change number" to get a new one.',
    'invalid-phone-number' => 'Enter an 8-digit Singapore number',
    'too-many-requests' =>
      'Too many attempts. Wait a few minutes and try again.',
    'network-request-failed' =>
      'No internet connection. Check it and try again.',
    'operation-not-allowed' => "This sign-in method isn't turned on yet.",
    'requires-recent-login' =>
      'For your security, log out and log in again first.',
    'billing-not-enabled' || 'quota-exceeded' =>
      "Text messages aren't available yet. Use email or Google for now.",
    _ => 'Something went wrong. Please try again. (${e.code})',
  };
}
