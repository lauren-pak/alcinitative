import 'package:flutter/material.dart';

import '../models/sign_up_data.dart';
import '../widgets/minor_protections_notice.dart';

/// Shown after sign-up. Placeholder until the feed exists.
class SignUpCompleteScreen extends StatelessWidget {
  const SignUpCompleteScreen({super.key, required this.data});

  final SignUpData data;

  String get _signedUpWith => switch (data.method!) {
        SignUpMethod.google => 'Google',
        SignUpMethod.phone => 'Phone · +65 ${data.phone}',
        SignUpMethod.email => 'Email · ${data.email}',
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final firstName = data.name.split(' ').first;
    final topics =
        Topic.values.where(data.topics.contains).map((t) => t.label).join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('Athlete App')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Welcome, $firstName!', style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('Your profile is ready.', style: textTheme.bodyLarge),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryRow(label: 'Account type', value: data.role!.label),
                      _SummaryRow(label: 'Signed up with', value: _signedUpWith),
                      if (data.role == UserRole.athlete) ...[
                        _SummaryRow(
                          label: 'Sport',
                          value: '${data.sport} · ${data.level!.label}',
                        ),
                        if (data.category != null)
                          _SummaryRow(
                            label: 'Programme',
                            value: data.category!.label,
                          ),
                      ],
                      _SummaryRow(label: 'Topics', value: topics),
                    ],
                  ),
                ),
              ),
              if (data.isMinorOn(DateTime.now())) ...[
                const SizedBox(height: 16),
                const MinorProtectionsNotice(),
              ],
              const SizedBox(height: 24),
              Text(
                'Prototype: nothing is saved yet. The feed comes next.',
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium),
          Text(value, style: textTheme.bodyLarge),
        ],
      ),
    );
  }
}
