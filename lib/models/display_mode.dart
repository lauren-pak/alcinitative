import 'package:flutter/foundation.dart';

/// How the app looks. **Easy** is a simplified view (big text and buttons,
/// one step at a time, pictures with every choice) designed with Special
/// Olympics athletes in mind, but anyone can choose it.
enum DisplayMode {
  standard('Standard'),
  easy('Easy');

  const DisplayMode(this.label);
  final String label;
}

/// The current mode for the whole app. Set from the signed-in member's
/// profile, or from the intro page's switch before sign-up.
final displayMode = ValueNotifier(DisplayMode.standard);

bool get isEasyMode => displayMode.value == DisplayMode.easy;
