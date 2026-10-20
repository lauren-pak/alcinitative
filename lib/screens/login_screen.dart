import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/services.dart';
import '../widgets/auth_method_picker.dart';
import 'auth_gate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _verificationId;

  Future<String?> _attempt(Future<AuthUser?> Function() signIn) async {
    try {
      final user = await signIn();
      if (user != null && mounted) await openAccountFor(context, user);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Log in')),
      body: GestureDetector(
        // Tapping outside a text field dismisses the keyboard.
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Welcome back', style: textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Log in the same way you signed up.',
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                AuthMethodPicker(
                  isSignUp: false,
                  onGoogle: () => _attempt(Services.auth.signInWithGoogle),
                  onSendCode: _sendCode,
                  onVerifyCode: (code) => _attempt(
                    () =>
                        Services.auth.confirmPhoneCode(_verificationId!, code),
                  ),
                  onEmail: (email, password) => _attempt(
                    () => Services.auth.logInWithEmail(email, password),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
