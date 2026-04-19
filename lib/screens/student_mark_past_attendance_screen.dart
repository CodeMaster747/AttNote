// screens/student_mark_past_attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/attendance_model.dart';
import '../models/subject_model.dart';
import '../services/firestore_service.dart';

class StudentMarkPastAttendanceScreen extends StatefulWidget {
  final Subject subject;

  const StudentMarkPastAttendanceScreen({super.key, required this.subject});

  @override
  State<StudentMarkPastAttendanceScreen> createState() =>
      _StudentMarkPastAttendanceScreenState();
}

class _StudentMarkPastAttendanceScreenState
    extends State<StudentMarkPastAttendanceScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  DateTime _selectedDate = DateTime.now();
  int _numberOfSessions = 1;
  final Map<int, AttendanceStatus> _sessionAttendance = {};
  bool _isSaving = false;

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _sessionAttendance.clear();
      });
    }
  }

  Future<void> _saveAttendance() async {
    // Validate that all sessions have attendance marked
    if (_sessionAttendance.length < _numberOfSessions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please mark attendance for all sessions'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      for (int session = 1; session <= _numberOfSessions; session++) {
        final status = _sessionAttendance[session]!;

        await _firestoreService.markAttendanceForPastDate(
          uid,
          widget.subject.name,
          _selectedDate,
          session,
          status,
          null, // No topic for student-marked attendance
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance saved successfully')),
        );
        setState(() {
          _sessionAttendance.clear();
          _numberOfSessions = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving attendance: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('Mark Attendance — ${widget.subject.name}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Card(
              elevation: 0,
              color: colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You can mark attendance for past dates since no staff is assigned to this subject.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Date Selector
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              child: ListTile(
                leading: Icon(
                  Icons.calendar_today_rounded,
                  color: colorScheme.primary,
                ),
                title: const Text('Select Date'),
                subtitle: Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: _selectDate,
              ),
            ),

            const SizedBox(height: 16),

            // Number of Sessions
            Text(
              'Sessions',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _numberOfSessions,
                      decoration: const InputDecoration(
                        labelText: 'Number of Sessions',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.format_list_numbered_rounded),
                      ),
                      items: List.generate(10, (index) => index + 1)
                          .map(
                            (sessionCount) => DropdownMenuItem<int>(
                              value: sessionCount,
                              child: Text(
                                '$sessionCount session${sessionCount > 1 ? 's' : ''}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _numberOfSessions = val;
                            _sessionAttendance.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Session Attendance
            Text(
              'Mark Attendance',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            ...List.generate(_numberOfSessions, (index) {
              final sessionNum = index + 1;
              final status = _sessionAttendance[sessionNum];

              return Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session $sessionNum',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Present'),
                            selected: status == AttendanceStatus.present,
                            selectedColor: colorScheme.tertiaryContainer,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _sessionAttendance[sessionNum] =
                                      AttendanceStatus.present;
                                });
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Absent'),
                            selected: status == AttendanceStatus.absent,
                            selectedColor: colorScheme.errorContainer,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _sessionAttendance[sessionNum] =
                                      AttendanceStatus.absent;
                                });
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Cancelled'),
                            selected: status == AttendanceStatus.cancelled,
                            selectedColor: colorScheme.secondaryContainer,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _sessionAttendance[sessionNum] =
                                      AttendanceStatus.cancelled;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveAttendance,
                icon: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Attendance'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
