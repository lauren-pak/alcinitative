import 'package:flutter/material.dart';

import '../models/account.dart';
import '../models/display_mode.dart';
import '../models/post.dart';
import 'easy/easy_compose_screen.dart';
import 'easy/easy_home_screen.dart';
import 'events/events_screen.dart';
import 'feed/capture_screen.dart';
import 'feed/compose_post_screen.dart';
import 'feed/huddle_screen.dart';
import 'profile/profile_screen.dart';

/// Signed-in home. Bottom bar: Events · Huddle · Profile ("Me" in Easy
/// mode). Events, the in-person meetups, is the main tab; Huddle is where
/// athletes share spotlights and answer questions, and posting starts from
/// there. New members land on their profile (with their ID card) first.
/// Follows the member's saved [DisplayMode].
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.account,
    required this.isNewAccount,
  });

  final Account account;
  final bool isNewAccount;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

enum _Tab { events, huddle, profile }

class _HomeShellState extends State<HomeShell> {
  late _Tab _tab = widget.isNewAccount ? _Tab.profile : _Tab.events;

  /// Bumped after posting so Huddle and the profile reload.
  int _version = 0;

  @override
  void initState() {
    super.initState();
    // Apply the member's saved view. After this frame, because changing it
    // rebuilds the whole app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      displayMode.value = widget.account.profile.displayMode;
    });
  }

  /// Standard: a spotlight starts at the camera (video first); a question
  /// opens the composer. Easy: the step-by-step guide, which asks which.
  /// [prompt]: answering this week's Huddle question.
  Future<void> _compose(PostType type, {WeeklyPrompt? prompt}) async {
    final created = await Navigator.of(context).push<Post>(
      MaterialPageRoute(
        builder: (_) => isEasyMode
            ? EasyComposeScreen(account: widget.account, prompt: prompt)
            : type == PostType.experience
            ? CaptureScreen(account: widget.account, prompt: prompt)
            : ComposePostScreen(
                account: widget.account,
                initialType: PostType.question,
              ),
      ),
    );
    if (created == null || !mounted) return;
    setState(() => _version++);
    if (created.isHeld) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEasyMode
                ? 'Thank you! A helper will check your post before others see it.'
                : 'Thanks! Your post will appear once a moderator has checked it. '
                      'You can see it on your profile.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: displayMode,
      builder: (context, mode, _) => _build(mode == DisplayMode.easy),
    );
  }

  Widget _build(bool easy) {
    return Scaffold(
      body: IndexedStack(
        index: _tab.index,
        children: [
          EventsScreen(account: widget.account),
          if (easy)
            EasyHomeScreen(
              key: ValueKey('easy-home-$_version'),
              account: widget.account,
              onCompose: () => _compose(PostType.experience),
              onAnswerPrompt: (prompt) =>
                  _compose(PostType.experience, prompt: prompt),
            )
          else
            HuddleScreen(
              key: ValueKey('huddle-$_version'),
              account: widget.account,
              onCompose: _compose,
              onAnswerPrompt: (prompt) =>
                  _compose(PostType.experience, prompt: prompt),
            ),
          ProfileScreen(
            key: ValueKey('profile-$_version'),
            account: widget.account,
            isNewAccount: widget.isNewAccount,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) => setState(() => _tab = _Tab.values[i]),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Events',
          ),
          const NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Huddle',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: easy ? 'Me' : 'Profile',
          ),
        ],
      ),
    );
  }
}
