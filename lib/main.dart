import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/display_mode.dart';
import 'screens/auth_gate.dart';
import 'services/firebase_auth_service.dart';
import 'services/firebase_media_repository.dart';
import 'services/firestore_feed_repository.dart';
import 'services/firestore_profile_repository.dart';
import 'services/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final auth = FirebaseAuthService();
  await auth.init();
  Services.auth = auth;
  Services.profiles = FirestoreProfileRepository();
  Services.feed = FirestoreFeedRepository();
  Services.media = FirebaseMediaRepository();
  runApp(const AthleteApp());
}

const _seed = Color(0xFF00897B);

ThemeData _standardTheme() => ThemeData(colorSchemeSeed: _seed, useMaterial3: true);

/// Easy mode: big tap targets and roomier layout. Text is enlarged
/// separately (see `builder` below) so it also applies inside dialogs.
ThemeData _easyTheme() {
  final base = _standardTheme();
  const big = Size(64, 64);
  const shape = StadiumBorder();
  return base.copyWith(
    visualDensity: VisualDensity.comfortable,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: big, shape: shape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: big, shape: shape),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 56)),
    ),
    navigationBarTheme: const NavigationBarThemeData(height: 88),
  );
}

class AthleteApp extends StatelessWidget {
  const AthleteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: displayMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Athlete App',
        debugShowCheckedModeBanner: false,
        theme: mode == DisplayMode.easy ? _easyTheme() : _standardTheme(),
        // Applies to every screen, including pushed pages and dialogs.
        builder: (context, child) {
          if (mode != DisplayMode.easy) return child!;
          final media = MediaQuery.of(context);
          // At least 130% text, more if the phone is set larger.
          final scale = media.textScaler.scale(1) < 1.3
              ? const TextScaler.linear(1.3)
              : media.textScaler;
          return MediaQuery(
            data: media.copyWith(textScaler: scale),
            child: child!,
          );
        },
        home: const AuthGate(),
      ),
    );
  }
}
