// screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gap/gap.dart';
import '../main.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/widgets.dart';
import '../services/firestore_service.dart';
import 'auth/profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentTheme = 'light';
  bool _autoAttendance = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    bool autoAttendance = false;
    if (uid != null) {
      final firestoreService = FirestoreService();
      autoAttendance = await firestoreService.getAutoAttendanceSetting(uid);
    }

    if (!mounted) return;
    setState(() {
      _currentTheme = prefs.getString('theme') ?? 'light';
      _autoAttendance = autoAttendance;
      _loading = false;
    });
  }

  Future<void> _setTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', theme);
    if (!mounted) return;
    setState(() {
      _currentTheme = theme;
    });

    final appState = MyApp.of(context);
    appState?.setTheme(theme);
  }

  Future<void> _setAutoAttendance(bool enabled) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final firestoreService = FirestoreService();
      await firestoreService.setAutoAttendanceSetting(uid, enabled);
      setState(() {
        _autoAttendance = enabled;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Automatic attendance enabled'
                : 'Automatic attendance disabled',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating setting: $e')));
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: currentPasswordCtrl,
                  obscureText: true,
                  labelText: 'Current Password',
                  prefixIcon: Icons.lock_outline,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const Gap(AppSpacing.sm),
                AppTextField(
                  controller: newPasswordCtrl,
                  obscureText: true,
                  labelText: 'New Password',
                  prefixIcon: Icons.lock_outline,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
                const Gap(AppSpacing.sm),
                AppTextField(
                  controller: confirmPasswordCtrl,
                  obscureText: true,
                  labelText: 'Confirm New Password',
                  prefixIcon: Icons.lock_outline,
                  validator: (v) {
                    if (v != newPasswordCtrl.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            AppPrimaryButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isLoading = true);
                      final scaffoldMessenger = ScaffoldMessenger.of(
                        this.context,
                      );

                      try {
                        final user = FirebaseAuth.instance.currentUser!;
                        final cred = EmailAuthProvider.credential(
                          email: user.email!,
                          password: currentPasswordCtrl.text,
                        );
                        await user.reauthenticateWithCredential(cred);
                        await user.updatePassword(newPasswordCtrl.text);

                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Password changed successfully'),
                          ),
                        );
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() => isLoading = false);
                        String msg = 'Failed to change password';
                        if (e.code == 'wrong-password') {
                          msg = 'Current password is incorrect';
                        } else if (e.code == 'weak-password') {
                          msg = 'New password is too weak';
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(msg)));
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
              label: 'Change',
              isLoading: isLoading,
            ),
          ],
        ),
      ),
    );

    currentPasswordCtrl.dispose();
    newPasswordCtrl.dispose();
    confirmPasswordCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = _currentTheme == 'dark';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          // Appearance Section
          const SectionHeader(title: 'Appearance', padding: EdgeInsets.zero),
          const Gap(AppSpacing.xs),

          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: Text(
                isDarkMode ? 'Dark theme enabled' : 'Light theme enabled',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              value: isDarkMode,
              onChanged: (bool value) {
                _setTheme(value ? 'dark' : 'light');
              },
              secondary: Icon(
                isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                color: colorScheme.primary,
              ),
            ),
          ),

          const Gap(AppSpacing.lg),

          // Attendance Section
          const SectionHeader(title: 'Attendance', padding: EdgeInsets.zero),
          const Gap(AppSpacing.xs),

          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              title: const Text('Automatic Attendance'),
              subtitle: Text(
                _autoAttendance
                    ? 'Auto-mark for personal subjects based on timetable'
                    : 'Manual attendance marking only',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              value: _autoAttendance,
              onChanged: _loading
                  ? null
                  : (bool value) {
                      _setAutoAttendance(value);
                    },
              secondary: Icon(
                _autoAttendance
                    ? Icons.auto_awesome_outlined
                    : Icons.touch_app_outlined,
                color: _autoAttendance
                    ? colorScheme.tertiary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const Gap(AppSpacing.lg),

          // Account Section
          const SectionHeader(title: 'Account', padding: EdgeInsets.zero),
          const Gap(AppSpacing.xs),

          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.person_outline, color: colorScheme.primary),
                  title: const Text('Account profile'),
                  subtitle: Text(
                    'Name, email, sign out',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(
                    Icons.email_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('Email'),
                  subtitle: Text(
                    FirebaseAuth.instance.currentUser?.email ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.lock_outline, color: colorScheme.primary),
                  title: const Text('Change Password'),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onTap: _showChangePasswordDialog,
                ),
              ],
            ),
          ),

          const Gap(AppSpacing.lg),

          // About Section
          const SectionHeader(title: 'About', padding: EdgeInsets.zero),
          const Gap(AppSpacing.xs),

          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('App Name'),
                  subtitle: Text(
                    'AttNote - Attendance Manager',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(
                    Icons.new_releases_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('Version'),
                  subtitle: Text(
                    '1.0.0',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Gap(AppSpacing.xl),
        ],
      ),
    );
  }
}
