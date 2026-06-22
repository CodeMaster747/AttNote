// screens/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../models/subject_model.dart';
import '../models/attendance_model.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/widgets.dart';
import '../services/firestore_service.dart';

class AttendanceScreen extends StatefulWidget {
  final Subject subject;

  const AttendanceScreen({super.key, required this.subject});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  List<Attendance> _attendanceList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    try {
      final attendance = await _firestoreService.getAttendance(
        uid,
        widget.subject.id,
      );
      if (!mounted) return;
      setState(() {
        _attendanceList = attendance
          ..sort((a, b) => b.date.compareTo(a.date)); // newest first
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading attendance: $e')));
    }
  }

  // Group attendance by date
  Map<String, List<Attendance>> _groupByDate() {
    final Map<String, List<Attendance>> grouped = {};
    for (final a in _attendanceList) {
      final key = DateFormat('yyyy-MM-dd').format(a.date);
      grouped.putIfAbsent(key, () => []).add(a);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.subject.name)),
      body: RefreshIndicator(
        onRefresh: _loadAttendance,
        child: _isLoading
            ? const ShimmerCardList(itemCount: 6)
            : _attendanceList.isEmpty
            ? const EmptyState(
                title: 'No attendance records found',
                message: 'Mark your attendance to see records here',
                icon: Icons.event_note_outlined,
              )
            : _buildGroupedList(theme, colorScheme),
      ),
    );
  }

  Widget _buildGroupedList(ThemeData theme, ColorScheme colorScheme) {
    final grouped = _groupByDate();
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final records = grouped[dateKey]!;
        final date = records.first.date;
        final dateStr = DateFormat('EEEE, d MMM yyyy').format(date);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const Gap(AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                dateStr,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...records.map((attendance) {
              final statusColor = _getStatusColor(attendance.status);
              final statusIcon = _getStatusIcon(attendance.status);
              final statusLabel =
                  attendance.status.name[0].toUpperCase() +
                  attendance.status.name.substring(1);

              return AppCard(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 20),
                      ),
                      const Gap(AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attendance.sessionNumber > 0
                                  ? 'Session ${attendance.sessionNumber}'
                                  : 'Session',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
              );
            }),
          ],
        );
      },
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case AttendanceStatus.present:
        return colorScheme.tertiary;
      case AttendanceStatus.absent:
        return colorScheme.error;
      case AttendanceStatus.cancelled:
        return colorScheme.secondary;
    }
  }

  IconData _getStatusIcon(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Icons.check_circle_rounded;
      case AttendanceStatus.absent:
        return Icons.cancel_rounded;
      case AttendanceStatus.cancelled:
        return Icons.event_busy_rounded;
    }
  }
}
