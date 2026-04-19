// screens/auth/signup_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/network/connectivity_helper.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/widgets.dart';
import '../../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _departmentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedRole = 'student';
  final _auth = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    final online = await ConnectivityHelper.hasConnection;
    if (!online) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.registerWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        role: _selectedRole,
        department: _departmentController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. Welcome!')),
      );
      // AuthWrapper navigates to home via authStateChanges — no manual route.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthService.messageForAuthException(e)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.secondary, colorScheme.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.secondary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_outlined,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                    const Gap(AppSpacing.md),
                    Text(
                      'Create Account',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Gap(AppSpacing.xs),
                    Text(
                      'Register to start tracking attendance',
                      style: theme.textTheme.bodyMedium?.copyWith(
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
                            'Personal Information',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Gap(AppSpacing.md),
                          AppTextField(
                            controller: _nameController,
                            labelText: 'Full Name',
                            prefixIcon: Icons.badge_outlined,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your full name';
                              }
                              if (value.trim().length < 2) {
                                return 'Name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                          const Gap(AppSpacing.sm),
                          AppTextField(
                            controller: _emailController,
                            labelText: 'Email',
                            prefixIcon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
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

                          const Gap(AppSpacing.lg),
                          Text(
                            'Security',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Gap(AppSpacing.md),
                          AppTextField(
                            controller: _passwordController,
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
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const Gap(AppSpacing.sm),
                          AppTextField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            labelText: 'Confirm Password',
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),

                          const Gap(AppSpacing.lg),
                          Text(
                            'Academic Details',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Gap(AppSpacing.md),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Role',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const Gap(AppSpacing.xs),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment<String>(
                                value: 'student',
                                label: Text('Student'),
                                icon: Icon(Icons.school_outlined),
                              ),
                              ButtonSegment<String>(
                                value: 'staff',
                                label: Text('Staff'),
                                icon: Icon(Icons.work_outline),
                              ),
                            ],
                            selected: {_selectedRole},
                            onSelectionChanged: (selection) {
                              setState(() {
                                _selectedRole = selection.first;
                              });
                            },
                          ),
                          const Gap(AppSpacing.sm),
                          AppTextField(
                            controller: _departmentController,
                            labelText: 'Department',
                            prefixIcon: Icons.apartment_outlined,
                            hintText: 'e.g. Computer Science',
                            textInputAction: TextInputAction.done,
                            textCapitalization: TextCapitalization.words,
                            onFieldSubmitted: (_) => _signup(),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your department';
                              }
                              return null;
                            },
                          ),

                          const Gap(AppSpacing.lg),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: AppPrimaryButton(
                              label: 'Create Account',
                              onPressed: _isLoading ? null : _signup,
                              isLoading: _isLoading,
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
                          'Already have an account? ',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Sign In',
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
    );
  }
}
