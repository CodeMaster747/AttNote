# Security Setup Guide (AttNote)

This guide covers immediate production-hardening tasks for Flutter + Firebase.

## 1) Firebase project strategy

Create separate Firebase projects:

- `attnote-dev`
- `attnote-staging`
- `attnote-prod`

Do **not** use one project for everything.

## 2) Authentication hardening

In Firebase Console -> Authentication:

1. Enable only required providers (Email/Password + Google).
2. Disable unused providers.
3. Add authorized domains for:
   - localhost
   - staging domain
   - production domain
4. Ensure OAuth consent screen is configured in Google Cloud Console.

## 3) Firestore + Storage rules

This repo now includes:

- `firestore.rules`
- `storage.rules`

Deploy commands:

```bash
firebase deploy --only firestore:rules
firebase deploy --only storage
```

Before deploy:

```bash
npm ci
npm run test:rules
```

## 4) Secrets policy

Never commit:

- Android keystores (`.jks`, `.keystore`)
- signing passwords
- service account JSON keys
- `.env` secrets

Use GitHub repository secrets for CI/CD.

## 5) Local data handling

- Do not log sensitive user data.
- For sensitive local storage, prefer secure storage.
- Keep PII access scoped to current user in rules.

## 6) Monitoring and incident readiness

Enable:

- Crashlytics
- Performance Monitoring
- Billing budget alerts
- Authentication abuse alerts

Create a rollback runbook:

- previous app build release
- previous rules commit hash
- contact owner/on-call

