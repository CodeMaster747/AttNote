import 'package:flutter_dotenv/flutter_dotenv.dart';

/// OAuth 2.0 **Web** client ID, loaded from `.env`.
///
/// Required by `google_sign_in` on Web. Set `GOOGLE_OAUTH_WEB_CLIENT_ID`
/// in `.env` to your Web client ID from Google Cloud Console
/// (APIs & Services -> Credentials).
String get kGoogleOAuthWebClientId {
  final value = dotenv.maybeGet('GOOGLE_OAUTH_WEB_CLIENT_ID');
  if (value == null || value.isEmpty) {
    throw StateError(
      'Missing GOOGLE_OAUTH_WEB_CLIENT_ID in .env — copy .env.example '
      'to .env and fill it in.',
    );
  }
  return value;
}
