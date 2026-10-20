import 'package:flutter/material.dart';

import '../config/privacy_config.dart';

/// The PDPA notice, written so a 13-year-old can follow it (PDPC Advisory
/// Guidelines on Children's Personal Data, section 3). Bump
/// [privacyNoticeVersion] whenever the wording changes.
class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final contact = dataProtectionOfficerEmail.isEmpty
        ? 'Our Data Protection Officer contact will be added here before the '
            'app launches.'
        : 'Email our Data Protection Officer at $dataProtectionOfficerEmail.';

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Notice')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('How we look after your information',
                style: textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Version $privacyNoticeVersion', style: textTheme.bodySmall),
            const SizedBox(height: 16),
            Text(
              "This explains, in plain words, what Athlete App collects "
              "about you, why we need it, and what you can do about it. It's "
              "written to follow Singapore's Personal Data Protection Act "
              '(PDPA).',
              style: textTheme.bodyLarge,
            ),
            const _Section(
              title: 'What we collect',
              points: [
                'Your name and date of birth.',
                "Whether you're an athlete or a member of the public.",
                'Your sport, level and athlete programme, if you give them.',
                'The topics you pick for your feed.',
                'Your email address, phone number or Google account, '
                    'depending on how you sign in.',
                "An athlete ID we make for you. We don't collect your "
                    'location.',
              ],
            ),
            const _Section(
              title: 'Why we need it',
              points: [
                'To create your account and let you log in.',
                'To show your athlete ID card.',
                "Your date of birth tells us if you're under 18, so we can "
                    'turn on extra protections for you.',
                'Your topics decide what shows up in your feed.',
                "We never sell your information or use it for adverts.",
              ],
            ),
            const _Section(
              title: 'Who can see it',
              points: [
                'People you share your athlete ID with can see your ID '
                    'card: your name, sport, level, programme, ID and the '
                    'month you joined.',
                "If you're under 18, only other under-18s can see your "
                    'card, even if an adult has your ID.',
                'Nobody can search for you or browse a list of members.',
                'Your date of birth, email and phone number are never '
                    'shown to other members.',
              ],
            ),
            const _Section(
              title: 'Where we keep it',
              points: [
                "On Google Firebase computers in Singapore. Google looks "
                    'after the data for us and only uses it to run the app.',
                'Only you can open your full profile. Our security rules '
                    'block everyone else.',
              ],
            ),
            const _Section(
              title: 'How long we keep it',
              points: [
                'For as long as you have an account.',
                'When you delete your account, we delete your profile, '
                    'your athlete ID and your sign-in details.',
              ],
            ),
            const _Section(
              title: 'Your choices',
              points: [
                'See everything we hold about you, and download a copy: '
                    'open "Your data & privacy" in the app.',
                'Fix your details there at any time. To fix your date of '
                    'birth, contact us (below).',
                'Change your mind? Delete your account in "Your data & '
                    "privacy\". It's as easy as signing up, and it stops us "
                    'using your information.',
              ],
            ),
            const _Section(
              title: 'If you are under 18',
              points: [
                'You need to be 13 or older to join.',
                "If you're 13 to 17, only agree if you understand this "
                    'notice. If anything is unclear, read it with a parent '
                    'or guardian first.',
              ],
            ),
            const _Section(
              title: 'If something goes wrong',
              points: [
                'If your information is ever leaked in a way that could '
                    'harm you, we will tell you, and the Personal Data '
                    'Protection Commission when the law requires it.',
                "If you're under 18, we'll explain what happened in "
                    'simple words and suggest you tell a parent or guardian.',
              ],
            ),
            _Section(title: 'Questions or requests', points: [contact]),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.points});

  final String title;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: textTheme.bodyMedium),
                  Expanded(child: Text(point, style: textTheme.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
