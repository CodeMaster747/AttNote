// screens/staff_mark_past_attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/attendance_model.dart';
import '../services/firestore_service.dart';

class StaffMarkPastAttendanceScreen extends StatefulWidget {
  final String classId;
  final String subjectName;

  const StaffMarkPastAttendanceScreen({
    super.key,
    required this.classId,
    required this.subjectName,
  });

  @override
  State<StaffMarkPastAttendanceScreen> createState() =>
      _StaffMarkPastAttendanceScreenState();
}

class _StaffMarkPastAttendanceScreenState
    extends State<StaffMarkPastAttendanceScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String staffId = FirebaseAuth.instance.currentUser!.uid;

  DateTime _selectedDate = DateTime.now();
  List<StudentInfo> _students = [];
  Map<String, dynamic>? _schedule;
  bool _isLoading = false;
  bool _isSaving = false;

  // Map: studentId -> sessionNumber -> AttendanceStatus
  final Map<String, Map<int, AttendanceStatus>> _attendanceData = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load students in this class
      final classDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(staffId)
          .collection('classes')
          .doc(widget.classId)
          .get();

      final studentIds = List<String>.from(
        classDoc.data()?['studentIds'] ?? [],
      );

      List<StudentInfo> students = [];
      for (var studentId in studentIds) {
        final studentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .get();

        if (studentDoc.exists) {
          students.add(
            StudentInfo(
              id: studentId,
              name: studentDoc.data()?['name'] ?? 'Unknown',
            ),
          );
        }
      }

      // Load schedule for the selected date
      final schedule = await _firestoreService.getSessionSchedule(
        staffId,
        widget.classId,
        _selectedDate,
      );

      if (mounted) {
        setState(() {
          _students = students;
          _schedule = schedule;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

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
        _attendanceData.clear();
      });
      await _loadData();
    }
  }

  Future<void> _saveAttendance() async {
    if (_schedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No schedule found for this date. Please create a schedule first.',
          ),
        ),
      );
      return;
    }

    final numberOfSessions = _schedule!['numberOfSessions'] as int? ?? 0;

    // Validate that attendance is marked for all students and sessions
    for (var student in _students) {
      for (int session = 1; session <= numberOfSessions; session++) {
        if (_attendanceData[student.id]?[session] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please mark attendance for ${student.name} - Session $session',
              ),
            ),
          );
          return;
        }
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final topicsData =
          _schedule!['sessionTopics'] as Map<dynamic, dynamic>? ?? {};

      for (var student in _students) {
        for (int session = 1; session <= numberOfSessions; session++) {
          final status = _attendanceData[student.id]![session]!;
          final topic = topicsData[session.toString()]?.toString();

          await _firestoreService.markAttendanceForPastDate(
            student.id,
            widget.subjectName,
            _selectedDate,
            session,
            status,
            topic,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance saved successfully')),
        );
        setState(() {
          _attendanceData.clear();
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

  void _setAttendance(String studentId, int session, AttendanceStatus status) {
    setState(() {
      _attendanceData.putIfAbsent(studentId, () => {});
      _attendanceData[studentId]![session] = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final numberOfSessions = _schedule?['numberOfSessions'] as int? ?? 0;
    final topicsData =
        _schedule?['sessionTopics'] as Map<dynamic, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(title: Text('Mark Attendance — ${widget.subjectName}')),
      body: Column(
        children: [
          // Date Selector
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            margin: const EdgeInsets.all(16),
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

          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_schedule == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_busy_rounded,
                      size: 56,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No schedule found for this date',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please create a schedule first',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _students.length,
                itemBuilder: (context, index) {
                  final student = _students[index];
                  return Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          student.name.isNotEmpty
                              ? student.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        student.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      children: List.generate(numberOfSessions, (sessionIndex) {
                        final session = sessionIndex + 1;
                        final topic =
                            topicsData[session.toString()]?.toString() ??
                            'No topic';
                        final currentStatus =
                            _attendanceData[student.id]?[session];

                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Session $session: $topic',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: const Text('Present'),
                                    selected:
                                        currentStatus ==
                                        AttendanceStatus.present,
                                    selectedColor:
                                        colorScheme.tertiaryContainer,
                                    onSelected: (selected) {
                                      if (selected) {
                                        _setAttendance(
                                          student.id,
                                          session,
                                          AttendanceStatus.present,
                                        );
                                      }
                                    },
                                  ),
                                  ChoiceChip(
                                    label: const Text('Absent'),
                                    selected:
                                        currentStatus ==
                                        AttendanceStatus.absent,
                                    selectedColor: colorScheme.errorContainer,
                                    onSelected: (selected) {
                                      if (selected) {
                                        _setAttendance(
                                          student.id,
                                          session,
                                          AttendanceStatus.absent,
                                        );
                                      }
                                    },
                                  ),
                                  ChoiceChip(
                                    label: const Text('Cancelled'),
                                    selected:
                                        currentStatus ==
                                        AttendanceStatus.cancelled,
                                    selectedColor:
                                        colorScheme.secondaryContainer,
                                    onSelected: (selected) {
                                      if (selected) {
                                        _setAttendance(
                                          student.id,
                                          session,
                                          AttendanceStatus.cancelled,
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                              if (sessionIndex < numberOfSessions - 1)
                                const Divider(),
                            ],
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),
            ),

          // Save Button
          if (_schedule != null && _students.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
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
            ),
        ],
      ),
    );
  }
}

class StudentInfo {
  final String id;
  final String name;

  StudentInfo({required this.id, required this.name});
}
