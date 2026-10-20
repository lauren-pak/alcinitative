// Google sign-in client IDs from Google Cloud. See "Google sign-in setup" in
// CLAUDE.md. Until these are filled in, the Google buttons explain that
// Google sign-in isn't set up, instead of calling the SDK (which crashes on iOS
// without a client ID).

/// iOS OAuth client ID, e.g. `1234-abc.apps.googleusercontent.com`.
/// The reversed form also goes in `ios/Flutter/GoogleSignIn.xcconfig`.
const googleIosClientId =
    '427340183202-d8bhvu6v2g7plt2ruf3a9anqndi339fr.apps.googleusercontent.com';

/// Web OAuth client ID. Android needs it as the "server client ID".
const googleWebClientId = '';
