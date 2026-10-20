import '../models/sign_up_data.dart';

/// The signed-in person, as far as sign-in is concerned.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.method,
    this.email,
    this.phone,
    this.displayName,
  });

  final String uid;
  final SignUpMethod method;
  final String? email;

  /// In international format, e.g. `+6591234567`.
  final String? phone;

  /// From Google, used to pre-fill the name step.
  final String? displayName;
}

/// A sign-in problem, with a message ready to show to the user.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sign-in and account deletion. Firebase in the app, a fake in tests.
abstract class AuthService {
  AuthUser? get currentUser;

  /// Whether the user signed in within the last few minutes. Deleting an
  /// account needs a recent sign-in.
  bool get signedInRecently;

  Future<AuthUser> signUpWithEmail(String email, String password);

  Future<AuthUser> logInWithEmail(String email, String password);

  /// Texts a code to [phoneNumber] (international format) and returns the
  /// verification ID to pass to [confirmPhoneCode].
  Future<String> sendPhoneCode(String phoneNumber);

  Future<AuthUser> confirmPhoneCode(String verificationId, String code);

  /// Returns null if the user cancels Google's account picker.
  Future<AuthUser?> signInWithGoogle();

  Future<void> signOut();

  /// Permanently deletes the sign-in account (email, phone or Google link).
  Future<void> deleteCurrentUser();
}
