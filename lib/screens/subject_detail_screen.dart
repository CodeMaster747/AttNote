// screens/subject_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for Firestore queries
import '../models/subject_model.dart';
import '../models/attendance_model.dart';
import '../services/firestore_service.dart';
import 'attendance_screen.dart';
import 'student_mark_past_attendance_screen.dart';

class SubjectDetailScreen extends StatefulWidget {
  final Subject subject;

  const SubjectDetailScreen({super.key, required this.subject});

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  AttendanceStats? _stats;
  bool _isLoading = true;
  AttendancePart? _selectedPart; // Selected attendance part (e.g. Term 1)

  int _numberOfSessions = 1; // How many classes today
  final Map<int, AttendanceStatus> _sessionAttendance =
      {}; // session number → status
  bool _isSavingAttendance = false;

  List<String> _assignedFacultyNames = [];
  bool _isLoadingFaculty = true;

  @override
  void initState() {
    super.initState();
    _determineCurrentPart();
    _loadData();
    _loadAssignedFacultyNames();
  }

  void _determineCurrentPart() {
    if (widget.subject.attendanceParts.isEmpty) return;

    final now = DateTime.now();
    // Default to first part
    AttendancePart current = widget.subject.attendanceParts.first;

    // Find part that includes today
    for (var part in widget.subject.attendanceParts) {
      if (now.isAfter(part.startDate.subtract(const Duration(days: 1))) &&
          now.isBefore(part.endDate.add(const Duration(days: 1)))) {
        current = part;
        break;
      }
      // Or find the latest part that has started?
      // If we are past 'Term 1' end date, we should probably default to 'Term 2' even if 'Term 2' hasn't strictly started?
      // Requirement: "after first 10 days are over, for cat2 the attendance will be restarted".
      // Implies sequential flow.
      if (now.isAfter(part.startDate)) {
        current = part;
      }
    }
    _selectedPart = current;
  }

