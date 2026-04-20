/// OAuth 2.0 **Web** client ID (public; safe to ship in the app).
///
/// This value is extracted from the Firebase project configuration.
/// The actual client ID is determined at build time based on the Firebase project.
///
/// For staging: attnote-staging project
/// For production: attnote-prod project
/// For development: attnote-dd1f2 project
///
/// If Google Sign-In on web still fails, open [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
/// → your project → **OAuth 2.0 Client IDs** → Web client → ensure
/// **Authorized JavaScript origins** includes your deployment domain.
///
/// IMPORTANT: This file should be regenerated for each environment during CI/CD.
const String kGoogleOAuthWebClientId =
    '714889227250-vmo0qst7di9vtorsgh02v3cbtknsq57j.apps.googleusercontent.com';
