import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../models/sign_up_data.dart';
import '../../services/safety_repository.dart';
import '../../services/services.dart';
import '../../widgets/feed_widgets.dart';

/// Muted topics, name search and blocked members.
class SafetySettingsScreen extends StatefulWidget {
  const SafetySettingsScreen({super.key, required this.account});

  final Account account;

  @override
  State<SafetySettingsScreen> createState() => _SafetySettingsScreenState();
}

class _SafetySettingsScreenState extends State<SafetySettingsScreen> {
  late Future<List<BlockedMember>> _blocked =
      Services.safety.blockedMembers(widget.account);
  bool _saving = false;

  Set<Topic> get _muted => widget.account.profile.mutedTopics;

  Future<void> _toggleMute(Topic topic, bool mute) async {
    setState(() {
      _saving = true;
      mute ? _muted.add(topic) : _muted.remove(topic);
    });
    try {
      await Services.profiles.update(widget.account);
    } catch (_) {
      setState(() => mute ? _muted.remove(topic) : _muted.add(topic));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't save. Check your connection."),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setFindable(bool on) async {
    final profile = widget.account.profile;
    setState(() {
      _saving = true;
      profile.findable = on;
    });
    try {
      await Services.profiles.update(widget.account);
    } catch (_) {
      setState(() => profile.findable = !on);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't save. Check your connection."),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _unblock(BlockedMember member) async {
    await Services.safety.unblock(widget.account, member.uid);
    if (!mounted) return;
    setState(() => _blocked = Services.safety.blockedMembers(widget.account));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You unblocked ${member.name}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canBeFindable =
        widget.account.profile.canBeFindableOn(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Safety & privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Muted topics', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            "Hide topics you don't want to see, for example if a topic is "
            'hard for you right now.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final topic in Topic.values)
                FilterChip(
                  avatar: Icon(topicIcon(topic), size: 18),
                  label: Text(topic.label),
                  selected: _muted.contains(topic),
                  onSelected: _saving ? null : (on) => _toggleMute(topic, on),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Finding you', style: textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show me in Find athlete'),
            subtitle: Text(
              canBeFindable
                  ? 'Members can find your ID card by searching your name or '
                      'browsing by sport and programme. Off: only people you '
                      'give your athlete ID to can find you.'
                  : widget.account.profile.role == UserRole.athlete
                      ? "Under-18s can't be found in search, to keep you safe. "
                          'Share your athlete ID instead.'
                      : 'Only athletes can be found by name.',
            ),
            value: widget.account.profile.findable && canBeFindable,
            onChanged: canBeFindable && !_saving ? _setFindable : null,
          ),
          const SizedBox(height: 24),
          Text('Blocked members', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            "You don't see their posts or replies, and they can't reply to "
            "yours. They aren't told.",
            style: textTheme.bodyMedium,
          ),
          FutureBuilder<List<BlockedMember>>(
            future: _blocked,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final members = snapshot.data ?? const <BlockedMember>[];
              if (members.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text("You haven't blocked anyone."),
                );
              }
              return Column(
                children: [
                  for (final member in members)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.block),
                      title: Text(member.name),
                      trailing: TextButton(
                        onPressed: () => _unblock(member),
                        child: const Text('Unblock'),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Reporting', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Use the ⋮ menu on any post or reply to report it. A moderator '
            'checks every report. Anything reported by several members is '
            'hidden until it has been checked.',
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
