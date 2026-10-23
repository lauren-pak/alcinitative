import 'package:flutter/material.dart';

import '../models/sign_up_data.dart';

/// Shows a Google sign-in problem in a dialog.
Future<void> showGoogleError(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Google sign-in'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Google, phone and email buttons, each opening its own inline form.
///
/// Shared by sign-up and log-in. The phone and email callbacks return an
/// error message to show under the form, or null on success. While a
/// callback runs, the buttons are disabled and a spinner shows.
class AuthMethodPicker extends StatefulWidget {
  const AuthMethodPicker({
    super.key,
    required this.isSignUp,
    required this.onGoogle,
    required this.onSendCode,
    required this.onVerifyCode,
    required this.onEmail,
  });

  final bool isSignUp;

  /// Returns an error, shown in a dialog rather than under a form.
  final Future<String?> Function() onGoogle;

  /// [phone] is the 8-digit Singapore number without +65.
  final Future<String?> Function(String phone) onSendCode;
  final Future<String?> Function(String code) onVerifyCode;
  final Future<String?> Function(String email, String password) onEmail;

  @override
  State<AuthMethodPicker> createState() => _AuthMethodPickerState();
}

class _AuthMethodPickerState extends State<AuthMethodPicker> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  // Singapore mobile and landline numbers: 8 digits starting with 3, 6, 8 or 9.
  static final _sgPhonePattern = RegExp(r'^[3689]\d{7}$');
  static final _codePattern = RegExp(r'^\d{6}$');

  final _phoneForm = GlobalKey<FormState>();
  final _emailForm = GlobalKey<FormState>();

  /// Which inline form is open (phone or email).
  SignUpMethod? _open;
  String _phone = '';
  String _code = '';
  String _email = '';
  String _password = '';
  bool _codeSent = false;
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  /// Runs a sign-in step with the buttons disabled; returns its error.
  Future<String?> _run(
    Future<String?> Function() action, {
    bool showErrorInline = true,
  }) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final error = await action();
      if (mounted && showErrorInline) setState(() => _error = error);
      return error;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggle(SignUpMethod method) => setState(() {
    _open = _open == method ? null : method;
    _error = null;
    _autovalidate = AutovalidateMode.disabled;
  });

  bool _validate(GlobalKey<FormState> form) {
    final valid = form.currentState!.validate();
    if (!valid) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    }
    return valid;
  }

  Future<void> _sendCode() async {
    if (!_validate(_phoneForm)) return;
    final error = await _run(() => widget.onSendCode(_phone));
    if (error == null && mounted) {
      setState(() {
        _codeSent = true;
        _autovalidate = AutovalidateMode.disabled;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (!_validate(_phoneForm)) return;
    await _run(() => widget.onVerifyCode(_code));
  }

  Future<void> _submitEmail() async {
    if (!_validate(_emailForm)) return;
    await _run(() => widget.onEmail(_email.trim(), _password));
  }

  Future<void> _google() async {
    final error = await _run(widget.onGoogle, showErrorInline: false);
    if (error != null && mounted) await showGoogleError(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MethodButton(
          icon: Icons.g_mobiledata,
          label: 'Continue with Google',
          onPressed: _busy ? null : _google,
        ),
        const SizedBox(height: 12),
        _MethodButton(
          icon: Icons.phone_outlined,
          label: 'Continue with phone number',
          selected: _open == SignUpMethod.phone,
          onPressed: _busy ? null : () => _toggle(SignUpMethod.phone),
        ),
        if (_open == SignUpMethod.phone) _buildPhoneForm(),
        const SizedBox(height: 12),
        _MethodButton(
          icon: Icons.email_outlined,
          label: 'Continue with email',
          selected: _open == SignUpMethod.email,
          onPressed: _busy ? null : () => _toggle(SignUpMethod.email),
        ),
        if (_open == SignUpMethod.email) _buildEmailForm(),
        if (_busy) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  Widget _buildError() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        _error!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Widget _buildPhoneForm() {
    final textTheme = Theme.of(context).textTheme;

    return Form(
      key: _phoneForm,
      autovalidateMode: _autovalidate,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: _phone,
              enabled: !_codeSent && !_busy,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixText: '+65 ',
                // Firebase asks apps to warn that an SMS will be sent.
                helperText:
                    "We'll text you a 6-digit code. Standard "
                    'message rates may apply.',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              onChanged: (v) => _phone = v.replaceAll(' ', ''),
              validator: (v) =>
                  _sgPhonePattern.hasMatch(v?.replaceAll(' ', '') ?? '')
                  ? null
                  : 'Enter an 8-digit Singapore number',
            ),
            if (!_codeSent) ...[
              _buildError(),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _sendCode,
                child: const Text('Send code'),
              ),
            ] else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() {
                    _codeSent = false;
                    _error = null;
                  }),
                  child: const Text('Change number'),
                ),
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                onChanged: (v) => _code = v.trim(),
                validator: (v) => _codePattern.hasMatch(v ?? '')
                    ? null
                    : 'Enter the 6-digit code',
              ),
              Text(
                'We texted a code to +65 $_phone.',
                style: textTheme.bodySmall,
              ),
              _buildError(),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _verifyCode,
                child: const Text('Verify'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmailForm() {
    final isSignUp = widget.isSignUp;

    return Form(
      key: _emailForm,
      autovalidateMode: _autovalidate,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: _email,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onChanged: (v) => _email = v,
              validator: (v) => _emailPattern.hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Enter a valid email address',
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _password,
              obscureText: _hidePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: isSignUp ? 'At least 8 characters' : null,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _hidePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              autofillHints: [
                isSignUp ? AutofillHints.newPassword : AutofillHints.password,
              ],
              onChanged: (v) => _password = v,
              validator: (v) {
                if (isSignUp) {
                  return (v == null || v.length < 8)
                      ? 'Use at least 8 characters'
                      : null;
                }
                return (v == null || v.isEmpty) ? 'Enter your password' : null;
              },
            ),
            _buildError(),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submitEmail,
              child: Text(isSignUp ? 'Continue' : 'Log in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outline,
          width: selected ? 2 : 1,
        ),
      ),
    );
  }
}
