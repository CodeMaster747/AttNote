// screens/staff_mark_past_attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../models/attendance_model.dart';
import '../models/course_model.dart';
import '../models/subject_model.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/widgets.dart';
import '../services/firestore_service.dart';

/// Staff records attendance for every student on the subject's roster for a
/// given date. The topic, if planned for that day, is attached automatically.
class StaffMarkPastAttendanceScreen extends StatefulWidget {
  final Subject subject;

  const StaffMarkPastAttendanceScreen({super.key, required this.subject});

  @override
  State<StaffMarkPastAttendanceScreen> createState() =>
      _StaffMarkPastAttendanceScreenState();
}

class _StaffMarkPastAttendanceScreenState
    extends State<StaffMarkPastAttendanceScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  DateTime _selectedDate = DateTime.now();
  int _numberOfSessions = 1;
  List<Map<String, dynamic>> _students = [];
  String? _topicForDay;
  bool _isLoading = false;
  bool _isSaving = false;

  // studentId -> sessionNumber -> status
  final Map<String, Map<int, AttendanceStatus>> _attendanceData = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final students =
          await _firestoreService.getRosterStudents(widget.subject.studentIds);
      final plans = await _firestoreService.getDayPlans(
        widget.subject.createdBy,
        widget.subject.id,
      );
      final key = DayPlan.dateKey(_selectedDate);
      final match = plans.where((p) => p.id == key);
      if (!mounted) return;
      setState(() {
        _students = students;
        _topicForDay = match.isNotEmpty ? match.first.topic : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _attendanceData.clear();
      });
      await _loadData();
    }
  }

  void _setAttendance(String studentId, int session, AttendanceStatus status) {
    setState(() {
      _attendanceData.putIfAbsent(studentId, () => {});
      _attendanceData[studentId]![session] = status;
    });
  }

  Future<void> _saveAttendance() async {
    for (final student in _students) {
      final id = student['id'] as String;
      for (int session = 1; session <= _numberOfSessions; session++) {
        if (_attendanceData[id]?[session] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Mark attendance for ${student['name'] ?? id} · Session $session',
              ),
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSaving = true);
    try {
      for (final student in _students) {
        final id = student['id'] as String;
        for (int session = 1; session <= _numberOfSessions; session++) {
          await _firestoreService.markAttendanceForPastDate(
            id,
            widget.subject.id,
            _selectedDate,
            session,
            _attendanceData[id]![session]!,
            _topicForDay,
          );
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance saved')),
      );
      setState(() => _attendanceData.clear());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving attendance: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: Text('Record attendance · ${widget.subject.name}')),
      body: Column(
        children: [
          Padding(
            padding: AppSpacing.pagePadding,
            child: Column(
              children: [
                AppCard(
                  onTap: _selectDate,
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 18, color: colors.textSecondary),
                      const Gap(AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Date',
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: colors.textTertiary)),
                            Text(
                              DateFormat('EEEE, MMMM d, yyyy')
                                  .format(_selectedDate),
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: colors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.edit_outlined,
                          size: 16, color: colors.textTertiary),
                    ],
                  ),
                ),
                const Gap(AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _topicForDay != null && _topicForDay!.isNotEmpty
                            ? 'Topic: $_topicForDay'
                            : 'No topic planned for this day',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colors.textSecondary),
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    Text('Sessions',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: colors.textSecondary)),
                    const Gap(AppSpacing.xs),
                    DropdownButton<int>(
                      value: _numberOfSessions,
                      items: List.generate(6, (i) => i + 1)
                          .map((n) =>
                              DropdownMenuItem(value: n, child: Text('$n')))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _numberOfSessions = v;
                          _attendanceData.clear();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty
                    ? const EmptyState(
                        title: 'No students on the roster',
                        message: 'Add students by email to record attendance.',
                        icon: Icons.people_outline,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                        itemCount: _students.length,
                        separatorBuilder: (_, __) => const Gap(AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final student = _students[index];
                          final id = student['id'] as String;
                          final name = (student['name'] ?? id).toString();
                          return AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    )),
                                const Gap(AppSpacing.sm),
                                ...List.generate(_numberOfSessions, (s) {
                                  final session = s + 1;
                                  final current = _attendanceData[id]?[session];
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: AppSpacing.xs),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 64,
                                          child: Text('S$session',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                      color:
                                                          colors.textSecondary)),
                                        ),
                                        Expanded(
                                          child: Wrap(
                                            spacing: AppSpacing.xs,
                                            children: [
                                              for (final st
                                                  in AttendanceStatus.values)
                                                ChoiceChip(
                                                  label: Text(_label(st)),
                                                  selected: current == st,
                                                  onSelected: (_) =>
                                                      _setAttendance(
                                                          id, session, st),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          if (_students.isNotEmpty)
            Padding(
              padding: AppSpacing.pagePadding,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveAttendance,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Saving…' : 'Save attendance'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _label(AttendanceStatus s) {
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
