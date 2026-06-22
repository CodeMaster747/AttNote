// screens/subject_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/widgets.dart';
import '../models/subject_model.dart';
import '../models/attendance_model.dart';
import '../models/course_model.dart';
import '../services/firestore_service.dart';
import '../services/attendance_prediction_service.dart';
import 'attendance_screen.dart';
import 'course_guide_screen.dart';
import 'student_mark_past_attendance_screen.dart';

class SubjectDetailScreen extends StatefulWidget {
  final Subject subject;

  const SubjectDetailScreen({super.key, required this.subject});

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AttendancePredictionService _prediction = AttendancePredictionService();
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  AttendanceStats? _stats;
  AttendanceRisk? _risk;
  bool _isLoading = true;
  AttendancePart? _selectedPart;

  int _numberOfSessions = 1;
  final Map<int, AttendanceStatus> _sessionAttendance = {};
  bool _isSavingAttendance = false;

  bool get _isShared => widget.subject.isLinkedToStaff;
  String get _contentOwnerId =>
      _isShared ? widget.subject.linkedStaffId : uid;
  String get _contentSubjectId =>
      _isShared ? widget.subject.linkedStaffSubjectId : widget.subject.id;

  @override
  void initState() {
    super.initState();
    _determineCurrentPart();
    _loadData();
  }

