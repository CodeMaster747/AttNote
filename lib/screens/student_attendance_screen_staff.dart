// student_attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final String studentId;
  final String subjectName;

  const StudentAttendanceScreen({
    super.key,
    required this.studentId,
    required this.subjectName,
  });

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Stream<QuerySnapshot> _requestsStream;

  bool _loading = true;
  List<AttendanceRecord> _attendance = [];

  @override
  void initState() {
    super.initState();

    // final normalizedSubjectName = widget.subjectName.trim().toLowerCase();
    final normalizedSubjectName = widget.subjectName;

    // Stream to listen for pending attendance requests for this student and subject
    _requestsStream = _firestore
        .collection('attendanceRequests')
        .where('studentId', isEqualTo: widget.studentId)
        .where('subjectName', isEqualTo: normalizedSubjectName)
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots();

    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    final normalizedSubjectName = widget.subjectName.trim().toLowerCase();

    final snapshot = await _firestore
        .collection('users')
        .doc(widget.studentId)
        .collection('subjects')
        .doc(normalizedSubjectName)
        .collection('attendance')
        .orderBy('date', descending: true)
        .get();

    if (!mounted) return;

    final records = snapshot.docs.map((doc) {
      final data = doc.data();
      return AttendanceRecord(
        date: (data['date'] as Timestamp).toDate(),
        sessionNumber: data['sessionNumber'],
        status: data['status'],
      );
    }).toList();

    setState(() {
      _attendance = records;
      _loading = false;
    });
  }

  Future<void> _respondToRequest(
    QueryDocumentSnapshot doc,
    bool approve,
  ) async {
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final requestId = doc.id;
    final studentId = data['studentId'] as String;
    final subjectName = data['subjectName'] as String;
    final date = data['date'] as Timestamp;
    final sessionNumber = data['sessionNumber'] as int;
    final attendanceStatus = data['attendanceStatus'] as String;
    final staffId = data['staffId'] as String;

    try {
      await _firestore.collection('attendanceRequests').doc(requestId).update({
        'status': approve ? 'approved' : 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      if (approve) {
        // Write attendance record to student's collection
        final attendanceDocId = '${date.millisecondsSinceEpoch}_$sessionNumber';

        await _firestore
            .collection('users')
            .doc(studentId)
            .collection('subjects')
            .doc(subjectName.trim().toLowerCase())
            .collection('attendance')
            .doc(attendanceDocId)
            .set({
              'date': date.toDate(),
              'sessionNumber': sessionNumber,
              'status': attendanceStatus,
              'markedByStaff': true,
              'markedAt': FieldValue.serverTimestamp(),
              'staffId': staffId,
            });
      }

      // Refresh attendance and requests list
      await _loadAttendance();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Request ${approve ? 'approved' : 'rejected'} successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing request: $e')));
      }
    }
  }

  Color _getStatusColor(String status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'present':
        return colorScheme.tertiaryContainer;
      case 'absent':
        return colorScheme.errorContainer;
      case 'cancelled':
        return colorScheme.secondaryContainer;
      default:
        return colorScheme.surfaceContainerHighest;
    }
  }

  Color _getStatusForeground(String status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'present':
        return colorScheme.onTertiaryContainer;
      case 'absent':
        return colorScheme.onErrorContainer;
      case 'cancelled':
        return colorScheme.onSecondaryContainer;
      default:
        return colorScheme.onSurface;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'present':
        return Icons.check_circle_rounded;
      case 'absent':
        return Icons.cancel_rounded;
      case 'cancelled':
        return Icons.block_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Attendance — ${widget.subjectName}')),
      body: RefreshIndicator(
        onRefresh: _loadAttendance,
        child: CustomScrollView(
          slivers: [
            // ── Pending Requests Section ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Pending Requests',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: _requestsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        elevation: 0,
                        color: colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Error loading requests: ${snapshot.error}',
                            style: TextStyle(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }

                final requests = snapshot.data!.docs;

                if (requests.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainerLow,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox_rounded,
                                size: 40,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No pending requests',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final doc = requests[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final sessionNum = data['sessionNumber'];
                      final date = (data['date'] as Timestamp).toDate();
                      final status = data['attendanceStatus'] as String;

                      return Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainerLow,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: _getStatusColor(status),
                                child: Icon(
                                  _getStatusIcon(status),
                                  color: _getStatusForeground(status),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Session $sessionNum — ${status[0].toUpperCase()}${status.substring(1)}',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat(
                                        'EEE, d MMM yyyy',
                                      ).format(date),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: () => _respondToRequest(doc, true),
                                icon: const Icon(Icons.check_rounded),
                                tooltip: 'Approve',
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      colorScheme.tertiaryContainer,
                                  foregroundColor:
                                      colorScheme.onTertiaryContainer,
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton.filled(
                                onPressed: () => _respondToRequest(doc, false),
                                icon: const Icon(Icons.close_rounded),
                                tooltip: 'Reject',
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.errorContainer,
                                  foregroundColor: colorScheme.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: requests.length),
                  ),
                );
              },
            ),

            // ── Attendance Records Section ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  'Attendance Records',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_attendance.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_note_rounded,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No attendance records yet',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final att = _attendance[index];
                    return Card(
                      elevation: 0,
                      color: _getStatusColor(att.status),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          _getStatusIcon(att.status),
                          color: _getStatusForeground(att.status),
                        ),
                        title: Text(
                          'Session ${att.sessionNumber} — ${att.status[0].toUpperCase()}${att.status.substring(1)}',
                          style: TextStyle(
                            color: _getStatusForeground(att.status),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('EEE, d MMM yyyy').format(att.date),
                          style: TextStyle(
                            color: _getStatusForeground(
                              att.status,
                            ).withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    );
                  }, childCount: _attendance.length),
                ),
              ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }
}

class AttendanceRecord {
  final DateTime date;
  final int sessionNumber;
  final String status;

  AttendanceRecord({
    required this.date,
    required this.sessionNumber,
    required this.status,
  });
}
