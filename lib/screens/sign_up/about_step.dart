import 'package:flutter/material.dart';

import '../../models/sign_up_data.dart';
import '../../widgets/minor_protections_notice.dart';

/// Name and date of birth, collected whichever sign-up method was used.
class AboutStep extends StatefulWidget {
  const AboutStep({super.key, required this.data, required this.onContinue});

  final SignUpData data;
  final VoidCallback onContinue;

  @override
  State<AboutStep> createState() => _AboutStepState();
}

class _AboutStepState extends State<AboutStep> {
  final _formKey = GlobalKey<FormState>();
  final _dobText = TextEditingController();
  // Re-check fields as the user edits, but only after the first failed submit.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dob = widget.data.dateOfBirth;
    if (dob != null) _dobText.text = _formatDate(dob);
  }

  @override
  void dispose() {
    _dobText.dispose();
    super.dispose();
  }

  // Matches the date picker's format for the device locale.
  String _formatDate(DateTime d) =>
      MaterialLocalizations.of(context).formatCompactDate(d);

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          widget.data.dateOfBirth ??
          DateTime(now.year - 16, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.input,
      helpText: 'Date of birth',
    );
    if (picked == null || !mounted) return;
    setState(() {
      widget.data.dateOfBirth = picked;
      _dobText.text = _formatDate(picked);
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onContinue();
    } else {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final textTheme = Theme.of(context).textTheme;
    final dob = data.dateOfBirth;
    final showMinorNotice =
        dob != null &&
        ageOn(dob, DateTime.now()) >= minimumAge &&
        data.isMinorOn(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('About you', style: textTheme.headlineMedium),
            const SizedBox(height: 24),
            TextFormField(
              initialValue: data.name,
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              onChanged: (v) => data.name = v.trim(),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dobText,
              readOnly: true,
              onTap: _pickDateOfBirth,
              decoration: const InputDecoration(
                labelText: 'Date of birth',
                helperText:
                    'Used to keep younger members safe. '
                    'Never shown on your profile.',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: (_) {
                if (dob == null) return 'Enter your date of birth';
                if (ageOn(dob, DateTime.now()) < minimumAge) {
                  return 'You need to be at least $minimumAge to join';
                }
                return null;
              },
            ),
            if (showMinorNotice) ...[
              const SizedBox(height: 16),
              const MinorProtectionsNotice(),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: _submit, child: const Text('Continue')),
          ],
        ),
      ),
    );
  }
}
