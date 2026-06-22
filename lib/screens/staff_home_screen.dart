// screens/staff_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:gap/gap.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/widgets.dart';
import '../models/subject_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'create_subject_screen.dart';
import 'staff_subject_detail_screen.dart';
import 'topic_revision_screen.dart';
import 'settings_screen.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  final FirestoreService _service = FirestoreService();
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  List<Subject> _subjects = [];
  bool _loading = true;
  String _staffName = '';
  String _department = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadSubjects(), _loadProfile()]);
  }

  Future<void> _loadProfile() async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;
      final data = doc.data() ?? {};
      setState(() {
        _staffName = data['name'] ?? '';
        _department = data['department'] ?? '';
      });
    } catch (_) {}
  }

  Future<void> _loadSubjects() async {
    try {
      final all = await _service.getSubjects(uid);
      if (!mounted) return;
      setState(() {
        _subjects = all.where((s) => s.isStaffOwned).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _loadSubjects());
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
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
        icon: Icons.add_circle_outline,
        label: 'Create subject',
        onTap: () => _push(const CreateSubjectScreen()),
      ),
      SidebarItem(
        icon: Icons.lightbulb_outline,
        label: 'Topic revision',
        onTap: () => _push(const TopicRevisionScreen()),
      ),
      SidebarItem(
        icon: Icons.settings_outlined,
        label: 'Settings',
        onTap: () => _push(const SettingsScreen()),
      ),
    ];

    return AppShell(
      title: 'Staff',
      userName: _staffName.isNotEmpty ? _staffName : 'Staff',
      subtitle: _department,
      onLogout: _confirmLogout,
      items: items,
      headerActions: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          tooltip: 'Create subject',
          onPressed: () => _push(const CreateSubjectScreen()),
        ),
      ],
      body: _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    int totalStudents = 0;
    for (final s in _subjects) {
      totalStudents += s.studentIds.length;
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          Text(_getGreeting(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.textTertiary)),
          const Gap(2),
          Text(_staffName.isNotEmpty ? _staffName : 'Staff',
              style: theme.textTheme.headlineSmall),
          if (_department.isNotEmpty) ...[
            const Gap(2),
            Text(_department,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.textTertiary)),
          ],
          const Gap(AppSpacing.lg),

          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: _Stat(value: '${_subjects.length}', label: 'Subjects'),
                ),
                Container(width: 1, height: 32, color: colors.border),
                Expanded(
                  child: _Stat(value: '$totalStudents', label: 'Students'),
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.lg),

          Row(
            children: [
              Expanded(
                child: SectionHeader(title: 'Your subjects'),
              ),
              TextButton.icon(
                onPressed: () => _push(const CreateSubjectScreen()),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New'),
              ),
            ],
          ),
          const Gap(AppSpacing.sm),

          if (_loading)
            const ShimmerCardList(itemCount: 3)
          else if (_subjects.isEmpty)
            const EmptyState(
              title: 'No subjects yet',
              message: 'Create your first subject to get started.',
              icon: Icons.class_outlined,
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            )
          else
            ..._subjects.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Slidable(
                    key: ValueKey(s.id),
                    endActionPane: ActionPane(
                      motion: const DrawerMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (_) => _confirmDelete(s),
                          icon: Icons.delete_outline,
                          label: 'Delete',
                          backgroundColor: colors.danger.withValues(alpha: 0.12),
                          foregroundColor: colors.danger,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ],
                    ),
                    child: _SubjectTile(
                      subject: s,
                      onTap: () => _push(StaffSubjectDetailScreen(subject: s)),
                    ),
                  ),
                )),
          const Gap(AppSpacing.lg),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Subject s) async {
    final colors = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete subject'),
        content: Text(
            'Delete "${s.name}"? This removes it for all enrolled students.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteSubject(uid, s.id);
      _loadSubjects();
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Column(
      children: [
        Text(value,
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

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({required this.subject, required this.onTap});
  final Subject subject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final meta = [
      if (subject.department.isNotEmpty) subject.department,
      if (subject.section.isNotEmpty) subject.section,
      '${subject.studentIds.length} students',
    ].join(' · ');

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              subject.name.isNotEmpty ? subject.name[0].toUpperCase() : '?',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          const Gap(AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    )),
                const Gap(2),
                Text(meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.textTertiary)),
              ],
            ),
          ),
          if (subject.courseGuideEnabled)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Icon(Icons.auto_awesome,
                  size: 16, color: colors.textTertiary),
            ),
          Icon(Icons.arrow_forward_rounded, size: 16, color: colors.textTertiary),
        ],
      ),
    );
  }
}
