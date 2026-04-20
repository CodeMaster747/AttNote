# AttNote

AttNote is a Flutter + Firebase attendance management app for students and staff.

## Core Features

- Email/password and Google authentication
- Role-based routing (student/staff)
- Subject and attendance tracking
- Staff class management and approval workflows
- Analytics and trend views

## Local Development

```bash
flutter pub get
flutter run
```

## Security and CI/CD

- Security hardening guide: `SECURITY_SETUP.md`
- CI/CD bootstrap guide: `CICD_SETUP.md`
- Firestore rules: `firestore.rules`
- Storage rules: `storage.rules`
- Firestore rule tests: `tests/firestore.rules.test.js`

Run security rule tests:

```bash
npm ci
npm run test:rules
```
trigger checks
staging trigger
staging trigger
staging release trigger Mon Apr 20 11:19:40 IST 2026
