# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Athlete App": a Flutter app targeting **iOS and Android only**. It is a safe space for athletes to share experiences and advice under four topics (injury, training, sports nutrition, competition). It is an early prototype with no backend. Nothing is persisted yet, and screens use in-memory data.

Safeguarding is a core requirement, not polish. Members under 18 (`adultAge` in `lib/models/sign_up_data.dart`) get extra protections, and sign-up blocks anyone under `minimumAge` (13). The planned under-18 rules (hidden from search, comments only from other under-18s, videos reviewed before going live) are only described to users in `MinorProtectionsNotice` so far. Nothing enforces them yet, so keep that copy in sync when you implement them.

## Architecture

- `lib/main.dart` → `IntroScreen` ("Welcome to Athlete App", explains the app) → **Get started** pushes `SignUpFlow`.
- `lib/screens/sign_up/`: `SignUpFlow` owns a single mutable `SignUpData` and the step index. The step widgets (`RoleStep`, `MethodStep`, `AboutStep`, `ProfileStep`) write directly into that shared object, so values survive moving back and forth between steps. On completion it clears the stack and shows `SignUpCompleteScreen`, a placeholder for the feed.
- `MethodStep` offers Google, phone (+65, Singapore 8-digit numbers) and email sign-up. **Google and phone verification are simulated** (no OAuth, no SMS; any 6-digit code is accepted) until a backend is chosen. Email/password is only validated locally.
- `lib/models/sign_up_data.dart` holds the domain enums (`UserRole`, `SignUpMethod`, `AthleteCategory`, `Topic`, `CompetitionLevel`, each with a display `label`), the `sports` list and the age helpers. `AthleteCategory` (national / Paralympic / Special Olympics) is optional. The `sports` list includes the Special Olympics Singapore sports verified on inclusivesport.gov.sg. Don't add SOSG sports without a source. There's no state-management package; plain `StatefulWidget`s only.

The Flutter project lives at the **repo root**, not in a subfolder. An earlier Flutter + Firebase prototype was deliberately removed and survives only in git history (commit `4e1a513`). Don't restore it or assume the new app uses Firebase unless asked.

## Commands

```bash
flutter pub get                              # install dependencies
flutter run                                  # run on connected device/simulator (-d <id> to pick; `flutter devices` lists)
flutter analyze                              # lint (flutter_lints via analysis_options.yaml)
flutter test                                 # all tests
flutter test test/widget_test.dart           # single test file
flutter test --plain-name "<test name>"      # single test by name
flutter build apk                            # Android build
flutter build ios                            # iOS build (macOS + Xcode required)
```

## iOS build gotchas

- The repo must stay **outside iCloud-synced folders** (`~/Desktop`, `~/Documents` are synced on this Mac). iCloud adds extended attributes that break framework code-signing with "resource fork, Finder information, or similar detritus not allowed". The repo was moved to `~/Coding/alcinitative` for this reason. If it reappears, run `flutter clean`, then strip attributes outside `.git`.
- `IPHONEOS_DEPLOYMENT_TARGET` is **15.0** in `ios/Runner.xcodeproj/project.pbxproj`. Xcode 27 rejects the template's default of 13.0. Keep it ≥15 when adding a Podfile or plugins.

## Identifiers

- Dart package: `athlete_app` (imports are `package:athlete_app/...`). Dart SDK `^3.12.2`.
- Display name "Athlete App": `CFBundleDisplayName` in `ios/Runner/Info.plist`, `android:label` in `android/app/src/main/AndroidManifest.xml`.
- The bundle ID and application ID are still the placeholder `com.example`: `com.example.athleteApp` (iOS, `ios/Runner.xcodeproj/project.pbxproj`) and `com.example.athlete_app` (Android, `android/app/build.gradle.kts`). Change them before publishing or registering with any backend service such as Firebase, since those services are keyed to them.