  void _determineCurrentPart() {
    if (widget.subject.attendanceParts.isEmpty) return;
    final now = DateTime.now();
    AttendancePart current = widget.subject.attendanceParts.first;
    for (var part in widget.subject.attendanceParts) {
      if (now.isAfter(part.startDate.subtract(const Duration(days: 1))) &&
          now.isBefore(part.endDate.add(const Duration(days: 1)))) {
        current = part;
        break;
      }
      if (now.isAfter(part.startDate)) current = part;
    }
    _selectedPart = current;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _firestoreService.getAttendanceStats(
        uid,
        widget.subject.id,
        startDate: _selectedPart?.startDate,
        endDate: _selectedPart?.endDate,
      );
      final risk = await _prediction.computeRisk(uid, widget.subject);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _risk = risk;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load attendance data: $e')),
      );
    }
  }

  Future<void> _saveAttendance() async {
    if (_sessionAttendance.length < _numberOfSessions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select attendance for all classes')),
      );
      return;
    }
    setState(() => _isSavingAttendance = true);
    final now = DateTime.now();
    final dayOnly = DateTime(now.year, now.month, now.day);
    try {
      for (int session = 1; session <= _numberOfSessions; session++) {
        final status = _sessionAttendance[session] ?? AttendanceStatus.absent;
        await _firestoreService.markAttendance(
          uid,
          widget.subject.id,
          Attendance(
            id: '',
            subjectId: widget.subject.id,
            date: dayOnly,
            status: status,
            sessionNumber: session,
          ),
        );
      }
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Attendance updated')));
      setState(() {
        _sessionAttendance.clear();
        _numberOfSessions = 1;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _isSavingAttendance = false);
    }
  }

  Color _percentColor(AppColors colors, double pct) {
    if (pct >= 75) return colors.success;
    if (pct >= 50) return colors.warning;
    return colors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(widget.subject.name),
        actions: [
          if (widget.subject.attendanceParts.isNotEmpty)
            DropdownButtonHideUnderline(
              child: DropdownButton<AttendancePart>(
                value: _selectedPart,
                items: widget.subject.attendanceParts
                    .map((p) =>
                        DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: (part) {
                  if (part != null) {
                    setState(() => _selectedPart = part);
                    _loadData();
                  }
                },
              ),
            ),
          const Gap(AppSpacing.xs),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: AppSpacing.pagePadding,
                children: [
                  if (widget.subject.staffName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 14, color: colors.textTertiary),
                          const Gap(AppSpacing.xxs),
                          Text(widget.subject.staffName,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: colors.textSecondary)),
                        ],
                      ),
                    ),

                  if (_risk != null && _risk!.hasData && _risk!.level != RiskLevel.safe) ...[
                    _buildRiskBanner(theme, colors, _risk!),
                    const Gap(AppSpacing.md),
                  ],

                  _buildOverviewCard(theme, colors),
                  const Gap(AppSpacing.md),
                  _buildTodayCard(theme, colors),
                  const Gap(AppSpacing.md),

                  // History action
                  AppCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AttendanceScreen(subject: widget.subject),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 18, color: colors.textSecondary),
                        const Gap(AppSpacing.sm),
                        Expanded(
                          child: Text('Attendance history',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              )),
                        ),
                        Icon(Icons.arrow_forward_rounded,
                            size: 16, color: colors.textTertiary),
                      ],
                    ),
                  ),

                  if (_isShared && widget.subject.courseGuideEnabled) ...[
                    const Gap(AppSpacing.md),
                    AppCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CourseGuideScreen(
                            subject: widget.subject,
                            readOnly: true,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome_outlined,
                              size: 18, color: colors.textSecondary),
                          const Gap(AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Course Guide',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    )),
                                Text('Teaching plan, prerequisites & resources',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: colors.textTertiary)),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_rounded,
                              size: 16, color: colors.textTertiary),
                        ],
                      ),
                    ),
                  ],

                  if (_isShared) ...[
                    const Gap(AppSpacing.lg),
                    SectionHeader(
                      title: 'Course content',
                      subtitle: 'Shared by ${widget.subject.staffName.isEmpty ? 'your staff' : widget.subject.staffName}',
                    ),
                    const Gap(AppSpacing.sm),
                    _buildContentRows(theme, colors),
                  ],
                  const Gap(AppSpacing.lg),
                ],
              ),
            ),
    );
  }

  Widget _buildRiskBanner(ThemeData theme, AppColors colors, AttendanceRisk r) {
    final below = r.level == RiskLevel.below;
    final c = below ? colors.danger : colors.warning;
    final String message;
    if (below) {
      message = r.classesToRecover > 0
          ? 'Below 75%. Attend the next ${r.classesToRecover} class'
              '${r.classesToRecover == 1 ? '' : 'es'} to recover.'
          : 'Just below 75% — attend the next class to recover.';
    } else if (r.projectedBelowDate != null) {
      message =
          'At risk: may dip below 75% around ${DateFormat('d MMM').format(r.projectedBelowDate!)}. '
          'You can miss ${r.missableClasses} more.';
    } else {
      message =
          'At risk: only ${r.missableClasses} more class'
          '${r.missableClasses == 1 ? '' : 'es'} can be missed.';
    }

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(below ? Icons.error_outline : Icons.warning_amber_outlined,
              size: 18, color: c),
          const Gap(AppSpacing.sm),
          Expanded(
            child: Text(message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(ThemeData theme, AppColors colors) {
    final stats = _stats;
    final pct = stats?.attendancePercentage ?? 0;
    final pctColor = _percentColor(colors, pct);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attendance overview',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              )),
          if (_selectedPart != null) ...[
            const Gap(2),
            Text(_selectedPart!.name,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.textTertiary)),
          ],
          const Gap(AppSpacing.md),
          if (stats == null || stats.totalClasses == 0)
            Text('No attendance data yet.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colors.textTertiary))
          else
            Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: (pct / 100).clamp(0, 1),
                        strokeWidth: 6,
                        backgroundColor: colors.surfaceMuted,
                        valueColor: AlwaysStoppedAnimation(pctColor),
                      ),
                      Text('${pct.toStringAsFixed(0)}%',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          )),
                    ],
                  ),
                ),
                const Gap(AppSpacing.lg),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat(theme, colors, 'Total', stats.totalClasses),
                      _stat(theme, colors, 'Present', stats.presentCount,
                          color: colors.success),
                      _stat(theme, colors, 'Absent', stats.absentCount,
                          color: colors.danger),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _stat(ThemeData theme, AppColors colors, String label, int value,
      {Color? color}) {
    return Column(
      children: [
        Text('$value',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color ?? colors.textPrimary,
            )),
        const Gap(2),
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: colors.textTertiary)),
      ],
    );
  }

  Widget _buildTodayCard(ThemeData theme, AppColors colors) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's attendance",
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              )),
          const Gap(AppSpacing.sm),
          Row(
            children: [
              Text('Classes today',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colors.textSecondary)),
              const Spacer(),
              DropdownButton<int>(
                value: _numberOfSessions,
                items: List.generate(8, (i) => i + 1)
                    .map((n) =>
                        DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _numberOfSessions = v;
                    _sessionAttendance.clear();
                  });
                },
              ),
            ],
          ),
          const Gap(AppSpacing.xs),
          ...List.generate(_numberOfSessions, (i) {
            final session = i + 1;
            final status = _sessionAttendance[session];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text('Class $session',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colors.textSecondary)),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        for (final st in AttendanceStatus.values)
                          ChoiceChip(
                            label: Text(_statusLabel(st)),
                            selected: status == st,
                            onSelected: (_) => setState(
                                () => _sessionAttendance[session] = st),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const Gap(AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSavingAttendance ? null : _saveAttendance,
                  icon: _isSavingAttendance
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save'),
                ),
              ),
              const Gap(AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StudentMarkPastAttendanceScreen(subject: widget.subject),
                  ),
                ),
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: const Text('Past'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentRows(ThemeData theme, AppColors colors) {
    return StreamBuilder<List<DayPlan>>(
      stream: _firestoreService.streamDayPlans(_contentOwnerId, _contentSubjectId),
      builder: (context, daySnap) {
        final plans = daySnap.data ?? [];
        final notePlans = plans.where((p) => p.notes.isNotEmpty).toList();
        return StreamBuilder<List<SubjectSection>>(
          stream: _firestoreService.streamSections(
              _contentOwnerId, _contentSubjectId),
          builder: (context, secSnap) {
            final sections = secSnap.data ?? [];
            return Column(
              children: [
                _CollapsibleRow(
                  title: 'Day-wise',
                  subtitle: '${plans.length} ${plans.length == 1 ? 'day' : 'days'}',
                  icon: Icons.view_day_outlined,
                  child: plans.isEmpty
                      ? _emptyRow(theme, colors, 'No days added yet')
                      : Column(
                          children: plans
                              .map((p) => _dayLine(theme, colors, p,
                                  showNotes: false))
                              .toList(),
                        ),
                ),
                const Gap(AppSpacing.xs),
                _CollapsibleRow(
                  title: 'Notes',
                  subtitle:
                      '${notePlans.length} ${notePlans.length == 1 ? 'note' : 'notes'}',
                  icon: Icons.sticky_note_2_outlined,
                  child: notePlans.isEmpty
                      ? _emptyRow(theme, colors, 'No notes yet')
                      : Column(
                          children: notePlans
                              .map((p) =>
                                  _dayLine(theme, colors, p, showNotes: true))
                              .toList(),
                        ),
                ),
                for (final s in sections) ...[
                  const Gap(AppSpacing.xs),
                  _CollapsibleRow(
                    title: s.title,
                    icon: Icons.view_agenda_outlined,
                    child: s.content.isEmpty
                        ? _emptyRow(theme, colors, 'No content')
                        : Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(s.content,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: colors.textSecondary)),
                          ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _dayLine(ThemeData theme, AppColors colors, DayPlan p,
      {required bool showNotes}) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('EEE, d MMM yyyy').format(p.date),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: colors.textTertiary)),
          const Gap(2),
          Text(showNotes ? p.notes : (p.topic.isEmpty ? '—' : p.topic),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.textPrimary)),
        ],
      ),
    );
  }

  Widget _emptyRow(ThemeData theme, AppColors colors, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(text,
          style:
              theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary)),
    );
  }

  String _statusLabel(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// A bordered, animated collapsible row used for the student content section.
class _CollapsibleRow extends StatefulWidget {
  const _CollapsibleRow({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;

  @override
  State<_CollapsibleRow> createState() => _CollapsibleRowState();
}

class _CollapsibleRowState extends State<_CollapsibleRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(widget.icon, size: 18, color: colors.textSecondary),
                  const Gap(AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            )),
                        if (widget.subtitle != null)
                          Text(widget.subtitle!,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: colors.textTertiary)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: AppDuration.fast,
                    child: Icon(Icons.expand_more,
                        size: 20, color: colors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              child: widget.child,
            ),
            crossFadeState:
                _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: AppDuration.base,
          ),
        ],
      ),
    );
  }
}
