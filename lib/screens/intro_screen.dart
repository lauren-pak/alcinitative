import 'package:flutter/material.dart';

import '../models/display_mode.dart';
import 'login_screen.dart';
import 'sign_up/sign_up_flow.dart';

/// First screen: explains what Athlete App is before sign-up.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          // Visible before sign-up, so the simpler view helps from the start.
          ValueListenableBuilder(
            valueListenable: displayMode,
            builder: (context, mode, _) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: const Icon(Icons.text_increase, size: 18),
                label: const Text('Easy mode'),
                selected: mode == DisplayMode.easy,
                onSelected: (on) => displayMode.value = on
                    ? DisplayMode.easy
                    : DisplayMode.standard,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    Icons.sports_handball_outlined,
                    size: 40,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Welcome to Athlete App', style: textTheme.headlineLarge),
              const SizedBox(height: 12),
              Text(
                'A safe space where athletes share their sporting experiences '
                'and get advice from people who have been there.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              const _Feature(
                icon: Icons.edit_note,
                title: 'Share your journey',
                body:
                    'Post updates and videos about injury, training, '
                    'sports nutrition and competition.',
              ),
              const _Feature(
                icon: Icons.forum_outlined,
                title: 'Learn from each other',
                body:
                    'Get advice from athletes in your sport, and pass on '
                    'what worked for you.',
              ),
              const _Feature(
                icon: Icons.diversity_3_outlined,
                title: 'For every athlete',
                body:
                    'National, Paralympic and Special Olympics athletes, '
                    'from school level to elite.',
              ),
              const _Feature(
                icon: Icons.shield_outlined,
                title: 'Safe by design',
                body:
                    'Extra protections for under-18s, and easy ways to '
                    "report anything that doesn't feel right.",
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SignUpFlow())),
                child: const Text('Get started'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(body, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
