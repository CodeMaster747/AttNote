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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Delete Class'),
        content: const Text(
          'Are you sure you want to delete this class? This will remove it permanently.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
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
        const SnackBar(content: Text('Class deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete class: $e')));
    }
  }

  Future<void> _navigateToCreateClass() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateClassScreen()),
    );
    _loadClasses();
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
            onRefresh: _loadData,
            child: CustomScrollView(
              slivers: [
            SliverAppBar(
              expandedHeight: 140,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: Text(
                  'Staff Dashboard',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.tertiaryContainer.withValues(alpha: 0.5),
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
                              _staffName.isNotEmpty ? _staffName : 'Staff',
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
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: colorScheme.tertiaryContainer,
                        child: Text(
                          _staffName.isNotEmpty
                              ? _staffName[0].toUpperCase()
                              : 'S',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Gap(AppSpacing.lg),

                  // Quick Stats Row
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildQuickStat(
                            theme,
                            colorScheme,
                            Icons.class_rounded,
                            _classes.length.toString(),
                            'Classes',
                            colorScheme.primary,
                          ),
                          SizedBox(
                            width: 1,
                            height: 40,
                            child: ColoredBox(color: colorScheme.outlineVariant),
                          ),
                          StreamBuilder<QuerySnapshot>(
                            stream: _firestore
                                .collection('joinRequests')
                                .where('ownerId', isEqualTo: uid)
                                .where('status', isEqualTo: 'pending')
                                .snapshots(),
                            builder: (context, snapshot) {
                              final count = snapshot.data?.docs.length ?? 0;
                              return _buildQuickStat(
                                theme,
                                colorScheme,
                                Icons.pending_actions_rounded,
                                count.toString(),
                                'Pending',
                                count > 0
                                    ? colorScheme.error
                                    : colorScheme.onSurfaceVariant,
                              );
                            },
                          ),
                          SizedBox(
                            width: 1,
                            height: 40,
                            child: ColoredBox(color: colorScheme.outlineVariant),
                          ),
                          StreamBuilder<QuerySnapshot>(
                            stream: _firestore
                                .collection('attendanceRequests')
                                .where('staffId', isEqualTo: uid)
                                .where('status', isEqualTo: 'pending')
                                .snapshots(),
                            builder: (context, snapshot) {
                              final count = snapshot.data?.docs.length ?? 0;
                              return _buildQuickStat(
                                theme,
                                colorScheme,
                                Icons.fact_check_rounded,
                                count.toString(),
                                'Verify',
                                count > 0
                                    ? colorScheme.tertiary
                                    : colorScheme.onSurfaceVariant,
                              );
                            },
                          ),
                        ],
                      ),
                  ),

                  const Gap(AppSpacing.lg),

                  // Management Section
                  SectionHeader(
                    title: 'Management',
                    subtitle: 'Class and request operations',
                    padding: EdgeInsets.zero,
                  ),
                  const Gap(AppSpacing.sm),

                  FeatureCard(
                    title: 'Create Class',
                    description: 'Create and manage your classes',
                    icon: Icons.add_circle_outline,
                    accentColor: colorScheme.primary,
                    onTap: _navigateToCreateClass,
                  ),
                  const Gap(AppSpacing.sm),

                  // Join Requests with badge
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('joinRequests')
                        .where('ownerId', isEqualTo: uid)
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, snapshot) {
                      int pendingCount = snapshot.data?.docs.length ?? 0;

                      return FeatureCard(
                        title: 'Join Requests',
                        description: 'Approve or reject student requests',
                        icon: Icons.group_add_outlined,
                        accentColor: colorScheme.tertiary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StaffRequestsScreen(),
                            ),
                          );
                        },
                        trailing: pendingCount > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.error,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$pendingCount',
                                  style: TextStyle(
                                    color: colorScheme.onError,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                  const Gap(AppSpacing.sm),

                  // Attendance Verification Requests
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('attendanceRequests')
                        .where('staffId', isEqualTo: uid)
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, snapshot) {
                      int pendingCount = snapshot.data?.docs.length ?? 0;

                      return FeatureCard(
                        title: 'Verify Attendance',
                        description: 'Review student attendance submissions',
                        icon: Icons.assignment_turned_in_outlined,
                        accentColor: colorScheme.secondary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AttendanceRequestsScreen(),
                            ),
                          );
                        },
                        trailing: pendingCount > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.error,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$pendingCount',
                                  style: TextStyle(
                                    color: colorScheme.onError,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                  const Gap(AppSpacing.sm),

                  FeatureCard(
                    title: 'Topic Revision',
                    description: 'AI-powered suggestions based on attendance',
                    icon: Icons.lightbulb_outline,
                    accentColor: Colors.amber.shade700,
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
                    accentColor: colorScheme.onSurfaceVariant,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),

                  const Gap(AppSpacing.lg),

                  // Classes List
                  Row(
                    children: [
                      Text(
                        'Your Classes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (_classes.isNotEmpty)
                        Text(
                          '${_classes.length} ${_classes.length == 1 ? 'class' : 'classes'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const Gap(AppSpacing.sm),

                  if (_loading)
                    const ShimmerCardList(itemCount: 4)
                  else if (_classes.isEmpty)
                    const EmptyState(
                      title: 'No classes created yet',
                      message: 'Create your first class to get started',
                      icon: Icons.class_outlined,
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
                                backgroundColor: colorScheme.errorContainer,
                                foregroundColor: colorScheme.onErrorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ],
                          ),
                          child: AppCard(
                            padding: EdgeInsets.zero,
                            child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: colorScheme.primaryContainer,
                              child: Text(
                                cls.subjectName.isNotEmpty
                                    ? cls.subjectName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            title: Text(
                              cls.subjectName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${cls.department} - ${cls.className}',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chevron_right,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
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

  Widget _buildQuickStat(
    ThemeData theme,
    ColorScheme colorScheme,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const Gap(AppSpacing.xs),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
