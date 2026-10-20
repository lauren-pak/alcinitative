import 'package:flutter/material.dart';

import '../models/account.dart';
import 'account_home_screen.dart';
import 'feed/feed_screen.dart';

/// Signed-in home: the feed and the member's own ID, as bottom tabs.
/// New members land on their ID card first; returning members on the feed.
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

class _HomeShellState extends State<HomeShell> {
  late int _tab = widget.isNewAccount ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          FeedScreen(account: widget.account),
          AccountHomeScreen(
            account: widget.account,
            isNewAccount: widget.isNewAccount,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge),
            label: 'My ID',
          ),
        ],
      ),
    );
  }
}
