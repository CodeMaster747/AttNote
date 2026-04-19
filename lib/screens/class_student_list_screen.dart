// screens/class_student_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/widgets.dart';
import 'student_attendance_screen_staff.dart';
import 'staff_session_schedule_screen.dart';
import 'staff_mark_past_attendance_screen.dart';

class ClassStudentListScreen extends StatefulWidget {
  final String staffId;
  final String classId;
  final String subjectName;
  // final String subjectId;

  const ClassStudentListScreen({
    super.key,
    required this.staffId,
    required this.classId,
    required this.subjectName,
    // required this.subjectId,
  });

  @override
  State<ClassStudentListScreen> createState() => _ClassStudentListScreenState();
}

class _ClassStudentListScreenState extends State<ClassStudentListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  List<StudentData> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final snapshot = await _firestore
        .collection('users')
        .doc(widget.staffId)
        .collection('classes')
        .doc(widget.classId)
        .collection('students')
        .get();

    if (!mounted) return;

    final students = snapshot.docs
        .map(
          (doc) => StudentData(
            id: doc.id,
            joinedAt: (doc.data()['joinedAt'] as Timestamp?)?.toDate(),
            approved: doc.data()['approved'] ?? false,
          ),
        )
        .toList();

    setState(() {
      _students = students;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subjectName),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule_outlined),
            tooltip: 'Schedule Sessions',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StaffSessionScheduleScreen(
                    classId: widget.classId,
                    subjectName: widget.subjectName,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_calendar_outlined),
            tooltip: 'Mark Past Attendance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StaffMarkPastAttendanceScreen(
                    classId: widget.classId,
                    subjectName: widget.subjectName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStudents,
        child: _loading
            ? const ShimmerCardList(itemCount: 6)
            : _students.isEmpty
            ? const EmptyState(
                title: 'No students enrolled yet',
                message: 'Students will appear here after approval',
                icon: Icons.people_outline,
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                itemCount: _students.length,
                itemBuilder: (context, index) {
                  final student = _students[index];
                  return FutureBuilder<DocumentSnapshot>(
                    future: _firestore
                        .collection('users')
                        .doc(student.id)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return AppCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: const ListTile(
                            leading: CircleAvatar(child: Icon(Icons.person)),
                            title: Text('Loading...'),
                          ),
                        );
                      }
                      final userData =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      final name = userData?['name'] ?? student.id;
                      final rollNo = userData?['rollNumber']?.toString() ?? '';

                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: rollNo.isNotEmpty
                              ? Text('Roll No: $rollNo')
                              : null,
                          trailing: Icon(
                            Icons.chevron_right,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentAttendanceScreen(
                                  studentId: student.id,
                                  subjectName: widget.subjectName,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class StudentData {
  final String id;
  final DateTime? joinedAt;
  final bool approved;

  StudentData({required this.id, this.joinedAt, this.approved = false});
}
