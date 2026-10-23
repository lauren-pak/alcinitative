import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/display_mode.dart';
import 'screens/auth_gate.dart';
import 'services/firebase_auth_service.dart';
import 'services/firebase_media_repository.dart';
import 'services/firestore_events_repository.dart';
import 'services/firestore_feed_repository.dart';
import 'services/firestore_profile_repository.dart';
import 'services/firestore_safety_repository.dart';
import 'services/firestore_verification_repository.dart';
import 'services/services.dart';
import 'widgets/brand.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final auth = FirebaseAuthService();
  await auth.init();
  Services.auth = auth;
  Services.profiles = FirestoreProfileRepository();
  Services.feed = FirestoreFeedRepository();
  Services.media = FirebaseMediaRepository();
  Services.safety = FirestoreSafetyRepository();
  Services.moderation = FirestoreModerationRepository();
  Services.events = FirestoreEventsRepository();
  Services.verification = FirestoreVerificationRepository();
  runApp(const AthleteApp());
}

/// Sporty and warm: coral, navy and gold on cream, bold type, round
/// shapes. Colours live in `Brand` (`lib/widgets/brand.dart`).
ThemeData _standardTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.coral,
    dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    primary: Brand.coral,
    onPrimary: Colors.white,
    secondary: Brand.navy,
    onSecondary: Colors.white,
    tertiary: Brand.gold,
    onTertiary: Brand.navy,
    surface: Brand.cream,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final text = base.textTheme.apply(
    bodyColor: Brand.navy,
    displayColor: Brand.navy,
  );
  const round = StadiumBorder();
  return base.copyWith(
    scaffoldBackgroundColor: Brand.cream,
    textTheme: text.copyWith(
      headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w900,
      ),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Brand.cream,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: text.headlineSmall?.copyWith(
        fontSize: 28,
        color: Brand.navy,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: round,
      side: BorderSide(color: Brand.navy.withValues(alpha: 0.12)),
      labelStyle: text.labelLarge,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: round,
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: round,
        side: BorderSide(color: Brand.navy.withValues(alpha: 0.2)),
        foregroundColor: Brand.navy,
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Brand.coral,
      foregroundColor: Colors.white,
      shape: const StadiumBorder(),
      extendedTextStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Brand.coral.withValues(alpha: 0.16),
      labelTextStyle: WidgetStatePropertyAll(
        text.labelMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Brand.coral,
      unselectedLabelColor: Brand.navy.withValues(alpha: 0.6),
      indicatorColor: Brand.coral,
      // Both from the text theme, so the tab animation can blend them.
      labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      unselectedLabelStyle: text.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

/// Easy mode: big tap targets and roomier layout. Text is enlarged
/// separately (see `builder` below) so it also applies inside dialogs.
ThemeData _easyTheme() {
  final base = _standardTheme();
  const big = Size(64, 64);
  const shape = StadiumBorder();
  return base.copyWith(
    visualDensity: VisualDensity.comfortable,
    // Build on the standard styles, so switching views can animate.
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style!.merge(
        FilledButton.styleFrom(minimumSize: big, shape: shape),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style!.merge(
        OutlinedButton.styleFrom(minimumSize: big, shape: shape),
      ),
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
