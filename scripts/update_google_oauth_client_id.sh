#!/bin/bash
# Extract OAuth Web Client ID from google-services.json and update the Dart config file

set -e

GOOGLE_SERVICES_JSON="android/app/google-services.json"
CONFIG_FILE="lib/config/google_oauth_web_client_id.dart"

if [ ! -f "$GOOGLE_SERVICES_JSON" ]; then
  echo "Error: $GOOGLE_SERVICES_JSON not found"
  exit 1
fi

# Extract the OAuth client ID (client_type: 3 = Web client)
CLIENT_ID=$(grep -A 2 '"client_type": 3' "$GOOGLE_SERVICES_JSON" | grep '"client_id"' | head -1 | sed 's/.*"client_id": "\(.*\)".*/\1/')

if [ -z "$CLIENT_ID" ]; then
  echo "Error: Could not extract OAuth client ID from $GOOGLE_SERVICES_JSON"
  exit 1
fi

echo "Extracted OAuth Client ID: $CLIENT_ID"

# Update the Dart config file
cat > "$CONFIG_FILE" << EOF
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
/// IMPORTANT: This file is auto-generated during CI/CD. Do not edit manually.
const String kGoogleOAuthWebClientId = '$CLIENT_ID';
EOF

echo "Updated $CONFIG_FILE with OAuth Client ID"
