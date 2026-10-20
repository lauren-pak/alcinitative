import 'package:flutter/material.dart';

import '../../models/sign_up_data.dart';
import '../privacy_notice_screen.dart';

/// Privacy consent, then choosing athlete or general public.
///
/// PDPA: consent comes first, before any personal data is collected, and the
/// role buttons stay disabled until it's given.
class RoleStep extends StatelessWidget {
  const RoleStep({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.consented,
    required this.onConsentChanged,
  });

  final UserRole? selected;
  final ValueChanged<UserRole> onSelected;
  final bool consented;
  final ValueChanged<bool> onConsentChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Join Athlete App', style: textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'A safe space for athletes to share their experiences and swap '
            'advice. How will you use it?',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          _ConsentBox(consented: consented, onChanged: onConsentChanged),
          const SizedBox(height: 16),
          for (final role in UserRole.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RoleCard(
                role: role,
                selected: role == selected,
                onTap: consented ? () => onSelected(role) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final icon = switch (role) {
      UserRole.athlete => Icons.sports_handball_outlined,
      UserRole.public => Icons.people_outline,
    };

    final card = Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 32, color: scheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role.label, style: textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(role.description, style: textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
    return Opacity(opacity: onTap == null ? 0.5 : 1, child: card);
  }
}

class _ConsentBox extends StatelessWidget {
  const _ConsentBox({required this.consented, required this.onChanged});

  final bool consented;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // A Material (not a coloured Container) so the checkbox ripple shows.
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              value: consented,
              onChanged: (v) => onChanged(v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(
                "I've read the Privacy Notice and I agree to Athlete App "
                'using my information in the ways it explains.',
                style: textTheme.bodyMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacyNoticeScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: const Text('Read the Privacy Notice'),
                  ),
                  Text(
                    'You need to be 13 or older to join. If you are under 18 '
                    "and anything isn't clear, go through it with a parent "
                    'or guardian.',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
