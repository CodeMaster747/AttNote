// screens/staff_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gap/gap.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/widgets.dart';
import '../services/firestore_service.dart';
import '../models/subject_model.dart';

class StaffRequestsScreen extends StatefulWidget {
  const StaffRequestsScreen({super.key});

  @override
  State<StaffRequestsScreen> createState() => _StaffRequestsScreenState();
}

class _StaffRequestsScreenState extends State<StaffRequestsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _firestoreService = FirestoreService();
  final String staffId = FirebaseAuth.instance.currentUser!.uid;

  // Cleaned up: Using StreamBuilder is better for real-time requests updates

  Future<void> _respondToRequest(RequestData req, bool accept) async {
    if (!accept) {
      await _firestoreService.rejectJoinRequest(req.id);
      return;
    }

    try {
      // 1. Approve Global Request & Add to Student Profile
      // Reconstruct Subject from Request Data (minimal info needed for student profile)
      // Ideally we should fetch the real Subject doc to get full details (like parts),
      // especially since we need 'attendanceParts' for the student model if we copy them.
      // But for now let's reuse what we have or fetch it.

      Subject? globalSubject;
      if (req.subjectId.isNotEmpty) {
        final subjectDoc = await _firestore
            .collection('subjects')
            .doc(req.subjectId)
            .get();
        if (subjectDoc.exists) {
          globalSubject = Subject.fromMap(subjectDoc.data()!, subjectDoc.id);
        }
      }

      globalSubject ??= Subject(
        id: req.subjectId,
        name: req.subjectName,
        isGlobal: true,
        createdBy: staffId,
        department: req.department,
        section: req.studentClass,
      );

      await _firestoreService.approveJoinRequest(
        req.id,
        req.studentId,
        globalSubject,
      );

      // 2. Add Student to Staff's Local Class List
      // We need to find the matching class in users/{staffId}/classes
      final normalizedSubjectName = req.subjectName; // Matches search name
      final normalizedDept = req.department; // Matches global subject dept
      final normalizedClassName =
          req.studentClass; // Matches global subject section

      // Logic: try to find class by global ID first, then fallback to name match
      QuerySnapshot classQuery;

      // Try finding by globalSubjectId if we added it
      classQuery = await _firestore
          .collection('users')
          .doc(staffId)
          .collection('classes')
          .where('globalSubjectId', isEqualTo: req.subjectId)
          .limit(1)
          .get();

      if (classQuery.docs.isEmpty) {
        // Fallback to fields
        classQuery = await _firestore
            .collection('users')
            .doc(staffId)
            .collection('classes')
            .where('subjectName', isEqualTo: normalizedSubjectName)
            .where('department', isEqualTo: normalizedDept)
            .where('className', isEqualTo: normalizedClassName)
            .limit(1)
            .get();
      }

      if (classQuery.docs.isNotEmpty) {
        final classDoc = classQuery.docs.first.reference;

        await classDoc.collection('students').doc(req.studentId).set({
          'joinedAt': FieldValue.serverTimestamp(),
          'approved': true,
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Warning: matched local class not found, but student approved globally.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error approving request: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Join Requests')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getStaffJoinRequests(staffId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorState(
              title: 'Unable to load requests',
              message: 'Error: ${snapshot.error}',
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ShimmerCardList(itemCount: 5);
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const EmptyState(
              title: 'No pending join requests',
              message: 'Requests from students will appear here',
              icon: Icons.inbox_outlined,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.md,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final req = RequestData.fromMap(
                docs[index].data() as Map<String, dynamic>,
                docs[index].id,
              );

              return AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(
                              req.studentName.isNotEmpty
                                  ? req.studentName[0].toUpperCase()
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
                                  req.studentName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Gap(AppSpacing.xxs),
                                Text(
                                  req.subjectName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Gap(AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const Gap(AppSpacing.xxs),
                          Text(
                            req.department,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Gap(AppSpacing.md),
                          Icon(
                            Icons.class_outlined,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const Gap(AppSpacing.xxs),
                          Text(
                            req.studentClass,
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
                            onPressed: () => _respondToRequest(req, false),
                            icon: Icons.close,
                            label: 'Reject',
                          ),
                          const Gap(AppSpacing.xs),
                          AppPrimaryButton(
                            onPressed: () => _respondToRequest(req, true),
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

class RequestData {
  final String id;
  final String studentId;
  final String studentName;
  final String subjectId;
  final String subjectName;
  final String studentClass;
  final String department;
  final String status;

  RequestData({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.subjectId,
    required this.subjectName,
    required this.studentClass,
    required this.department,
    required this.status,
  });

  factory RequestData.fromMap(Map<String, dynamic> data, String id) {
    return RequestData(
      id: id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      subjectId: data['subjectId'] ?? '',
      subjectName: data['subjectName'] ?? '',
      studentClass: data['studentClass'] ?? '', // Mapped from section
      department: data['department'] ?? '',
      status: data['status'] ?? 'pending',
    );
  }
}
