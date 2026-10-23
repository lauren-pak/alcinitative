import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/display_mode.dart';
import '../../models/sign_up_data.dart';
import '../../services/services.dart';
import '../edit_profile_screen.dart';
import '../verification/get_verified_screen.dart';
import '../your_data_screen.dart';
import '../../widgets/brand.dart';
import 'safety_settings_screen.dart';

/// Profile details, how the app looks, safety and privacy, and your data.
/// Everything except the athlete ID (and date of birth, which controls
/// under-18 protections) can be changed here.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.account});

  final Account account;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Account get _account => widget.account;

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    // Edits are copied into the account's profile; show them.
    if (mounted) setState(() {});
  }

  Future<void> _setMode(DisplayMode mode) async {
    final previous = _account.profile.displayMode;
    _account.profile.displayMode = mode;
    displayMode.value = mode;
    try {
      await Services.profiles.update(_account);
    } catch (_) {
      _account.profile.displayMode = previous;
      displayMode.value = previous;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't save that. Check your connection."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final profile = _account.profile;
    final details = [
      if (profile.role == UserRole.athlete) ...[
        ?profile.sportName,
        ?profile.level?.label,
        ?profile.category?.label,
      ] else
        profile.role?.label,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(text, style: textTheme.titleMedium),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          heading('My profile'),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(profile.name),
            subtitle: Text(
              details.isEmpty
                  ? 'Name, sport, level, programme and topics'
                  : details,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(EditProfileScreen(account: _account)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Your athlete ID (${_account.athleteId}) can't be changed. "
              "Your date of birth can't be changed in the app, because it "
              'decides the under-18 protections. If it is wrong, contact us '
              '(see the Privacy Notice).',
              style: textTheme.bodySmall,
            ),
          ),
          if (profile.role == UserRole.athlete)
            ListTile(
              leading: _account.verified
                  ? const VerifiedBadge(size: 24)
                  : const Icon(Icons.verified_outlined),
              title: Text(
                _account.verified ? 'Verified athlete' : 'Get verified',
              ),
              subtitle: const Text(
                'National, Paralympic and Special Olympics athletes',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(GetVerifiedScreen(account: _account)),
            ),
          heading('How the app looks'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ValueListenableBuilder(
              valueListenable: displayMode,
              builder: (context, mode, _) => SegmentedButton<DisplayMode>(
                segments: const [
                  ButtonSegment(
                    value: DisplayMode.standard,
                    icon: Icon(Icons.article_outlined),
                    label: Text('Standard'),
                  ),
                  ButtonSegment(
                    value: DisplayMode.easy,
                    icon: Icon(Icons.text_increase),
                    label: Text('Easy'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) => _setMode(s.first),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Easy has bigger text and buttons, and simpler screens.',
              style: textTheme.bodySmall,
            ),
          ),
          heading('Safety & privacy'),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Safety & privacy'),
            subtitle: const Text(
              'Show me in Find athlete, muted topics, blocked members',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(SafetySettingsScreen(account: _account)),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Your data & privacy'),
            subtitle: const Text(
              'See and download your data, or delete your account',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(YourDataScreen(account: _account)),
          ),
        ],
      ),
    );
  }
}
