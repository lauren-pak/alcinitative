import 'package:flutter/material.dart';

import '../../models/sign_up_data.dart';
import '../../services/auth_service.dart';
import '../../services/services.dart';
import '../account_home_screen.dart';
import '../intro_screen.dart';
import 'about_step.dart';
import 'method_step.dart';
import 'profile_step.dart';
import 'role_step.dart';

/// Sign-up: consent and role, sign-in method, about you, then profile.
///
/// The sign-in account is created at the method step; the profile is saved
/// only at the end. With [resumeUser], someone who signed in but never
/// finished sign-up skips the method step.
class SignUpFlow extends StatefulWidget {
  const SignUpFlow({super.key, this.resumeUser});

  final AuthUser? resumeUser;

  @override
  State<SignUpFlow> createState() => _SignUpFlowState();
}

class _SignUpFlowState extends State<SignUpFlow> {
  final _data = SignUpData();
  int _step = 0;
  bool _saving = false;

  bool get _resuming => widget.resumeUser != null;
  int get _stepCount => _resuming ? 3 : 4;

  @override
  void initState() {
    super.initState();
    final user = widget.resumeUser;
    if (user != null) {
      _data
        ..method = user.method
        ..email = user.email ?? ''
        ..phone = user.phone ?? ''
        ..name = user.displayName ?? '';
    }
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step < _stepCount - 1) {
      setState(() => _step++);
    } else {
      _createAccount();
    }
  }

  Future<void> _createAccount() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final user = Services.auth.currentUser!;
      final account = await Services.profiles.create(user.uid, _data);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              AccountHomeScreen(account: account, isNewAccount: true),
        ),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't create your account. Check your internet connection "
            'and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _back() {
    // Going back past the method step: remove the sign-in account just made,
    // so we don't keep an email or phone number for an abandoned sign-up.
    if (!_resuming && _step == 2) _discardSignIn();
    setState(() => _step--);
  }

  void _discardSignIn() {
    Services.auth.deleteCurrentUser().catchError((_) => Services.auth.signOut());
  }

  /// Leaving an unfinished, resumed sign-up.
  void _cancelResume() {
    _discardSignIn();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const IntroScreen()),
      (_) => false,
    );
  }

  void _selectRole(UserRole role) {
    setState(() {
      _data.role = role;
      if (role == UserRole.public) {
        _data.sport = null;
        _data.level = null;
        _data.category = null;
      }
    });
    _next();
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      RoleStep(
        selected: _data.role,
        onSelected: _selectRole,
        consented: _data.consentGivenAt != null,
        onConsentChanged: (agreed) => setState(
          () => _data.consentGivenAt = agreed ? DateTime.now() : null,
        ),
      ),
      if (!_resuming) MethodStep(data: _data, onContinue: _next),
      AboutStep(data: _data, onContinue: _next),
      ProfileStep(data: _data, onContinue: _next),
    ];

    return PopScope(
      canPop: _step == 0 && !_resuming,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _step > 0
              ? BackButton(onPressed: _back)
              : _resuming
                  ? IconButton(
                      tooltip: 'Cancel sign-up',
                      icon: const Icon(Icons.close),
                      onPressed: _cancelResume,
                    )
                  : null,
          title: Text(
            _resuming
                ? 'Finish signing up · ${_step + 1} of $_stepCount'
                : 'Step ${_step + 1} of $_stepCount',
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: _saving ? null : (_step + 1) / _stepCount,
            ),
          ),
        ),
        body: GestureDetector(
          // Tapping outside a text field dismisses the keyboard.
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: AbsorbPointer(
              absorbing: _saving,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(key: ValueKey(_step), child: steps[_step]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
