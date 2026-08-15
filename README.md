# Athlete Advice App — Setup Guide

This is a basic Flutter scaffold for a social app where athletes post updates and share advice.
It uses **Firebase** (free tier) for user accounts (Firebase Auth) and the post database (Cloud Firestore).

## What's included

```
lib/
  main.dart                    # App entry point, routes based on login state
  models/
    app_user.dart              # User data model
    post.dart                  # Post data model
  services/
    auth_service.dart          # Sign up / log in / log out
    firestore_service.dart     # Create posts, stream posts, update profile
  screens/
    login_screen.dart
    signup_screen.dart
    home_screen.dart           # The main feed
    create_post_screen.dart
    profile_screen.dart
pubspec.yaml
```

## Setup steps (one-time)

1. **Create the Flutter project shell** (if you haven't already):
   ```
   flutter create athlete_app
   ```
   Then copy these `lib/` files and `pubspec.yaml` into it, overwriting the defaults.

2. **Install dependencies:**
   ```
   flutter pub get
   ```

3. **Create a free Firebase project:**
   - Go to https://console.firebase.google.com → "Add project" (free, no credit card needed for this tier)
   - In the project, enable **Authentication → Email/Password** sign-in method
   - Enable **Firestore Database** (start in test mode for development)

4. **Connect Firebase to your Flutter app:**
   - Install the FlutterFire CLI: `dart pub global activate flutterfire_cli`
   - Run inside your project folder: `flutterfire configure`
   - This auto-generates `lib/firebase_options.dart`, which `main.dart` imports — you don't write this file by hand.

5. **Run the app:**
   ```
   flutter run
   ```

## How the pieces fit together

- **Sign up** → creates a Firebase Auth account AND a matching document in the `users` Firestore collection (name, sport, bio).
- **Home feed** → streams all documents from the `posts` collection live, newest first, so new posts appear instantly for everyone.
- **Create post** → writes a new document to `posts`, tagged with the current user's name/sport.
- **Profile** → lets a user edit their own bio, saved back to their `users` document.

## Suggested next steps once this runs

- Add comments on posts (a `comments` sub-collection under each post)
- Add image uploads via Firebase Storage (also free tier)
- Filter feed by sport
- Add push notifications for replies (Firebase Cloud Messaging)
