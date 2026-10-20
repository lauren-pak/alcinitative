import 'package:flutter/material.dart';

import '../models/account.dart';
import '../models/sign_up_data.dart';

/// Digital ID card shown after sign-up and log-in.
///
/// Date of birth is deliberately left off: sign-up promises it is never shown.
class AthleteIdCard extends StatelessWidget {
  const AthleteIdCard({super.key, required this.account});

  final Account account;

  String get _initials => account.profile.name
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profile = account.profile;
    final isAthlete = profile.role == UserRole.athlete;
    final onCard = scheme.onPrimary;
    final faded = onCard.withValues(alpha: 0.8);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports_handball_outlined, color: onCard, size: 20),
              const SizedBox(width: 8),
              Text(
                'ATHLETE APP',
                style: textTheme.labelLarge
                    ?.copyWith(color: onCard, letterSpacing: 1.5),
              ),
              const Spacer(),
              Text(
                isAthlete ? 'ATHLETE' : 'MEMBER',
                style: textTheme.labelMedium
                    ?.copyWith(color: faded, letterSpacing: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: onCard,
                child: Text(
                  _initials,
                  style: textTheme.titleLarge?.copyWith(color: scheme.primary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: textTheme.titleLarge?.copyWith(color: onCard),
                    ),
                    Text(
                      isAthlete
                          ? '${profile.sportName} · ${profile.level!.label}'
                          : profile.role!.label,
                      style: textTheme.bodyMedium?.copyWith(color: faded),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profile.category != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: onCard.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                profile.category!.label,
                style: textTheme.labelMedium?.copyWith(color: onCard),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _CardField(
                label: isAthlete ? 'ATHLETE ID' : 'MEMBER ID',
                value: account.athleteId,
                valueStyle: textTheme.titleMedium?.copyWith(
                  color: onCard,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              _CardField(
                label: 'MEMBER SINCE',
                value: MaterialLocalizations.of(context)
                    .formatMonthYear(account.joinedAt),
                valueStyle: textTheme.bodyMedium?.copyWith(color: onCard),
                alignEnd: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardField extends StatelessWidget {
  const _CardField({
    required this.label,
    required this.value,
    required this.valueStyle,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final onCard = Theme.of(context).colorScheme.onPrimary;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: onCard.withValues(alpha: 0.8),
                letterSpacing: 1.2,
              ),
        ),
        const SizedBox(height: 2),
        Text(value, style: valueStyle),
      ],
    );
  }
}
