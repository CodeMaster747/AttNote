// screens/staff_subject_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/widgets.dart';
import '../models/course_model.dart';
import '../models/subject_model.dart';
import '../services/firestore_service.dart';
import '../widgets/test_editor_sheet.dart';
import 'course_guide_screen.dart';
import 'staff_mark_past_attendance_screen.dart';

class StaffSubjectDetailScreen extends StatefulWidget {
  final Subject subject;

  const StaffSubjectDetailScreen({super.key, required this.subject});

  @override
  State<StaffSubjectDetailScreen> createState() =>
      _StaffSubjectDetailScreenState();
}

class _StaffSubjectDetailScreenState extends State<StaffSubjectDetailScreen> {
  final FirestoreService _service = FirestoreService();
  late Subject _subject;

  List<Map<String, dynamic>> _roster = [];
  bool _loadingRoster = true;

  String get _staffId => _subject.createdBy;

  @override
  void initState() {
    super.initState();
    _subject = widget.subject;
    _loadRoster();
  }

  Future<void> _refreshSubject() async {
    final s = await _service.getSubject(_staffId, _subject.id);
    if (s != null && mounted) setState(() => _subject = s);
  }

  Future<void> _loadRoster() async {
    setState(() => _loadingRoster = true);
    final roster = await _service.getRosterStudents(_subject.studentIds);
    if (!mounted) return;
    setState(() {
      _roster = roster;
      _loadingRoster = false;
    });
  }

  Future<void> _toggleCourseGuide(bool value) async {
    setState(() => _subject = _subject.copyWith(courseGuideEnabled: value));
    await _service.updateSubject(
      _staffId,
      _subject.id,
      {'courseGuideEnabled': value},
    );
  }

