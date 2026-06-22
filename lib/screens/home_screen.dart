// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';

import 'subject_screen.dart';
import 'settings_screen.dart';
import 'analytics_screen.dart';
import 'ai_insights_screen.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/widgets.dart';
import '../services/auth_service.dart';
import '../screens/auth/profile_screen.dart';
import '../services/automatic_attendance_service.dart';
import '../services/analytics_service.dart';
import '../models/attendance_model.dart';

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
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;
      final data = doc.data() ?? {};
      setState(() {
        _userName = data['name'] ?? '';
        _department = data['department'] ?? '';
      });

      final now = DateTime.now();
      final analytics = await AnalyticsService().getAttendanceAnalytics(
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
    await AutomaticAttendanceService().initialize();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _confirmLogout() async {
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
            style: FilledButton.styleFrom(backgroundColor: colors.danger),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await AuthService().signOut();
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      SidebarItem(
        icon: Icons.dashboard_outlined,
        label: 'Home',
        selected: true,
        onTap: () {},
      ),
      SidebarItem(
        icon: Icons.school_outlined,
        label: 'Subjects',
        onTap: () => _push(const SubjectScreen()),
      ),
      SidebarItem(
        icon: Icons.insights_outlined,
        label: 'Analytics',
        onTap: () => _push(const AnalyticsScreen()),
      ),
      SidebarItem(
        icon: Icons.auto_awesome_outlined,
        label: 'AI insights',
        onTap: () => _push(const AiInsightsScreen()),
      ),
      SidebarItem(
        icon: Icons.person_outline,
        label: 'Profile',
        onTap: () => _push(const ProfileScreen()),
      ),
      SidebarItem(
        icon: Icons.settings_outlined,
        label: 'Settings',
        onTap: () => _push(const SettingsScreen()),
      ),
    ];

    return AppShell(
      title: 'AttNote',
      userName: _userName.isNotEmpty ? _userName : 'Student',
      subtitle: _department,
      onLogout: _confirmLogout,
      items: items,
      body: _Dashboard(
        greeting: _getGreeting(),
        userName: _userName.isNotEmpty ? _userName : 'Student',
        department: _department,
        loadingStats: _loadingStats,
        stats: _quickStats,
        onRefresh: _loadUserData,
        onOpenSubjects: () => _push(const SubjectScreen()),
        onOpenAnalytics: () => _push(const AnalyticsScreen()),
        onOpenInsights: () => _push(const AiInsightsScreen()),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.greeting,
    required this.userName,
    required this.department,
    required this.loadingStats,
    required this.stats,
    required this.onRefresh,
    required this.onOpenSubjects,
    required this.onOpenAnalytics,
    required this.onOpenInsights,
  });

  final String greeting;
  final String userName;
  final String department;
  final bool loadingStats;
  final AttendanceAnalytics? stats;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenSubjects;
  final VoidCallback onOpenAnalytics;
  final VoidCallback onOpenInsights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          Text(greeting,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.textTertiary)),
          const Gap(2),
          Text(userName, style: theme.textTheme.headlineSmall),
          if (department.isNotEmpty) ...[
            const Gap(2),
            Text(department,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.textTertiary)),
          ],
          const Gap(AppSpacing.lg),
          if (loadingStats)
            const _StatsSkeleton()
          else
            _StatsCard(stats: stats),
          const Gap(AppSpacing.lg),
          SectionHeader(title: 'Quick access'),
          const Gap(AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _QuickTile(
                  icon: Icons.school_outlined,
                  title: 'Subjects',
                  subtitle: 'Track attendance',
                  onTap: onOpenSubjects,
                ),
              ),
              const Gap(AppSpacing.sm),
              Expanded(
                child: _QuickTile(
                  icon: Icons.insights_outlined,
                  title: 'Analytics',
                  subtitle: 'Trends & insights',
                  onTap: onOpenAnalytics,
                ),
              ),
              const Gap(AppSpacing.sm),
              Expanded(
                child: _QuickTile(
                  icon: Icons.auto_awesome_outlined,
                  title: 'AI insights',
                  subtitle: 'Risk predictions',
                  onTap: onOpenInsights,
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.lg),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final AttendanceAnalytics? stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final pct = stats?.overallPercentage ?? 0.0;
    final totalPresent = stats?.totalPresent ?? 0;
    final totalAbsent = stats?.totalAbsent ?? 0;
    final totalClasses = stats?.totalClasses ?? 0;

    final Color pctColor = pct >= 75
        ? colors.success
        : pct >= 50
            ? colors.warning
            : colors.danger;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Last 30 days',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: colors.textTertiary)),
              const Spacer(),
              if (totalClasses > 0)
                Text('${pct.toStringAsFixed(0)}%',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: pctColor,
                    )),
            ],
          ),
          const Gap(AppSpacing.sm),
          if (totalClasses == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('No attendance data yet. Add subjects to begin.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colors.textTertiary)),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0, 1),
                minHeight: 6,
                backgroundColor: colors.surfaceMuted,
                valueColor: AlwaysStoppedAnimation<Color>(pctColor),
              ),
            ),
            const Gap(AppSpacing.md),
            Row(
              children: [
                Expanded(child: _StatItem(label: 'Total', value: totalClasses)),
                Container(width: 1, height: 28, color: colors.border),
                Expanded(
                    child: _StatItem(label: 'Present', value: totalPresent)),
                Container(width: 1, height: 28, color: colors.border),
                Expanded(child: _StatItem(label: 'Absent', value: totalAbsent)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Column(
      children: [
        Text('$value',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            )),
        const Gap(2),
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: colors.textTertiary)),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: colors.border),
            ),
            child: Icon(icon, size: 18, color: colors.textSecondary),
          ),
          const Gap(AppSpacing.sm),
          Text(title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              )),
          const Gap(2),
          Text(subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.textTertiary)),
        ],
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
