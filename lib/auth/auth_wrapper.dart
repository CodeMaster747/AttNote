import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../screens/auth/landing_screen.dart';
import '../screens/home_screen.dart';
import '../screens/staff_home_screen.dart';
import '../services/auth_service.dart';

/// Routes to [LandingScreen] (pre-auth) or the correct post-auth home based on
/// Firestore role. Navigation is driven only by [authStateChanges].
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashView();
        }

        final user = snapshot.data;
        if (user == null) {
          return const LandingScreen();
        }

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: authService.prepareSession(user),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const _SplashView();
            }

            if (userSnapshot.hasError) {
              return _AuthErrorView(
                message: 'Could not load your profile. Please try again.',
                onRetry: () async {
                  await authService.signOut();
                },
              );
            }

            final doc = userSnapshot.data;
            if (doc == null || !doc.exists) {
              return const LandingScreen();
            }

            final data = doc.data();
            final role = data?['role'] as String?;
            if (role == 'staff') {
              return const StaffHomeScreen();
            }
            return const HomeScreen();
          },
        );
      },
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                Icons.school_outlined,
                size: 24,
                color: colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'AttNote',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthErrorView extends StatelessWidget {
  const _AuthErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 20,
                    color: colors.danger,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () async {
                    await onRetry();
                  },
                  child: const Text('Sign out and retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
