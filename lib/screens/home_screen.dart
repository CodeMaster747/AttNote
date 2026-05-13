// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'subject_screen.dart';
import 'settings_screen.dart';
import 'analytics_screen.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/widgets.dart';
import '../services/auth_service.dart';
import '../screens/auth/profile_screen.dart';
import '../services/automatic_attendance_service.dart';
import '../services/analytics_service.dart';
import '../models/attendance_model.dart';
import '../widgets/feature_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';
  String _department = '';
  AttendanceAnalytics? _quickStats;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkAutomaticAttendance();
  }

  Future<void> _loadUserData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!mounted) return;

      final data = doc.data() ?? {};
      setState(() {
        _userName = data['name'] ?? '';
        _department = data['department'] ?? '';
      });

      final analyticsService = AnalyticsService();
      final now = DateTime.now();
      final analytics = await analyticsService.getAttendanceAnalytics(
        uid,
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now,
      );

      if (!mounted) return;
      setState(() {
        _quickStats = analytics;
        _loadingStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStats = false);
    }
  }

  Future<void> _checkAutomaticAttendance() async {
    final autoAttendanceService = AutomaticAttendanceService();
    await autoAttendanceService.initialize();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _confirmLogout(AuthService auth) async {
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.danger,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          const AmbientBackground(),
          RefreshIndicator(
            onRefresh: _loadUserData,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  floating: false,
                  backgroundColor: colors.background,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  title: Text(
                    'AttNote',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      tooltip: 'Log out',
                      onPressed: () => _confirmLogout(auth),
                    ),
                    const Gap(AppSpacing.xs),
                  ],
                ),

                SliverPadding(
                  padding: AppSpacing.pagePadding,
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Greeting
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.textTertiary,
                                  ),
                                ),
                                const Gap(2),
                                Text(
                                  _userName.isNotEmpty ? _userName : 'Student',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                                if (_department.isNotEmpty) ...[
                                  const Gap(2),
                                  Text(
                                    _department,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.textTertiary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          _Avatar(
                            label: _userName,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfileScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Gap(AppSpacing.lg),

                      // Quick stats
                      _buildQuickStatsCard(theme, colors),

                      const Gap(AppSpacing.lg),

                      // Quick access
                      SectionHeader(
                        title: 'Quick access',
                        subtitle: 'Jump to commonly used sections',
                      ),
                      const Gap(AppSpacing.sm),

                      FeatureCard(
                        title: 'Subjects & attendance',
                        description: 'Manage subjects and track attendance',
                        icon: Icons.school_outlined,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SubjectScreen()),
                        ),
                      ),
                      const Gap(AppSpacing.sm),
                      FeatureCard(
                        title: 'Analytics',
                        description: 'View attendance analytics and insights',
                        icon: Icons.insights_outlined,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                        ),
                      ),
                      const Gap(AppSpacing.sm),
                      FeatureCard(
                        title: 'Profile',
                        description: 'Manage your personal information',
                        icon: Icons.person_outline,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        ),
                      ),
                      const Gap(AppSpacing.sm),
                      FeatureCard(
                        title: 'Settings',
                        description: 'App settings and preferences',
                        icon: Icons.settings_outlined,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        ),
                      ),
                      const Gap(AppSpacing.lg),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard(ThemeData theme, AppColors colors) {
    if (_loadingStats) {
      return const _StatsSkeleton();
    }

    final percentage = _quickStats?.overallPercentage ?? 0.0;
    final totalPresent = _quickStats?.totalPresent ?? 0;
    final totalAbsent = _quickStats?.totalAbsent ?? 0;
    final totalClasses = _quickStats?.totalClasses ?? 0;

    final Color percentageColor;
    if (percentage >= 75) {
      percentageColor = colors.success;
    } else if (percentage >= 50) {
      percentageColor = colors.warning;
    } else {
      percentageColor = colors.danger;
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Last 30 days',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.textTertiary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              if (totalClasses > 0)
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: percentageColor,
                  ),
                ),
            ],
          ),
          const Gap(AppSpacing.sm),
          if (totalClasses == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'No attendance data yet. Add subjects to begin.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 6,
                backgroundColor: colors.surfaceMuted,
                valueColor: AlwaysStoppedAnimation<Color>(percentageColor),
              ),
            ),
            const Gap(AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Total',
                    value: totalClasses.toString(),
                    color: colors.textPrimary,
                  ),
                ),
                Container(width: 1, height: 28, color: colors.border),
                Expanded(
                  child: _StatItem(
                    label: 'Present',
                    value: totalPresent.toString(),
                    color: colors.textPrimary,
                  ),
                ),
                Container(width: 1, height: 28, color: colors.border),
                Expanded(
                  child: _StatItem(
                    label: 'Absent',
                    value: totalAbsent.toString(),
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const Gap(2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final initial = label.isNotEmpty ? label[0].toUpperCase() : 'S';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          shape: BoxShape.circle,
          border: Border.all(color: colors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLine(height: 12, width: 100),
          Gap(AppSpacing.sm),
          ShimmerLine(height: 6),
          Gap(AppSpacing.md),
          ShimmerLine(height: 14, width: 220),
        ],
      ),
    );
  }
}
