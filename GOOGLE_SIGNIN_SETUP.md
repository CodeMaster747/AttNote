# Google Sign-In Setup for Multi-Environment Deployment

## Problem
Google Sign-In fails with "invalid email or password" error when deploying to staging/production because:
1. OAuth Client ID is environment-specific
2. Authorized domains must be configured in Google Cloud Console

## Solution Overview
1. Extract OAuth Client ID dynamically from `google-services.json` during CI/CD
2. Configure authorized domains in Google Cloud Console for each Firebase project

## Automated Steps (CI/CD)
The following happens automatically in GitHub Actions:
- `flutterfire configure` generates `firebase_options.dart` for the target project
- `flutterfire configure` also updates `android/app/google-services.json` with project-specific config
- `scripts/update_google_oauth_client_id.sh` extracts OAuth Client ID and updates `lib/config/google_oauth_web_client_id.dart`

## Manual Steps Required (One-time per Firebase project)

### For Staging Project (`attnote-staging`)

1. **Open Google Cloud Console**
   - Go to: https://console.cloud.google.com/apis/credentials
   - Select project: `attnote-staging`

2. **Find the OAuth 2.0 Client ID**
   - Look for "Web client (auto created by Google Service)"
   - Or find the client ID that matches: `714889227250-vmo0qst7di9vtorsgh02v3cbtknsq57j.apps.googleusercontent.com`

3. **Configure Authorized JavaScript origins**
   Add these URLs:
   ```
   http://localhost
   http://localhost:5000
   https://attnote-staging.web.app
   https://attnote-staging.firebaseapp.com
   ```

4. **Configure Authorized redirect URIs**
   Add these URLs:
   ```
   http://localhost
   http://localhost:5000/__/auth/handler
   https://attnote-staging.web.app/__/auth/handler
   https://attnote-staging.firebaseapp.com/__/auth/handler
   ```

5. **Save changes**

### For Production Project (`attnote-prod`)

Repeat the same steps but use production URLs:

1. **Open Google Cloud Console**
   - Go to: https://console.cloud.google.com/apis/credentials
   - Select project: `attnote-prod`

2. **Find the OAuth 2.0 Client ID**
   - Look for "Web client (auto created by Google Service)"

3. **Configure Authorized JavaScript origins**
   Add these URLs:
   ```
   http://localhost
   http://localhost:5000
   https://attnote-prod.web.app
   https://attnote-prod.firebaseapp.com
   ```
   
   If you have a custom domain, add it too:
   ```
   https://yourdomain.com
   ```

4. **Configure Authorized redirect URIs**
   Add these URLs:
   ```
   http://localhost
   http://localhost:5000/__/auth/handler
   https://attnote-prod.web.app/__/auth/handler
   https://attnote-prod.firebaseapp.com/__/auth/handler
   ```
   
   If you have a custom domain:
   ```
   https://yourdomain.com/__/auth/handler
   ```

5. **Save changes**

## Verify Firebase Authentication Settings

For each Firebase project (staging and production):

1. **Open Firebase Console**
   - Staging: https://console.firebase.google.com/project/attnote-staging
   - Production: https://console.firebase.google.com/project/attnote-prod

2. **Enable Google Sign-In**
   - Go to: Authentication → Sign-in method
   - Enable "Google" provider
   - Set support email

3. **Check Authorized Domains**
   - Go to: Authentication → Settings → Authorized domains
   - Ensure these are listed:
     - `localhost`
     - `attnote-staging.web.app` (or `attnote-prod.web.app`)
     - `attnote-staging.firebaseapp.com` (or `attnote-prod.firebaseapp.com`)
   - Add custom domain if applicable

## Testing

### Local Testing
```bash
# Test with staging config
firebase use staging
flutterfire configure --project=attnote-staging --platforms=web,android --yes
bash scripts/update_google_oauth_client_id.sh
flutter run -d chrome
```

### Staging Testing
1. Push to `develop` branch
2. Wait for GitHub Actions to complete
3. Visit: https://attnote-staging.firebaseapp.com
4. Test Google Sign-In

### Production Testing
1. Merge to `main` branch
2. Run production deployment workflow
3. Visit: https://attnote-prod.firebaseapp.com (or custom domain)
4. Test Google Sign-In

## Troubleshooting

### Error: "invalid email or password" on Google Sign-In
- Check that OAuth Client ID is correctly extracted (check CI/CD logs)
- Verify authorized domains in Google Cloud Console
- Verify Google Sign-In is enabled in Firebase Console

### Error: "redirect_uri_mismatch"
- Add the redirect URI to Google Cloud Console OAuth client
- Format: `https://your-domain.com/__/auth/handler`

### Error: "unauthorized_client"
- Check that the OAuth Client ID matches between:
  - `lib/config/google_oauth_web_client_id.dart`
  - Google Cloud Console OAuth client
  - `android/app/google-services.json`

## Files Modified
- `.github/workflows/deploy-staging.yml` - Added OAuth client ID extraction
- `.github/workflows/deploy-production.yml` - Added OAuth client ID extraction
- `scripts/update_google_oauth_client_id.sh` - Script to extract and update OAuth client ID
- `lib/config/google_oauth_web_client_id.dart` - Now auto-generated during CI/CD
