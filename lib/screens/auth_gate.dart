import 'package:flutter/material.dart';

import '../models/account.dart';
import '../services/auth_service.dart';
import '../services/services.dart';
import 'home_shell.dart';
import 'intro_screen.dart';
import 'sign_up/sign_up_flow.dart';

/// First screen at launch: the intro if signed out, otherwise the account.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _user = Services.auth.currentUser;
  late final Future<Account?>? _account =
      _user == null ? null : Services.profiles.load(_user.uid);

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) return const IntroScreen();
    return FutureBuilder<Account?>(
      future: _account,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) return const IntroScreen();
        return _screenFor(user, snapshot.data);
      },
    );
  }
}

Widget _screenFor(AuthUser user, Account? account) => account == null
    // Signed in but never finished sign-up: pick up where they left off.
    ? SignUpFlow(resumeUser: user)
    : HomeShell(account: account, isNewAccount: false);

/// After a successful log-in: opens the account, or finishes sign-up if the
/// profile was never completed. Clears the back stack.
Future<void> openAccountFor(BuildContext context, AuthUser user) async {
  final account = await Services.profiles.load(user.uid);
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => _screenFor(user, account)),
    (_) => false,
  );
}
