import 'package:flutter/material.dart';

import '../../models/sign_up_data.dart';
import '../sign_up_complete_screen.dart';
import 'about_step.dart';
import 'method_step.dart';
import 'profile_step.dart';
import 'role_step.dart';

/// Four-step sign-up: role, sign-up method, about you, then profile.
class SignUpFlow extends StatefulWidget {
  const SignUpFlow({super.key});

  @override
  State<SignUpFlow> createState() => _SignUpFlowState();
}

class _SignUpFlowState extends State<SignUpFlow> {
  static const _stepCount = 4;

  final _data = SignUpData();
  int _step = 0;

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step < _stepCount - 1) {
      setState(() => _step++);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => SignUpCompleteScreen(data: _data)),
      (_) => false,
    );
  }

  void _back() => setState(() => _step--);

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
      RoleStep(selected: _data.role, onSelected: _selectRole),
      MethodStep(data: _data, onContinue: _next),
      AboutStep(data: _data, onContinue: _next),
      ProfileStep(data: _data, onContinue: _next),
    ];

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _step > 0 ? BackButton(onPressed: _back) : null,
          title: Text('Step ${_step + 1} of $_stepCount'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: (_step + 1) / _stepCount),
          ),
        ),
        body: GestureDetector(
          // Tapping outside a text field dismisses the keyboard.
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(key: ValueKey(_step), child: steps[_step]),
            ),
          ),
        ),
      ),
    );
  }
}
