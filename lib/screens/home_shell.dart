import 'package:flutter/material.dart';

import '../models/account.dart';
import '../models/display_mode.dart';
import '../models/post.dart';
import '../models/sign_up_data.dart';
import 'easy/easy_home_screen.dart';
import 'easy/easy_compose_screen.dart';
import 'feed/capture_screen.dart';
import 'feed/feed_screen.dart';
import 'profile/profile_screen.dart';

/// Signed-in home. Bottom bar: Feed · New post · Profile ("Home · Post · Me"
/// in Easy mode). "New post" opens the composer rather than a tab. New
/// members land on their profile (with their ID card) first; returning
/// members on the feed. Follows the member's saved [DisplayMode].
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

enum _Tab { feed, profile }

class _HomeShellState extends State<HomeShell> {
  late _Tab _tab = widget.isNewAccount ? _Tab.profile : _Tab.feed;

  /// Bumped after posting so the feed and profile reload.
  int _version = 0;

  bool get _isPublic => widget.account.profile.role == UserRole.public;

  @override
  void initState() {
    super.initState();
    // Apply the member's saved view. After this frame, because changing it
    // rebuilds the whole app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      displayMode.value = widget.account.profile.displayMode;
    });
  }

  Future<void> _compose() async {
    final created = await Navigator.of(context).push<Post>(
      // Standard: straight to the camera (video first). Easy: topic and
      // share-or-ask first, then the camera.
      MaterialPageRoute(
        builder: (_) => isEasyMode
            ? EasyComposeScreen(account: widget.account)
            : CaptureScreen(account: widget.account),
      ),
    );
    if (created == null || !mounted) return;
    setState(() => _version++);
    if (created.isHeld) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEasyMode
            ? 'Thank you! A helper will check your post before others see it.'
            : 'Thanks! Your post will appear once a moderator has checked it. '
                'You can see it on your profile.'),
      ));
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
          if (easy)
            EasyHomeScreen(
              key: ValueKey('easy-home-$_version'),
              account: widget.account,
            )
          else
            FeedScreen(
              key: ValueKey('feed-$_version'),
              account: widget.account,
            ),
          ProfileScreen(
            key: ValueKey('profile-$_version'),
            account: widget.account,
            isNewAccount: widget.isNewAccount,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab == _Tab.feed ? 0 : 2,
        onDestinationSelected: (i) {
          if (i == 1) {
            _compose();
          } else {
            setState(() => _tab = i == 0 ? _Tab.feed : _Tab.profile);
          }
        },
        destinations: [
          NavigationDestination(
            icon: Icon(easy ? Icons.home_outlined : Icons.forum_outlined),
            selectedIcon: Icon(easy ? Icons.home : Icons.forum),
            label: easy ? 'Home' : 'Feed',
          ),
          NavigationDestination(
            icon: Icon(_isPublic ? Icons.help_outline : Icons.add_box_outlined),
            label: easy
                ? (_isPublic ? 'Ask' : 'Post')
                : (_isPublic ? 'Ask' : 'New post'),
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
