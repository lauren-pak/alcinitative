import 'package:flutter/material.dart';

import '../../models/sign_up_data.dart';

class RoleStep extends StatelessWidget {
  const RoleStep({super.key, required this.selected, required this.onSelected});

  final UserRole? selected;
  final ValueChanged<UserRole> onSelected;

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
          const SizedBox(height: 24),
          for (final role in UserRole.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RoleCard(
                role: role,
                selected: role == selected,
                onTap: () => onSelected(role),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final icon = switch (role) {
      UserRole.athlete => Icons.sports_handball_outlined,
      UserRole.public => Icons.people_outline,
    };

    return Card(
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
  }
}
