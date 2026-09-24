# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Athlete App": a Flutter app targeting **iOS and Android only**. It is a fresh `flutter create` scaffold (Sept 2026), so `lib/main.dart` is still the default counter template and there's no app-specific architecture yet. Update this file as structure is added.

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

## Identifiers

- Dart package: `athlete_app` (imports are `package:athlete_app/...`). Dart SDK `^3.12.2`.
- Display name "Athlete App": `CFBundleDisplayName` in `ios/Runner/Info.plist`, `android:label` in `android/app/src/main/AndroidManifest.xml`.
- The bundle ID and application ID are still the placeholder `com.example`: `com.example.athleteApp` (iOS, `ios/Runner.xcodeproj/project.pbxproj`) and `com.example.athlete_app` (Android, `android/app/build.gradle.kts`). Change them before publishing or registering with any backend service such as Firebase, since those services are keyed to them.