  Future<void> _loadAssignedFacultyNames() async {
    // 0. Check if staff name is already available in the Subject object
    if (widget.subject.staffName.isNotEmpty) {
      if (mounted) {
        setState(() {
          _assignedFacultyNames = [widget.subject.staffName];
          _isLoadingFaculty = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingFaculty = true;
    });

    try {
      // 1. Get the current student/user document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid) // current user
          .get();
      final data = userDoc.data() ?? {};
      final assignedFacultyMap = data['assignedFaculty'] ?? {};

      // 2. Normalize subject name
      final normalizedSubjectName = widget.subject.name.trim().toLowerCase();

      // 3. Find all staff IDs assigned for this subject
      // Support multiple faculties per subject by mapping the value to a list if needed.
      var staffIds = [];
      final assignedStaff = assignedFacultyMap[normalizedSubjectName];
      if (assignedStaff is List) {
        staffIds = assignedStaff;
      } else if (assignedStaff is String) {
        staffIds = [assignedStaff];
      }

      // Fetch staff names
      List<String> facultyNames = [];
      for (final staffId in staffIds) {
        final staffDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(staffId)
            .get();
        if (staffDoc.exists) {
          facultyNames.add(staffDoc.data()?['name'] ?? staffId);
        }
      }

      setState(() {
        _assignedFacultyNames = facultyNames;
        _isLoadingFaculty = false;
      });
    } catch (e) {
      setState(() {
        _assignedFacultyNames = [];
        _isLoadingFaculty = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final stats = await _firestoreService.getAttendanceStats(
        uid,
        widget.subject.id,
        startDate: _selectedPart?.startDate,
        endDate: _selectedPart?.endDate,
      );
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load attendance data: $e')),
      );
    }
  }

  Widget _buildStatColumn(String label, String value, {Color? color}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Color getStatusColor(AttendanceStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case AttendanceStatus.present:
        return colorScheme.tertiaryContainer;
      case AttendanceStatus.absent:
        return colorScheme.errorContainer;
      case AttendanceStatus.cancelled:
        return colorScheme.secondaryContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject.name),
        actions: [
          if (widget.subject.attendanceParts.isNotEmpty)
            DropdownButtonHideUnderline(
              child: DropdownButton<AttendancePart>(
                value: _selectedPart,
                dropdownColor: colorScheme.surface,
                iconEnabledColor: colorScheme.onSurface,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
                items: widget.subject.attendanceParts.map((part) {
                  return DropdownMenuItem(value: part, child: Text(part.name));
                }).toList(),
                onChanged: (part) {
                  if (part != null) {
                    setState(() {
                      _selectedPart = part;
                      _loadData(); // Reload stats for new part
                    });
                  }
                },
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Attendance Stats Card
                  Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attendance Overview',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_selectedPart != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _selectedPart!.name,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (_stats != null) ...[
                            Row(
                              children: [
                                // Circular percentage indicator
                                SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value:
                                            (_stats!.attendancePercentage / 100)
                                                .clamp(0, 1),
                                        strokeWidth: 6,
                                        backgroundColor:
                                            colorScheme.surfaceContainerHighest,
                                        color:
                                            _stats!.attendancePercentage >= 75
                                            ? colorScheme.tertiary
                                            : _stats!.attendancePercentage >= 50
                                            ? colorScheme.secondary
                                            : colorScheme.error,
                                      ),
                                      Text(
                                        '${_stats!.attendancePercentage.toStringAsFixed(0)}%',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildStatColumn(
                                        'Total',
                                        _stats!.totalClasses.toString(),
                                        color: colorScheme.primary,
                                      ),
                                      _buildStatColumn(
                                        'Present',
                                        _stats!.presentCount.toString(),
                                        color: colorScheme.tertiary,
                                      ),
                                      _buildStatColumn(
                                        'Absent',
                                        _stats!.absentCount.toString(),
                                        color: colorScheme.error,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'No attendance data available',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action Buttons Row
                  Row(
                    children: [
                      /* Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add Staff'),
                          onPressed: _showAddStaffDialog,
                        ),
                      ), */
                      if (_assignedFacultyNames.isEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.edit_calendar),
                            label: const Text('Past Attendance'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      StudentMarkPastAttendanceScreen(
                                        subject: widget.subject,
                                      ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ...inside the children[] before/after Add Staff button:
                  if (_isLoadingFaculty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Loading faculty...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else if (_assignedFacultyNames.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'No staff assigned yet.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // "Faculty:" a bit lower to align with Chip(s)
                          Transform.translate(
                            offset: const Offset(
                              0,
                              1,
                            ), // Tune this value for your app!
                            child: const Text(
                              'Faculty:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Expanded to allow chips to wrap nicely
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _assignedFacultyNames
                                  .map((name) => Chip(label: Text(name)))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Today's Attendance Card
                  Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Attendance",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Show info if staff is assigned
                          if (_assignedFacultyNames.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: colorScheme.onPrimaryContainer,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Number of sessions is set by your assigned staff',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color:
                                                colorScheme.onPrimaryContainer,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text("Number of classes today: "),
                              DropdownButton<int>(
                                value: _numberOfSessions,
                                items: List.generate(10, (index) => index + 1)
                                    .map(
                                      (sessionCount) => DropdownMenuItem<int>(
                                        value: sessionCount,
                                        child: Text(sessionCount.toString()),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _assignedFacultyNames.isNotEmpty
                                    ? null // Disable if staff is assigned
                                    : (val) {
                                        if (val == null) return;
                                        setState(() {
                                          _numberOfSessions = val;
                                          _sessionAttendance.clear();
                                        });
                                      },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Attendance marking per session
                          ...List.generate(_numberOfSessions, (index) {
                            final sessionNum = index + 1;
                            final status = _sessionAttendance[sessionNum];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Text("Class $sessionNum:"),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ChoiceChip(
                                          label: const Text('Present'),
                                          selected:
                                              status ==
                                              AttendanceStatus.present,
                                          onSelected: (selected) {
                                            setState(() {
                                              _sessionAttendance[sessionNum] =
                                                  AttendanceStatus.present;
                                            });
                                          },
                                        ),
                                        ChoiceChip(
                                          label: const Text('Absent'),
                                          selected:
                                              status == AttendanceStatus.absent,
                                          onSelected: (selected) {
                                            setState(() {
                                              _sessionAttendance[sessionNum] =
                                                  AttendanceStatus.absent;
                                            });
                                          },
                                        ),
                                        ChoiceChip(
                                          label: const Text('Cancelled'),
                                          selected:
                                              status ==
                                              AttendanceStatus.cancelled,
                                          onSelected: (selected) {
                                            setState(() {
                                              _sessionAttendance[sessionNum] =
                                                  AttendanceStatus.cancelled;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 16),

                          // Save button
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isSavingAttendance
                                  ? null
                                  : () async {
                                      if (_sessionAttendance.length <
                                          _numberOfSessions) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Please select attendance for all classes',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      setState(() {
                                        _isSavingAttendance = true;
                                      });

                                      final now = DateTime.now();
                                      final dayOnly = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                      );

                                      try {
                                        // Fetch student doc to get assigned faculty
                                        final studentDoc =
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(uid)
                                                .get();

                                        final assignedFacultyMap =
                                            studentDoc
                                                .data()?['assignedFaculty'] ??
                                            {};
                                        final normalizedSubjectName = widget
                                            .subject
                                            .name
                                            .trim()
                                            .toLowerCase();
                                        final assignedStaffId =
                                            assignedFacultyMap[normalizedSubjectName];

                                        // Iterate sessions
                                        for (
                                          int session = 1;
                                          session <= _numberOfSessions;
                                          session++
                                        ) {
                                          final status =
                                              _sessionAttendance[session] ??
                                              AttendanceStatus.absent;

                                          final attendance = Attendance(
                                            id: '',
                                            subjectId: widget.subject.id,
                                            date: dayOnly,
                                            status: status,
                                            sessionNumber: session,
                                          );

                                          if (assignedStaffId != null &&
                                              assignedStaffId.isNotEmpty) {
                                            // Send an attendance verification request to assigned faculty
                                            await FirebaseFirestore.instance
                                                .collection(
                                                  'attendanceRequests',
                                                )
                                                .add({
                                                  'studentId': uid,
                                                  'studentName':
                                                      studentDoc
                                                          .data()?['name'] ??
                                                      '',
                                                  'staffId': assignedStaffId,
                                                  'subjectId':
                                                      widget.subject.id,
                                                  'subjectName':
                                                      widget.subject.name,
                                                  'date': dayOnly,
                                                  'sessionNumber': session,
                                                  'attendanceStatus':
                                                      status.name,
                                                  'requestedAt':
                                                      FieldValue.serverTimestamp(),
                                                  'status': 'pending',
                                                });
                                          } else {
                                            // No assigned faculty, mark attendance directly
                                            await _firestoreService
                                                .markAttendance(
                                                  uid,
                                                  widget.subject.name,
                                                  attendance,
                                                );
                                          }
                                        }

                                        await _loadData();
                                        if (!mounted) return;

                                        // Show different message based on whether staff is assigned
                                        final message =
                                            (assignedStaffId != null &&
                                                assignedStaffId.isNotEmpty)
                                            ? 'Attendance submitted and pending verification.'
                                            : 'Attendance updated.';

                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(message)),
                                        );

                                        setState(() {
                                          _sessionAttendance.clear();
                                          _numberOfSessions = 1;
                                        });
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to save attendance: $e',
                                            ),
                                          ),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            _isSavingAttendance = false;
                                          });
                                        }
                                      }
                                    },

                              label: _isSavingAttendance
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Save Attendance'),
                              icon: _isSavingAttendance
                                  ? const SizedBox.shrink()
                                  : const Icon(Icons.save_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick Actions
                  Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Actions',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AttendanceScreen(
                                      subject: widget.subject,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.calendar_month_rounded),
                              label: const Text('View Attendance History'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
