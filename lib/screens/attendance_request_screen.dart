import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/widgets.dart';

class AttendanceRequestsScreen extends StatefulWidget {
  const AttendanceRequestsScreen({super.key});

  @override
  State<AttendanceRequestsScreen> createState() =>
      _AttendanceRequestsScreenState();
}

class _AttendanceRequestsScreenState extends State<AttendanceRequestsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final String staffId = FirebaseAuth.instance.currentUser!.uid;

  late final Stream<QuerySnapshot> _requestsStream;

  @override
  void initState() {
    super.initState();
    _requestsStream = _firestore
        .collection('attendanceRequests')
        .where('staffId', isEqualTo: staffId)
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots();
  }

  Future<void> _handleRequest(QueryDocumentSnapshot doc, bool approve) async {
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final requestId = doc.id;
    final studentId = data['studentId'] as String;
    final subjectId = data['subjectId'] as String;
    final date = data['date'] as Timestamp;
    final sessionNumber = data['sessionNumber'] as int;
    final attendanceStatus = data['attendanceStatus'] as String;

    try {
      await _firestore.collection('attendanceRequests').doc(requestId).update({
        'status': approve ? 'approved' : 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      if (approve) {
        final attendanceDocId = '${date.millisecondsSinceEpoch}_$sessionNumber';
        await _firestore
            .collection('users')
            .doc(studentId)
            .collection('subjects')
            .doc(subjectId)
            .collection('attendance')
            .doc(attendanceDocId)
            .set({
              'date': date.toDate(),
              'sessionNumber': sessionNumber,
              'status': attendanceStatus,
              'markedByStaff': true,
              'markedAt': FieldValue.serverTimestamp(),
            });
      }

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
        ).showSnackBar(SnackBar(content: Text('Error handling request: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Attendance')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _requestsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorState(
              title: 'Unable to load requests',
              message: 'Error loading requests: ${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const ShimmerCardList(itemCount: 5);
          }

          final requests = snapshot.data!.docs;

          if (requests.isEmpty) {
            return const EmptyState(
              title: 'No pending requests',
              message: 'Student attendance submissions will appear here',
              icon: Icons.fact_check_outlined,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.md,
            ),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final doc = requests[index];
              final data = doc.data() as Map<String, dynamic>;

              final studentName = data['studentName'] ?? 'Student';
              final subjectName = data['subjectName'] ?? 'Subject';
              final date = (data['date'] as Timestamp).toDate();
              final sessionNumber = data['sessionNumber'] ?? 1;
              final attendanceStatus = data['attendanceStatus'] ?? 'unknown';

              final statusColor = attendanceStatus == 'present'
                  ? colorScheme.tertiary
                  : attendanceStatus == 'absent'
                  ? colorScheme.error
                  : colorScheme.secondary;

              return AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            radius: 20,
                            child: Text(
                              studentName.isNotEmpty
                                  ? studentName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const Gap(AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studentName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  subjectName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
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
                              attendanceStatus[0].toUpperCase() +
                                  attendanceStatus.substring(1),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(AppSpacing.sm),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const Gap(AppSpacing.xxs),
                          Text(
                            DateFormat('d MMM yyyy').format(date),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Gap(AppSpacing.md),
                          Icon(
                            Icons.schedule_outlined,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const Gap(AppSpacing.xxs),
                          Text(
                            'Session $sessionNumber',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const Gap(AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AppSecondaryButton(
                            onPressed: () => _handleRequest(doc, false),
                            icon: Icons.close,
                            label: 'Reject',
                          ),
                          const Gap(AppSpacing.xs),
                          AppPrimaryButton(
                            onPressed: () => _handleRequest(doc, true),
                            icon: Icons.check,
                            label: 'Approve',
                          ),
                        ],
                      ),
                    ],
                  ),
              );
            },
          );
        },
      ),
    );
  }
}
