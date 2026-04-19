// screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'subject_screen.dart';
import 'settings_screen.dart';
import 'analytics_screen.dart';
import '../core/theme/app_spacing.dart';
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

      // Load quick analytics
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
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          const AmbientBackground(),
          RefreshIndicator(
            onRefresh: _loadUserData,
            child: CustomScrollView(
              slivers: [
            // Custom App Bar with greeting
            SliverAppBar(
              expandedHeight: 140,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: Text(
                  'AttNote',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer.withValues(alpha: 0.5),
                        colorScheme.surface,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Logout',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        icon: Icon(
                          Icons.logout_rounded,
                          color: colorScheme.error,
                        ),
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.error,
                              foregroundColor: colorScheme.onError,
                            ),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      await auth.signOut();
                      // AuthWrapper navigates via authStateChanges — no manual route.
                    }
                  },
                ),
                const Gap(AppSpacing.xxs),
              ],
            ),

            SliverPadding(
              padding: AppSpacing.pagePadding,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Greeting Section
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Gap(AppSpacing.xxs),
                            Text(
                              _userName.isNotEmpty ? _userName : 'Student',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_department.isNotEmpty) ...[
                              const Gap(AppSpacing.xxs),
                              Text(
                                _department,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            _userName.isNotEmpty
                                ? _userName[0].toUpperCase()
                                : 'S',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Gap(AppSpacing.lg),

                  // Quick Stats Card
                  _buildQuickStatsCard(theme, colorScheme),

                  const Gap(AppSpacing.lg),

                  // Quick Access Section
                  SectionHeader(
                    title: 'Quick Access',
                    subtitle: 'Jump to commonly used sections',
                    padding: EdgeInsets.zero,
                  ),
                  const Gap(AppSpacing.sm),

                  FeatureCard(
                    title: 'Subjects & Attendance',
                    description: 'Manage your subjects and track attendance',
                    icon: Icons.school_outlined,
                    accentColor: colorScheme.primary,
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
                    accentColor: colorScheme.tertiary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnalyticsScreen(),
                      ),
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  FeatureCard(
                    title: 'Profile',
                    description: 'Manage your personal information',
                    icon: Icons.person_outline,
                    accentColor: colorScheme.secondary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileScreen(),
                      ),
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  FeatureCard(
                    title: 'Settings',
                    description: 'App settings and preferences',
                    icon: Icons.settings_outlined,
                    accentColor: colorScheme.onSurfaceVariant,
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

  Widget _buildQuickStatsCard(ThemeData theme, ColorScheme colorScheme) {
    if (_loadingStats) {
      return const SizedBox(height: 120, child: AppShimmer(child: _StatsSkeleton()));
    }

    final percentage = _quickStats?.overallPercentage ?? 0.0;
    final totalPresent = _quickStats?.totalPresent ?? 0;
    final totalAbsent = _quickStats?.totalAbsent ?? 0;
    final totalClasses = _quickStats?.totalClasses ?? 0;

    Color percentageColor;
    if (percentage >= 75) {
      percentageColor = colorScheme.tertiary;
    } else if (percentage >= 50) {
      percentageColor = colorScheme.secondary;
    } else {
      percentageColor = colorScheme.error;
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const Gap(AppSpacing.xs),
                Text(
                  'Monthly Overview',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Gap(AppSpacing.md),
            if (totalClasses == 0)
              const EmptyState(
                title: 'No attendance data yet',
                message: 'Start by adding subjects!',
                icon: Icons.bar_chart_rounded,
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
              )
            else
              Row(
                children: [
                  // Percentage circle
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: percentage / 100,
                          strokeWidth: 8,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          color: percentageColor,
                          strokeCap: StrokeCap.round,
                        ),
                        Center(
                          child: Text(
                            '${percentage.toStringAsFixed(0)}%',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: percentageColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(AppSpacing.lg),
                  Expanded(
                    child: Column(
                      children: [
                        _buildStatRow(
                          'Total Classes',
                          totalClasses.toString(),
                          colorScheme.onSurface,
                          theme,
                        ),
                        const Gap(AppSpacing.xs),
                        _buildStatRow(
                          'Present',
                          totalPresent.toString(),
                          colorScheme.tertiary,
                          theme,
                        ),
                        const Gap(AppSpacing.xs),
                        _buildStatRow(
                          'Absent',
                          totalAbsent.toString(),
                          colorScheme.error,
                          theme,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    String value,
    Color color,
    ThemeData theme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLine(height: 14, width: 120),
          Gap(AppSpacing.md),
          ShimmerLine(height: 14),
          Gap(AppSpacing.xs),
          ShimmerLine(height: 14, width: 220),
        ],
      ),
    );
  }
}
