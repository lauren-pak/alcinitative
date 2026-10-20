# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Athlete App": a Flutter app targeting **iOS and Android only**. It is a safe space for athletes to share experiences and advice under four topics (injury, training, sports nutrition, competition). The backend is **Firebase**: Auth for sign-in, and Cloud Firestore in `asia-southeast1` (Singapore) for profiles. The feed isn't built yet.

Safeguarding and Singapore's **PDPA** are core requirements, not polish. Read `docs/pdpa.md` before touching personal data: it maps each obligation to code and lists what's still outstanding. Key rules:
- Members under 18 (`adultAge` in `lib/models/sign_up_data.dart`) get extra protections. Sign-up blocks under-13s (`minimumAge`), because the PDPA needs a parent's consent below 13.
- **`firestore.rules` is the real enforcement.** The app only mirrors it. Rules: profiles are owner-only; ID cards can be read one at a time but never listed; adults can't read under-18 cards; date of birth, `adultFrom` and the consent record can't be edited. Change the rules alongside any data-model change, and deploy them with `npx -y firebase-tools@latest deploy --only firestore:rules`.
- Never store email, phone or passwords in Firestore (Firebase Auth holds them), and never show date of birth on the ID card.
- Privacy Notice changes: edit `PrivacyNoticeScreen` and bump `privacyNoticeVersion`. It's written for 13-year-olds; keep it that way.
- Under-18 comment and video rules are only described in `MinorProtectionsNotice` so far. Implement them with the feed.

## Architecture

- `main.dart` initializes Firebase and sets `Services.auth` / `Services.profiles` (`lib/services/services.dart`), then shows `AuthGate`. `AuthGate` goes to `IntroScreen` if signed out, `AccountHomeScreen` if the profile exists, or `SignUpFlow(resumeUser:)` if they signed in but never finished.
- Screens only talk to the **`AuthService`** and **`ProfileRepository`** interfaces. The Firebase implementations are `FirebaseAuthService` and `FirestoreProfileRepository`. Tests swap in `FakeAuthService` and `InMemoryProfileRepository` (`test/fakes.dart`), so tests never touch Firebase. Keep new backend calls behind these interfaces.
- Firestore model: `users/{uid}` (private profile, with `dateOfBirth`, `adultFrom` = 18th birthday, `athleteId`, `consent{version, acceptedAt}`) and `athleteIds/{athleteId}` (the public card: `ownerUid`, name, sport, level, programme, `joinedAt`). Both are created in one transaction that retries if the random ID is taken.
- `SignUpFlow` (`lib/screens/sign_up/`): `RoleStep` (Privacy Notice consent, then role) → `MethodStep` (creates the **sign-in** account) → `AboutStep` → `ProfileStep` (saves the **profile**). The steps write into one shared `SignUpData`. Going back past the method step deletes the just-created sign-in, so abandoned sign-ups don't keep an email or phone number.
- `AuthMethodPicker` (`lib/widgets/`) is the Google / phone (+65) / email UI shared by `MethodStep` and `LoginScreen`. Its callbacks are async and return an error string, or null on success. After any log-in, `openAccountFor` (`auth_gate.dart`) routes to the account or resumes sign-up.
- Google: `GoogleAuth` (`google_sign_in` v7: `initialize` once, then `authenticate`) gets an ID token that `FirebaseAuthService` exchanges for a Firebase credential. `GoogleAuth.isConfigured` gates every SDK call, because the iOS SDK crashes without a client ID; keep that guard.
- Phone: real Firebase phone auth. Real SMS needs the Blaze (paid) plan; on the free plan, use test numbers set in the Firebase console.
- `YourDataScreen` covers the PDPA rights (view everything stored, download, edit via `EditProfileScreen`, delete). Delete checks `signedInRecently` first, so the profile is never deleted while the sign-in is left behind.
- `AccountHomeScreen` has **Share my ID** (`share_plus`, text only) and **Find athlete** (`FindAthleteScreen`, which uses `ProfileRepository.findById`; a permission-denied result reads as "not found").
- `lib/models/`: `sign_up_data.dart` holds the domain enums (each with a display `label`), the `sports` list, the age helpers and `SignUpData`. `account.dart` holds `Account` and the athlete ID helpers (`AA-` plus 6 characters, with no 0/O/1/I). When `sport` is `otherSport`, display it via `SignUpData.sportName`. The `sports` list includes the Special Olympics Singapore sports verified on inclusivesport.gov.sg; don't add SOSG sports without a source. There's no state-management package; plain `StatefulWidget`s only.

The Flutter project lives at the **repo root**, not in a subfolder. An earlier Flutter + Firebase prototype (Firebase project `athlete-app-e777d`) was deliberately removed and survives only in git history (commit `4e1a513`). Don't restore it, and don't use that Firebase project.

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
- **Firebase is pinned to the 4.x line** (`firebase_core ^4.15`, `firebase_auth ^6`, `cloud_firestore ^6`, which is Firebase iOS SDK 12). `firebase_core` 5 needs Firebase iOS SDK 13, which conflicts with GoogleSignIn-iOS 9 (used by `google_sign_in_ios` 6.3.x) over `app-check` and `gtm-session-fetcher`, so the build fails to resolve Swift packages. Upgrade only when `google_sign_in_ios` moves to GoogleSignIn 10.
- Adding a plugin with native code (like `google_sign_in` or `share_plus`) needs a full `flutter run` rebuild. Hot restart isn't enough.

## Identifiers

- Dart package: `athlete_app` (imports are `package:athlete_app/...`). Dart SDK `^3.12.2`.
- Display name "Athlete App": `CFBundleDisplayName` in `ios/Runner/Info.plist`, `android:label` in `android/app/src/main/AndroidManifest.xml`.
- App ID **`com.stridebystride`** on both platforms: iOS `PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj/project.pbxproj`, and Android `applicationId`/`namespace` in `android/app/build.gradle.kts`, with `MainActivity` in `android/app/src/main/kotlin/com/stridebystride/`. Google OAuth clients are registered against this ID, so changing it means redoing the Google setup.

## Firebase setup

Firebase belongs to the same Google Cloud project as the Google sign-in client (project number 427340183202), because Firebase only accepts Google tokens from its own project. The `firebase` binary in `/usr/local/bin` is Intel-only and broken on this Mac, so use `npx -y firebase-tools@latest …`. Its login is the user's own and is interactive. `lib/firebase_options.dart` is a placeholder that throws until `flutterfire configure` (in `~/.pub-cache/bin`) generates it for that project, with `--ios-bundle-id=com.stridebystride --android-package-name=com.stridebystride`.

## Google sign-in setup

Client IDs come from a Google Cloud project owned by the user. Until they're set, the Google buttons show "isn't set up yet".
- iOS: put the iOS OAuth client ID in `googleIosClientId` (`lib/config/google_sign_in_config.dart`), and its reversed form (`com.googleusercontent.apps.…`) in `GOOGLE_REVERSED_CLIENT_ID` (`ios/Flutter/GoogleSignIn.xcconfig`). `Info.plist`'s `CFBundleURLTypes` reads it from there.
- Android: put the **Web** OAuth client ID in `googleWebClientId`. It also needs an Android OAuth client with package `com.stridebystride` and the debug keystore's SHA-1.