  Future<void> _confirmDelete() async {
    final colors = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete subject'),
        content: const Text(
          'This removes the subject for you and everyone enrolled, along with '
          'all attendance and content. This cannot be undone.',
        ),
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
      await _service.deleteSubject(_staffId, _subject.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: Text(_subject.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.fact_check_outlined),
              tooltip: 'Record attendance',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StaffMarkPastAttendanceScreen(subject: _subject),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete subject',
              onPressed: _confirmDelete,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Roster'),
              Tab(text: 'Planner'),
              Tab(text: 'Tests'),
              Tab(text: 'Content'),
            ],
          ),
        ),
        body: Column(
          children: [
            _HeaderCard(subject: _subject, onToggleGuide: _toggleCourseGuide),
            Expanded(
              child: TabBarView(
                children: [
                  _RosterTab(
                    loading: _loadingRoster,
                    roster: _roster,
                    onAdd: _addStudent,
                    onRemove: _removeStudent,
                  ),
                  _PlannerTab(
                    service: _service,
                    staffId: _staffId,
                    subject: _subject,
                  ),
                  _TestsTab(
                    service: _service,
                    staffId: _staffId,
                    subjectId: _subject.id,
                  ),
                  _ContentTab(
                    service: _service,
                    staffId: _staffId,
                    subjectId: _subject.id,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addStudent(String email) async {
    final result =
        await _service.addStudentToStaffSubjectByEmail(_subject, email);
    if (!mounted) return;
    final messages = {
      AddStudentResult.added: 'Student added',
      AddStudentResult.alreadyAdded: 'Already enrolled',
      AddStudentResult.notFound: 'No account found for that email',
      AddStudentResult.notAStudent: 'That account is not a student',
      AddStudentResult.isSelf: 'You cannot add yourself',
      AddStudentResult.error: 'Could not add student',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(messages[result]!)),
    );
    if (result == AddStudentResult.added) {
      await _refreshSubject();
      await _loadRoster();
    }
  }

  Future<void> _removeStudent(String studentId) async {
    await _service.removeStudentFromStaffSubject(_subject, studentId);
    await _refreshSubject();
    await _loadRoster();
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.subject, required this.onToggleGuide});

  final Subject subject;
  final ValueChanged<bool> onToggleGuide;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final meta = [
      if (subject.department.isNotEmpty) subject.department,
      if (subject.section.isNotEmpty) subject.section,
      if (subject.taughtDays.isNotEmpty)
        '${subject.taughtDays.length} days/week',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meta.isNotEmpty)
              Text(meta,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.textSecondary)),
            const Gap(AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined,
                    size: 18, color: colors.textSecondary),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: Text('Course Guide',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      )),
                ),
                Switch(
                  value: subject.courseGuideEnabled,
                  onChanged: onToggleGuide,
                ),
              ],
            ),
            if (subject.courseGuideEnabled) ...[
              const Gap(AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseGuideScreen(subject: subject),
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Open Course Guide'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Roster
// ---------------------------------------------------------------------------

class _RosterTab extends StatefulWidget {
  const _RosterTab({
    required this.loading,
    required this.roster,
    required this.onAdd,
    required this.onRemove,
  });

  final bool loading;
  final List<Map<String, dynamic>> roster;
  final Future<void> Function(String email) onAdd;
  final Future<void> Function(String studentId) onRemove;

  @override
  State<_RosterTab> createState() => _RosterTabState();
}

class _RosterTabState extends State<_RosterTab> {
  final _emailCtrl = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_emailCtrl.text.trim().isEmpty) return;
    setState(() => _adding = true);
    await widget.onAdd(_emailCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _adding = false;
      _emailCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: AppSpacing.pagePadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _emailCtrl,
                  hintText: 'student@email.com',
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  onFieldSubmitted: (_) => _add(),
                ),
              ),
              const Gap(AppSpacing.xs),
              FilledButton(
                onPressed: _adding ? null : _add,
                child: _adding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.loading
              ? const Center(child: CircularProgressIndicator())
              : widget.roster.isEmpty
                  ? const EmptyState(
                      title: 'No students yet',
                      message: 'Add students by their account email above.',
                      icon: Icons.people_outline,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                      itemCount: widget.roster.length,
                      separatorBuilder: (_, __) => const Gap(AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final s = widget.roster[index];
                        final name = (s['name'] ?? s['id']).toString();
                        final email = (s['email'] ?? '').toString();
                        return AppCard(
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: colors.surfaceMuted,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Gap(AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: colors.textPrimary,
                                        )),
                                    if (email.isNotEmpty)
                                      Text(email,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                  color: colors.textTertiary)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.person_remove_outlined,
                                    size: 18),
                                tooltip: 'Remove',
                                onPressed: () =>
                                    widget.onRemove(s['id'] as String),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Planner (per-day topic + notes)
// ---------------------------------------------------------------------------

class _PlannerTab extends StatelessWidget {
  const _PlannerTab({
    required this.service,
    required this.staffId,
    required this.subject,
  });

  final FirestoreService service;
  final String staffId;
  final Subject subject;

  Future<void> _editDay(BuildContext context, {DayPlan? existing}) async {
    final result = await _DayEditorSheet.show(context, existing: existing);
    if (result != null) {
      await service.setDayPlan(staffId, subject.id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Stack(
      children: [
        StreamBuilder<List<DayPlan>>(
          stream: service.streamDayPlans(staffId, subject.id),
          builder: (context, snapshot) {
            final plans = snapshot.data ?? [];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (plans.isEmpty) {
              return const EmptyState(
                title: 'No days planned',
                message: 'Plan a day to set its topic and notes.',
                icon: Icons.event_note_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, 88),
              itemCount: plans.length,
              separatorBuilder: (_, __) => const Gap(AppSpacing.xs),
              itemBuilder: (context, index) {
                final p = plans[index];
                return AppCard(
                  onTap: () => _editDay(context, existing: p),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('EEEE, d MMM yyyy').format(p.date),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colors.textTertiary)),
                      const Gap(2),
                      Text(p.topic.isEmpty ? 'No topic' : p.topic,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              )),
                      if (p.notes.isNotEmpty) ...[
                        const Gap(AppSpacing.xs),
                        Text(p.notes,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary)),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          right: AppSpacing.md,
          bottom: AppSpacing.md,
          child: FloatingActionButton.extended(
            onPressed: () => _editDay(context),
            icon: const Icon(Icons.add),
            label: const Text('Plan a day'),
          ),
        ),
      ],
    );
  }
}

class _DayEditorSheet extends StatefulWidget {
  const _DayEditorSheet({this.existing});

  final DayPlan? existing;

  static Future<DayPlan?> show(BuildContext context, {DayPlan? existing}) {
    return showModalBottomSheet<DayPlan>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DayEditorSheet(existing: existing),
    );
  }

  @override
  State<_DayEditorSheet> createState() => _DayEditorSheetState();
}

class _DayEditorSheetState extends State<_DayEditorSheet> {
  late final TextEditingController _topicCtrl;
  late final TextEditingController _notesCtrl;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _topicCtrl = TextEditingController(text: widget.existing?.topic ?? '');
    _notesCtrl = TextEditingController(text: widget.existing?.notes ?? '');
    _date = widget.existing?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: AppSpacing.cardPadding,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Plan a day' : 'Edit day',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                )),
            const Gap(AppSpacing.md),
            AppCard(
              onTap: _pickDate,
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 18, color: colors.textSecondary),
                  const Gap(AppSpacing.sm),
                  Expanded(
                    child: Text(DateFormat('EEEE, d MMM yyyy').format(_date),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: colors.textPrimary)),
                  ),
                  Icon(Icons.edit_outlined, size: 16, color: colors.textTertiary),
                ],
              ),
            ),
            const Gap(AppSpacing.sm),
            AppTextField(
              controller: _topicCtrl,
              labelText: 'Topic',
              hintText: "What's being taught",
            ),
            const Gap(AppSpacing.sm),
            AppTextField(
              controller: _notesCtrl,
              labelText: "Day's notes",
              hintText: 'Notes for students',
              maxLines: 4,
            ),
            const Gap(AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        DayPlan(
                          id: DayPlan.dateKey(_date),
                          date: _date,
                          topic: _topicCtrl.text.trim(),
                          notes: _notesCtrl.text.trim(),
                        ),
                      );
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

class _TestsTab extends StatelessWidget {
  const _TestsTab({
    required this.service,
    required this.staffId,
    required this.subjectId,
  });

  final FirestoreService service;
  final String staffId;
  final String subjectId;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Stack(
      children: [
        StreamBuilder<List<CourseTest>>(
          stream: service.streamTests(staffId, subjectId),
          builder: (context, snapshot) {
            final tests = snapshot.data ?? [];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (tests.isEmpty) {
              return const EmptyState(
                title: 'No tests',
                message: 'Add a test with its date and portion.',
                icon: Icons.quiz_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, 88),
              itemCount: tests.length,
              separatorBuilder: (_, __) => const Gap(AppSpacing.xs),
              itemBuilder: (context, index) {
                final t = tests[index];
                return AppCard(
                  onTap: () async {
                    final edited =
                        await TestEditorSheet.show(context, initial: t);
                    if (edited != null) {
                      await service.upsertTest(staffId, subjectId, edited);
                    }
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                )),
                            Text(
                              '${DateFormat('d MMM yyyy').format(t.date)}'
                              '${t.portion.isNotEmpty ? ' · ${t.portion}' : ''}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () =>
                            service.deleteTest(staffId, subjectId, t.id),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          right: AppSpacing.md,
          bottom: AppSpacing.md,
          child: FloatingActionButton.extended(
            onPressed: () async {
              final t = await TestEditorSheet.show(context);
              if (t != null) await service.upsertTest(staffId, subjectId, t);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add test'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Content sections (collapsible custom rows)
// ---------------------------------------------------------------------------

class _ContentTab extends StatelessWidget {
  const _ContentTab({
    required this.service,
    required this.staffId,
    required this.subjectId,
  });

  final FirestoreService service;
  final String staffId;
  final String subjectId;

  Future<void> _edit(BuildContext context, {SubjectSection? existing}) async {
    final result = await _SectionEditorSheet.show(context, existing: existing);
    if (result != null) {
      await service.upsertSection(staffId, subjectId, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Stack(
      children: [
        StreamBuilder<List<SubjectSection>>(
          stream: service.streamSections(staffId, subjectId),
          builder: (context, snapshot) {
            final sections = snapshot.data ?? [];
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, 88),
              children: [
                Text(
                  'Students always see "Day-wise" and "Notes" rows built from '
                  'your planner. Add extra collapsible rows below.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.textTertiary),
                ),
                const Gap(AppSpacing.md),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (sections.isEmpty)
                  const EmptyState(
                    title: 'No custom rows',
                    message: 'Add a row such as "References" or "Assignments".',
                    icon: Icons.view_agenda_outlined,
                  )
                else
                  ...sections.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: AppCard(
                          onTap: () => _edit(context, existing: s),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: colors.textPrimary,
                                            )),
                                    if (s.content.isNotEmpty)
                                      Text(s.content,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  color: colors.textSecondary)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () => service.deleteSection(
                                    staffId, subjectId, s.id),
                              ),
                            ],
                          ),
                        ),
                      )),
              ],
            );
          },
        ),
        Positioned(
          right: AppSpacing.md,
          bottom: AppSpacing.md,
          child: FloatingActionButton.extended(
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add),
            label: const Text('Add row'),
          ),
        ),
      ],
    );
  }
}

class _SectionEditorSheet extends StatefulWidget {
  const _SectionEditorSheet({this.existing});

  final SubjectSection? existing;

  static Future<SubjectSection?> show(
    BuildContext context, {
    SubjectSection? existing,
  }) {
    return showModalBottomSheet<SubjectSection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SectionEditorSheet(existing: existing),
    );
  }

  @override
  State<_SectionEditorSheet> createState() => _SectionEditorSheetState();
}

class _SectionEditorSheetState extends State<_SectionEditorSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.existing?.content ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: AppSpacing.cardPadding,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Add row' : 'Edit row',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                )),
            const Gap(AppSpacing.md),
            AppTextField(
              controller: _titleCtrl,
              labelText: 'Title',
              hintText: 'e.g. References',
            ),
            const Gap(AppSpacing.sm),
            AppTextField(
              controller: _contentCtrl,
              labelText: 'Content',
              maxLines: 6,
            ),
            const Gap(AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (_titleCtrl.text.trim().isEmpty) return;
                      Navigator.pop(
                        context,
                        SubjectSection(
                          id: widget.existing?.id ?? '',
                          title: _titleCtrl.text.trim(),
                          type: SubjectSectionType.custom,
                          order: widget.existing?.order ?? 100,
                          content: _contentCtrl.text.trim(),
                        ),
                      );
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
