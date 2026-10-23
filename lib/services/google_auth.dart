import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/google_sign_in_config.dart';
import 'auth_service.dart';

/// What we use from a Google account.
class GoogleProfile {
  const GoogleProfile({required this.idToken, this.name});

  /// Passed to Firebase Auth to sign in.
  final String idToken;
  final String? name;
}

/// Thin wrapper around the google_sign_in package.
class GoogleAuth {
  static bool _initialized = false;

  static bool get isConfigured => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => googleIosClientId.isNotEmpty,
    TargetPlatform.android => googleWebClientId.isNotEmpty,
    _ => false,
  };

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    await GoogleSignIn.instance.initialize(
      clientId: isIOS ? googleIosClientId : null,
      serverClientId: isIOS ? null : googleWebClientId,
    );
    _initialized = true;
  }

  /// Shows Google's account picker. Returns null if the user cancels.
  static Future<GoogleProfile?> signIn() async {
    // The iOS SDK crashes without a client ID, so never call it unconfigured.
    if (!isConfigured) {
      throw const AuthException(
        "Google sign-in isn't set up for this app yet. "
        'Use your phone number or email for now.',
      );
    }
    try {
      await _ensureInitialized();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthException('Google sign-in failed. Please try again.');
      }
      return GoogleProfile(idToken: idToken, name: account.displayName);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthException(
        'Google sign-in failed. Please try again. (${e.code.name})',
      );
    }
  }

  /// Signs out of Google so the account picker shows next time.
  static Future<void> signOut() async {
    if (_initialized) await GoogleSignIn.instance.signOut();
  }
}
