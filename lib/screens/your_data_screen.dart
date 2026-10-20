import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../config/privacy_config.dart';
import '../models/account.dart';
import '../models/sign_up_data.dart';
import '../services/auth_service.dart';
import '../services/services.dart';
import 'account_home_screen.dart';
import 'edit_profile_screen.dart';
import 'intro_screen.dart';
import 'privacy_notice_screen.dart';

/// PDPA rights in one place: see everything we hold (access), fix it
/// (correction), download a copy, and delete the account (withdrawing
/// consent, as easily as giving it).
class YourDataScreen extends StatefulWidget {
  const YourDataScreen({super.key, required this.account});

  final Account account;

  @override
  State<YourDataScreen> createState() => _YourDataScreenState();
}

class _YourDataScreenState extends State<YourDataScreen> {
  late Account _account = widget.account;
  bool _deleting = false;

  /// Everything stored about the member, as label → value.
  Map<String, String> get _data {
    final p = _account.profile;
    final loc = MaterialLocalizations.of(context);
    return {
      'Name': p.name,
      'Date of birth': p.dateOfBirth == null
          ? ''
          : loc.formatCompactDate(p.dateOfBirth!),
      'Account type': p.role?.label ?? '',
      if (p.role == UserRole.athlete) ...{
        'Sport': p.sportName ?? '',
        'Level': p.level?.label ?? '',
        'Athlete programme': p.category?.label ?? 'None',
      },
      'Topics': Topic.values
          .where(p.topics.contains)
          .map((t) => t.label)
          .join(', '),
      'Athlete ID': _account.athleteId,
      'Joined': loc.formatCompactDate(_account.joinedAt),
      'Signed in with': AccountHomeScreen.signInSummary() ?? '',
      'Privacy Notice agreed': p.consentGivenAt == null
          ? 'Version $privacyNoticeVersion'
          : 'Version $privacyNoticeVersion on '
                '${loc.formatCompactDate(p.consentGivenAt!)}',
    };
  }

  Future<void> _download(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final json = const JsonEncoder.withIndent('  ').convert(_data);
    await SharePlus.instance.share(
      ShareParams(
        text: json,
        subject: 'My Athlete App data',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Account>(
      MaterialPageRoute(builder: (_) => EditProfileScreen(account: _account)),
    );
    if (updated != null && mounted) setState(() => _account = updated);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your profile, your athlete ID and your '
          "sign-in details. You can't undo it.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Firebase only deletes sign-in accounts after a recent log-in. Check
    // first, so we never delete the profile but leave the sign-in behind.
    if (!Services.auth.signedInRecently) {
      await _showMessage(
        'Please log in again',
        'For your security, log out and log in again, then delete your '
            'account straight away.',
      );
      return;
    }

    setState(() => _deleting = true);
    try {
      await Services.profiles.delete(_account);
      await Services.auth.deleteCurrentUser();
    } on AuthException catch (e) {
      if (mounted) {
        await _showMessage("Couldn't delete your account", e.message);
      }
      if (mounted) setState(() => _deleting = false);
      return;
    } catch (_) {
      if (mounted) {
        await _showMessage(
          "Couldn't delete your account",
          'Check your internet connection and try again.',
        );
      }
      if (mounted) setState(() => _deleting = false);
      return;
    }
    if (!mounted) return;
    await _showMessage(
      'Account deleted',
      'Your account and information have been deleted.',
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const IntroScreen()),
      (_) => false,
    );
  }

  Future<void> _showMessage(String title, String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Your data & privacy')),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _deleting,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Everything we store about you',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Kept on servers in Singapore. Only you can see your date of '
                  'birth and sign-in details.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in _data.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.key, style: textTheme.labelMedium),
                                Text(entry.value, style: textTheme.bodyLarge),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit my details'),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (buttonContext) => OutlinedButton.icon(
                    onPressed: () => _download(buttonContext),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download a copy'),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PrivacyNoticeScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: const Text('Read the Privacy Notice'),
                ),
                const SizedBox(height: 32),
                Text('Delete your account', style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Deleting your account removes your information and stops us '
                  'using it.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                if (_deleting)
                  const Center(child: CircularProgressIndicator())
                else
                  OutlinedButton.icon(
                    onPressed: _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete my account'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
