# CI/CD Setup Guide (from zero)

This project now includes CI workflows in `.github/workflows`.

## 1) Create GitHub repository

From project root:

```bash
git init
git add .
git commit -m "chore: initialize repo with security and CI baseline"
git branch -M main
git remote add origin <your-github-repo-url>
git push -u origin main
```

## 2) Enable branch protection (GitHub settings)

Target branch: `main`

Require:

- Pull request review before merge
- Status checks to pass before merge
  - `Flutter CI / quality`
  - `Firebase Rules Test / rules`
- Dismiss stale approvals (recommended)
- Block direct pushes to `main`

## 3) CI secrets you should add

Repository -> Settings -> Secrets and variables -> Actions:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `FIREBASE_SERVICE_ACCOUNT_JSON` (if using deploy jobs)

Repository -> Settings -> Variables -> Actions:

- `FIREBASE_STAGING_PROJECT_ID`
- `FIREBASE_PROD_PROJECT_ID`

Do not store secrets in git.

## 4) Optional deploy workflow plan

Recommended branches:

- `develop` -> auto deploy to staging
- `main` -> manual approval -> production

Use environment protection rules in GitHub:

- `staging`: auto allowed
- `production`: required reviewer approval

## 5) Required local prerequisites

- Flutter SDK
- Node.js 20+
- Firebase CLI

Install:

```bash
npm ci
flutter pub get
```

## 6) Validate pipeline locally before pushing

```bash
flutter analyze
flutter test
flutter build apk --debug
npm run test:rules
```

