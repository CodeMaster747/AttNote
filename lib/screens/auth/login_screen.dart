import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/network/connectivity_helper.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/widgets.dart';
import '../../services/auth_service.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _googleLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final online = await ConnectivityHelper.hasConnection;
    if (!mounted) return;
    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) setState(() => _isLoading = false);
      // Navigation: AuthWrapper reacts to authStateChanges — no Navigator.pushReplacement.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.messageForAuthException(e))),
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    final online = await ConnectivityHelper.hasConnection;
    if (!mounted) return;
    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection')),
      );
      return;
    }

    setState(() => _googleLoading = true);

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        // User cancelled
        if (mounted) setState(() => _googleLoading = false);
        return;
      }
      if (mounted) setState(() => _googleLoading = false);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _googleLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.messageForAuthException(e))),
      );
    } catch (e) {
      if (mounted) setState(() => _googleLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    final formKey = GlobalKey<FormState>();
    var sending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reset password'),
          content: Form(
            key: formKey,
            child: AppTextField(
              controller: emailCtrl,
              labelText: 'Email',
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your email';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: sending
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      final online = await ConnectivityHelper.hasConnection;
                      if (!dialogContext.mounted) return;
                      if (!online) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('No internet connection'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => sending = true);
                      try {
                        await _authService.sendPasswordResetEmail(
                          emailCtrl.text.trim(),
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password reset email sent. Check your inbox.',
                              ),
                            ),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() => sending = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                AuthService.messageForAuthException(e),
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => sending = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              child: sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send link'),
            ),
          ],
        ),
      ),
    );

    emailCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final busy = _isLoading || _googleLoading;

    return Scaffold(
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
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
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.school_outlined,
                        size: 52,
                        color: Colors.white,
                      ),
                    ),
                    const Gap(AppSpacing.lg),
                    Text(
                      'AttNote',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Gap(AppSpacing.xs),
                    Text(
                      'Smart Attendance Management',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),

                    const Gap(AppSpacing.xl),

                    AppCard(
                      borderRadius: 20,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Gap(AppSpacing.xxs),
                          Text(
                            'Sign in to continue',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Gap(AppSpacing.lg),

                          AppTextField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            labelText: 'Email',
                            prefixIcon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) {
                              FocusScope.of(context)
                                  .requestFocus(_passwordFocusNode);
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(
                                r'^[^@]+@[^@]+\.[^@]+$',
                              ).hasMatch(value.trim())) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const Gap(AppSpacing.md),

                          AppTextField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: _obscurePassword,
                            labelText: 'Password',
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _login(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),

                          const Gap(AppSpacing.xs),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: busy ? null : _showForgotPasswordDialog,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot Password?',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ),

                          const Gap(AppSpacing.md),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: AppPrimaryButton(
                              label: 'Sign In',
                              onPressed: busy ? null : _login,
                              isLoading: _isLoading,
                            ),
                          ),

                          const Gap(AppSpacing.md),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: busy ? null : _signInWithGoogle,
                              icon: _googleLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.primary,
                                      ),
                                    )
                                  : const Icon(Icons.g_mobiledata_rounded),
                              label: const Text('Continue with Google'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Gap(AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const SignupScreen(),
                                    ),
                                  );
                                },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Sign up',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
