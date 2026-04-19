import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/staff_home_screen.dart';
import '../services/auth_service.dart';

/// Routes to [LoginScreen] or the correct home based on auth + Firestore role.
/// Navigation after sign-in/sign-out is driven only by [authStateChanges].
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
          return const LoginScreen();
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
              return const LoginScreen();
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

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.school_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'AttNote',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: colorScheme.primary,
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
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
