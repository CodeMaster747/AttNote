// screens/staff_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:gap/gap.dart';

import 'create_class_screen.dart';
import 'staff_requests_screen.dart';
import 'attendance_request_screen.dart';
import 'class_student_list_screen.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/widgets.dart';
import '../services/auth_service.dart';
import 'topic_revision_screen.dart';
import 'settings_screen.dart';
import '../widgets/feature_card.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  List<ClassData> _classes = [];
  bool _loading = true;
  String _staffName = '';
  String _department = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadClasses(), _loadProfile()]);
  }

  Future<void> _loadProfile() async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!mounted) return;
      final data = doc.data() ?? {};
      setState(() {
        _staffName = data['name'] ?? '';
        _department = data['department'] ?? '';
      });
    } catch (_) {}
  }

  Future<void> _loadClasses() async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('classes')
        .get();
    if (!mounted) return;
    setState(() {
      _classes = snapshot.docs
          .map((d) => ClassData.fromMap(d.data(), d.id))
          .toList();
      _loading = false;
    });
  }

  Future<void> _confirmDeleteClass(String classId) async {
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete class'),
        content: const Text(
          'Are you sure you want to delete this class? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.danger),
            child: const Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteClass(classId);
    }
  }

  Future<void> _deleteClass(String classId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('classes')
          .doc(classId)
          .delete();

      setState(() {
        _classes.removeWhere((cls) => cls.id == classId);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete class: $e')));
    }
  }

  Future<void> _navigateToCreateClass() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateClassScreen()),
    );
    _loadClasses();
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
            style: FilledButton.styleFrom(backgroundColor: colors.danger),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await auth.signOut();
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
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
            onRefresh: _loadData,
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
                    'Staff dashboard',
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
                                  _staffName.isNotEmpty ? _staffName : 'Staff',
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
                          _Avatar(label: _staffName),
                        ],
                      ),

                      const Gap(AppSpacing.lg),

                      // Quick stats row
                      AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _QuickStat(
                                value: _classes.length.toString(),
                                label: 'Classes',
                              ),
                            ),
                            Container(width: 1, height: 32, color: colors.border),
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: _firestore
                                    .collection('joinRequests')
                                    .where('ownerId', isEqualTo: uid)
                                    .where('status', isEqualTo: 'pending')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  final count = snapshot.data?.docs.length ?? 0;
                                  return _QuickStat(
                                    value: count.toString(),
                                    label: 'Pending',
                                    accent: count > 0 ? colors.danger : null,
                                  );
                                },
                              ),
                            ),
                            Container(width: 1, height: 32, color: colors.border),
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: _firestore
                                    .collection('attendanceRequests')
                                    .where('staffId', isEqualTo: uid)
                                    .where('status', isEqualTo: 'pending')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  final count = snapshot.data?.docs.length ?? 0;
                                  return _QuickStat(
                                    value: count.toString(),
                                    label: 'Verify',
                                    accent: count > 0 ? colors.warning : null,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Gap(AppSpacing.lg),

                      SectionHeader(
                        title: 'Management',
                        subtitle: 'Class and request operations',
                      ),
                      const Gap(AppSpacing.sm),

                      FeatureCard(
                        title: 'Create class',
                        description: 'Create and manage your classes',
                        icon: Icons.add_circle_outline,
                        onTap: _navigateToCreateClass,
                      ),
                      const Gap(AppSpacing.sm),

                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('joinRequests')
                            .where('ownerId', isEqualTo: uid)
                            .where('status', isEqualTo: 'pending')
                            .snapshots(),
                        builder: (context, snapshot) {
                          final pendingCount = snapshot.data?.docs.length ?? 0;
                          return FeatureCard(
                            title: 'Join requests',
                            description: 'Approve or reject student requests',
                            icon: Icons.group_add_outlined,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const StaffRequestsScreen(),
                                ),
                              );
                            },
                            trailing: pendingCount > 0
                                ? _CountBadge(count: pendingCount)
                                : null,
                          );
                        },
                      ),
                      const Gap(AppSpacing.sm),

                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('attendanceRequests')
                            .where('staffId', isEqualTo: uid)
                            .where('status', isEqualTo: 'pending')
                            .snapshots(),
                        builder: (context, snapshot) {
                          final pendingCount = snapshot.data?.docs.length ?? 0;
                          return FeatureCard(
                            title: 'Verify attendance',
                            description: 'Review student attendance submissions',
                            icon: Icons.assignment_turned_in_outlined,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AttendanceRequestsScreen(),
                                ),
                              );
                            },
                            trailing: pendingCount > 0
                                ? _CountBadge(count: pendingCount)
                                : null,
                          );
                        },
                      ),
                      const Gap(AppSpacing.sm),

                      FeatureCard(
                        title: 'Topic revision',
                        description: 'AI-powered suggestions based on attendance',
                        icon: Icons.lightbulb_outline,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TopicRevisionScreen(),
                            ),
                          );
                        },
                      ),
                      const Gap(AppSpacing.sm),
                      FeatureCard(
                        title: 'Settings',
                        description: 'App settings and preferences',
                        icon: Icons.settings_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),

                      const Gap(AppSpacing.xl),

                      // Classes list
                      Row(
                        children: [
                          Text(
                            'Your classes',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          if (_classes.isNotEmpty)
                            Text(
                              '${_classes.length} ${_classes.length == 1 ? 'class' : 'classes'}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.textTertiary,
                              ),
                            ),
                        ],
                      ),
                      const Gap(AppSpacing.sm),

                      if (_loading)
                        const ShimmerCardList(itemCount: 3)
                      else if (_classes.isEmpty)
                        const EmptyState(
                          title: 'No classes yet',
                          message: 'Create your first class to get started.',
                          icon: Icons.class_outlined,
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        )
                      else
                        ...List.generate(_classes.length, (index) {
                          final cls = _classes[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Slidable(
                              key: ValueKey(cls.id),
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                children: [
                                  SlidableAction(
                                    onPressed: (_) => _confirmDeleteClass(cls.id),
                                    icon: Icons.delete_outline,
                                    label: 'Delete',
                                    backgroundColor: colors.danger.withValues(alpha: 0.12),
                                    foregroundColor: colors.danger,
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                  ),
                                ],
                              ),
                              child: _ClassTile(
                                cls: cls,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ClassStudentListScreen(
                                        staffId: uid,
                                        classId: cls.id,
                                        subjectName: cls.subjectName,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }),

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
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.value,
    required this.label,
    this.accent,
  });

  final String value;
  final String label;
  final Color? accent;

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
            color: accent ?? colors.textPrimary,
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

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ClassTile extends StatefulWidget {
  const _ClassTile({required this.cls, required this.onTap});

  final ClassData cls;
  final VoidCallback onTap;

  @override
  State<_ClassTile> createState() => _ClassTileState();
}

class _ClassTileState extends State<_ClassTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final cls = widget.cls;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDuration.base,
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: _hovered ? colors.surfaceMuted : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: colors.border),
                ),
                alignment: Alignment.center,
                child: Text(
                  cls.subjectName.isNotEmpty
                      ? cls.subjectName[0].toUpperCase()
                      : '?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cls.subjectName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(2),
                    Text(
                      '${cls.department} · ${cls.className}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Gap(AppSpacing.sm),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final initial = label.isNotEmpty ? label[0].toUpperCase() : 'S';
    return Container(
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
    );
  }
}

class ClassData {
  final String id;
  final String subjectName;
  final String department;
  final String className;
  final String subjectId;

  ClassData({
    required this.id,
    required this.subjectName,
    required this.department,
    required this.className,
    required this.subjectId,
  });

  factory ClassData.fromMap(Map<String, dynamic> data, String id) => ClassData(
        id: id,
        subjectId: data['subjectId'] ?? '',
        subjectName: data['subjectName'] ?? '',
        department: data['department'] ?? '',
        className: data['className'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'subjectName': subjectName,
        'department': department,
        'className': className,
      };
}
