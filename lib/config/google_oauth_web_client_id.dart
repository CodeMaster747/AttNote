/// OAuth 2.0 **Web** client ID (public; safe to ship in the app).
///
/// Source: `android/app/google-services.json` → `oauth_client` entry with
/// `client_type: 3` (Web client auto-created for this Firebase project).
///
/// If Google Sign-In on web still fails, open [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
/// → your project → **OAuth 2.0 Client IDs** → Web client → ensure
/// **Authorized JavaScript origins** includes `http://localhost:<port>` for
/// local dev and your production domain.
const String kGoogleOAuthWebClientId =
    '714889227250-vmo0qst7di9vtorsgh02v3cbtknsq57j.apps.googleusercontent.com';
