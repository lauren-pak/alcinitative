import 'package:flutter/material.dart';

import '../../models/sign_up_data.dart';

/// Choose how to sign up: Google, phone number or email.
///
/// Prototype only: Google and phone verification are simulated, since there
/// is no backend yet.
class MethodStep extends StatefulWidget {
  const MethodStep({super.key, required this.data, required this.onContinue});

  final SignUpData data;
  final VoidCallback onContinue;

  @override
  State<MethodStep> createState() => _MethodStepState();
}

class _MethodStepState extends State<MethodStep> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  // Singapore mobile and landline numbers: 8 digits starting with 3, 6, 8 or 9.
  static final _sgPhonePattern = RegExp(r'^[3689]\d{7}$');
  static final _codePattern = RegExp(r'^\d{6}$');

  final _phoneForm = GlobalKey<FormState>();
  final _emailForm = GlobalKey<FormState>();

  /// Which inline form is open (phone or email).
  SignUpMethod? _open;
  bool _codeSent = false;
  bool _hidePassword = true;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    final method = widget.data.method;
    if (method != SignUpMethod.google) _open = method;
    _codeSent = method == SignUpMethod.phone;
  }

  void _toggle(SignUpMethod method) => setState(() {
        _open = _open == method ? null : method;
        _autovalidate = AutovalidateMode.disabled;
      });

  Future<void> _continueWithGoogle() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google sign-in'),
        content: const Text(
          "Google sign-in isn't connected in this prototype yet. "
          'You can continue to try the rest of sign-up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    widget.data.method = SignUpMethod.google;
    widget.onContinue();
  }

  bool _validate(GlobalKey<FormState> form) {
    final valid = form.currentState!.validate();
    if (!valid) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    }
    return valid;
  }

  void _sendCode() {
    if (!_validate(_phoneForm)) return;
    setState(() {
      _codeSent = true;
      _autovalidate = AutovalidateMode.disabled;
    });
  }

  void _verifyCode() {
    if (!_validate(_phoneForm)) return;
    widget.data.method = SignUpMethod.phone;
    widget.onContinue();
  }

  void _submitEmail() {
    if (!_validate(_emailForm)) return;
    widget.data.method = SignUpMethod.email;
    widget.onContinue();
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
          _MethodButton(
            icon: Icons.g_mobiledata,
            label: 'Continue with Google',
            onPressed: _continueWithGoogle,
          ),
          const SizedBox(height: 12),
          _MethodButton(
            icon: Icons.phone_outlined,
            label: 'Continue with phone number',
            selected: _open == SignUpMethod.phone,
            onPressed: () => _toggle(SignUpMethod.phone),
          ),
          if (_open == SignUpMethod.phone) _buildPhoneForm(),
          const SizedBox(height: 12),
          _MethodButton(
            icon: Icons.email_outlined,
            label: 'Continue with email',
            selected: _open == SignUpMethod.email,
            onPressed: () => _toggle(SignUpMethod.email),
          ),
          if (_open == SignUpMethod.email) _buildEmailForm(),
        ],
      ),
    );
  }

  Widget _buildPhoneForm() {
    final data = widget.data;
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
              initialValue: data.phone,
              enabled: !_codeSent,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixText: '+65 ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              onChanged: (v) => data.phone = v.replaceAll(' ', ''),
              validator: (v) =>
                  _sgPhonePattern.hasMatch(v?.replaceAll(' ', '') ?? '')
                      ? null
                      : 'Enter an 8-digit Singapore number',
            ),
            if (!_codeSent) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _sendCode,
                child: const Text('Send code'),
              ),
            ] else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _codeSent = false),
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
                validator: (v) => _codePattern.hasMatch(v ?? '')
                    ? null
                    : 'Enter the 6-digit code',
              ),
              Text(
                'Prototype: no text message is sent. Enter any 6 digits.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _verifyCode,
                child: const Text('Verify'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmailForm() {
    final data = widget.data;

    return Form(
      key: _emailForm,
      autovalidateMode: _autovalidate,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: data.email,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onChanged: (v) => data.email = v.trim(),
              validator: (v) => _emailPattern.hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Enter a valid email address',
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: data.password,
              obscureText: _hidePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'At least 8 characters',
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
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (v) => data.password = v,
              validator: (v) => (v == null || v.length < 8)
                  ? 'Use at least 8 characters'
                  : null,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submitEmail, child: const Text('Continue')),
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
  final VoidCallback onPressed;
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
