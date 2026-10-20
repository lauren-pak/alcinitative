import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/account.dart';
import '../models/sign_up_data.dart';
import '../services/services.dart';
import '../widgets/athlete_id_card.dart';
import '../widgets/minor_protections_notice.dart';
import 'find_athlete_screen.dart';
import 'intro_screen.dart';
import 'your_data_screen.dart';

/// Shown after sign-up or log-in. Placeholder until the feed exists.
class AccountHomeScreen extends StatelessWidget {
  const AccountHomeScreen({
    super.key,
    required this.account,
    required this.isNewAccount,
  });

  final Account account;
  final bool isNewAccount;

  /// How the member signs in, read from Firebase Auth (not stored in the
  /// profile).
  static String? signInSummary() {
    final user = Services.auth.currentUser;
    if (user == null) return null;
    return switch (user.method) {
      SignUpMethod.google => 'Google · ${user.email ?? ''}',
      SignUpMethod.phone => 'Phone · ${user.phone ?? ''}',
      SignUpMethod.email => 'Email · ${user.email ?? ''}',
    };
  }

  Future<void> _shareId(BuildContext buttonContext, String idName) async {
    // iPad needs to know where to anchor the share sheet.
    final box = buttonContext.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: "I'm on Athlete App! Find me with my $idName: "
            '${account.athleteId}',
        subject: 'My Athlete App $idName',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _logOut(BuildContext context) async {
    await Services.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const IntroScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final profile = account.profile;
    final firstName = profile.name.split(' ').first;
    final isMinor = profile.isMinorOn(DateTime.now());
    final idName =
        profile.role == UserRole.athlete ? 'athlete ID' : 'member ID';
    final topics = Topic.values
        .where(profile.topics.contains)
        .map((t) => t.label)
        .join(', ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Athlete App'),
        actions: [
          TextButton(
            onPressed: () => _logOut(context),
            child: const Text('Log out'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isNewAccount
                    ? 'Welcome, $firstName!'
                    : 'Welcome back, $firstName!',
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                isNewAccount
                    ? "You're all set. Here's your $idName."
                    : "Here's your $idName.",
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              AthleteIdCard(account: account),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (buttonContext) => FilledButton.tonalIcon(
                        onPressed: () => _shareId(buttonContext, idName),
                        icon: const Icon(Icons.ios_share),
                        label: Text('Share my ID'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FindAthleteScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.person_search_outlined),
                      label: const Text('Find athlete'),
                    ),
                  ),
                ],
              ),
              if (isMinor) ...[
                const SizedBox(height: 8),
                Text(
                  'Only share your ID with people you know. Adults '
                  "can't look up under-18s' IDs.",
                  style: textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (signInSummary() case final signIn?)
                        _DetailRow(label: 'Signed in with', value: signIn),
                      _DetailRow(label: 'Topics', value: topics),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => YourDataScreen(account: account),
                  ),
                ),
                icon: const Icon(Icons.privacy_tip_outlined),
                label: const Text('Your data & privacy'),
              ),
              if (isMinor) ...[
                const SizedBox(height: 16),
                const MinorProtectionsNotice(),
              ],
              const SizedBox(height: 24),
              Text(
                'The feed comes next.',
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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
