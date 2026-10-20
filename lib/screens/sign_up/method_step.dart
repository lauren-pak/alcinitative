import 'package:flutter/material.dart';

import '../../models/sign_up_data.dart';
import '../../services/auth_service.dart';
import '../../services/services.dart';
import '../../widgets/auth_method_picker.dart';
import '../auth_gate.dart';

/// Choose how to sign up: Google, phone number or email. This creates the
/// sign-in account; the profile is saved at the end of sign-up.
class MethodStep extends StatefulWidget {
  const MethodStep({super.key, required this.data, required this.onContinue});

  final SignUpData data;
  final VoidCallback onContinue;

  @override
  State<MethodStep> createState() => _MethodStepState();
}

class _MethodStepState extends State<MethodStep> {
  String? _verificationId;

  /// Continues sign-up, unless this person already has a full account (for
  /// example, they used Google again), in which case they're logged in.
  Future<void> _signedIn(AuthUser user) async {
    final existing = await Services.profiles.load(user.uid);
    if (!mounted) return;
    if (existing != null) {
      await openAccountFor(context, user);
      return;
    }
    final data = widget.data
      ..method = user.method
      ..email = user.email ?? ''
      ..phone = user.phone ?? '';
    // Pre-fill the name step; the person can still edit it.
    if (data.name.isEmpty && user.displayName != null) {
      data.name = user.displayName!;
    }
    widget.onContinue();
  }

  Future<String?> _attempt(Future<AuthUser?> Function() signIn) async {
    try {
      final user = await signIn();
      if (user != null) await _signedIn(user);
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> _sendCode(String phone) async {
    try {
      _verificationId = await Services.auth.sendPhoneCode('+65$phone');
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How do you want to sign up?', style: textTheme.headlineMedium),
          const SizedBox(height: 24),
          AuthMethodPicker(
            isSignUp: true,
            onGoogle: () => _attempt(Services.auth.signInWithGoogle),
            onSendCode: _sendCode,
            onVerifyCode: (code) => _attempt(
              () => Services.auth.confirmPhoneCode(_verificationId!, code),
            ),
            onEmail: (email, password) =>
                _attempt(() => Services.auth.signUpWithEmail(email, password)),
          ),
        ],
      ),
    );
  }
}
