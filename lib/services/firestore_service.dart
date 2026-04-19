// services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/subject_model.dart';
import '../models/attendance_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // Subject operations with proper error handling
  Future<void> addSubject(String uid, Subject subject) async {
    final docId = subject.name.trim().toLowerCase();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .doc(docId)
        .set(subject.toMap());
  }

  Future<List<Subject>> getSubjects(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .get();

    return snapshot.docs
        .map((doc) => Subject.fromMap(doc.data(), doc.id))
        .toList();
  }

  // DELETE FUNCTIONALITY - Delete subject
  Future<void> deleteSubject(String uid, String subjectName) async {
    try {
      final batch = _db.batch();

      // Delete all attendance records for this subject
      final attendanceSnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .doc(subjectName)
          .collection('attendance')
          .get();

      for (var doc in attendanceSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the subject itself
      batch.delete(
        _db
            .collection('users')
            .doc(uid)
            .collection('subjects')
            .doc(subjectName),
      );

      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting subject: $e');
      rethrow;
    }
  }

  Future<void> markAttendance(
    String uid,
    String subjectName,
    Attendance attendance,
  ) async {
    final firestore = FirebaseFirestore.instance;

    // Normalize subject name to keep consistent keys
    final normalizedSubjectName = subjectName;

    // Get student document to check assigned faculty
    final userDoc = await firestore.collection('users').doc(uid).get();
    final assignedFacultyMap = userDoc.data()?['assignedFaculty'] ?? {};
    final assignedFacultyId = assignedFacultyMap[normalizedSubjectName];

    final dayOnly = DateTime(
      attendance.date.year,
      attendance.date.month,
      attendance.date.day,
    );
    final docId =
        '${dayOnly.millisecondsSinceEpoch}_${attendance.sessionNumber}'; // unique per session

    if (assignedFacultyId != null && assignedFacultyId.isNotEmpty) {
      // Create an attendance request for staff approval
      await firestore.collection('attendanceRequests').add({
        'studentId': uid,
        'studentName':
            userDoc.data()?['name'] ?? '', // optionally add student name
        'staffId': assignedFacultyId,
        'subjectId': normalizedSubjectName, // or subject ID if using it
        'subjectName': subjectName,
        'date': attendance.date,
        'sessionNumber': attendance.sessionNumber,
        'attendanceStatus': attendance.status.name,
        'status': 'pending', // request is pending approval
        'requestedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // No assigned faculty, mark attendance directly
      final docRef = firestore
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .doc(normalizedSubjectName)
          .collection('attendance')
          .doc(docId);

      await docRef.set(attendance.toMap());
    }
  }

  Future<List<Attendance>> getAttendance(String uid, String subjectName) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .doc(subjectName)
          .collection('attendance')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Attendance.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting attendance: $e');
      return [];
    }
  }

  Future<AttendanceStats> getAttendanceStats(
    String uid,
    String subjectName, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final attendanceList = await getAttendance(uid, subjectName);

      var filteredList = attendanceList;
      if (startDate != null && endDate != null) {
        // Normalize constraints to start of day and end of day
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        final end = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );

        filteredList = attendanceList.where((a) {
          return a.date.isAfter(
                start.subtract(const Duration(milliseconds: 1)),
              ) &&
              a.date.isBefore(end.add(const Duration(milliseconds: 1)));
        }).toList();
      }

      int totalClasses = filteredList.length;
      int presentCount = filteredList
          .where((a) => a.status == AttendanceStatus.present)
          .length;
      int absentCount = filteredList
          .where((a) => a.status == AttendanceStatus.absent)
          .length;
      int cancelledCount = filteredList
          .where((a) => a.status == AttendanceStatus.cancelled)
          .length;

      return AttendanceStats(
        totalClasses: totalClasses,
        presentCount: presentCount,
        absentCount: absentCount,
        cancelledCount: cancelledCount,
      );
    } catch (e) {
      debugPrint('Error getting attendance stats: $e');
      return AttendanceStats(
        totalClasses: 0,
        presentCount: 0,
        absentCount: 0,
        cancelledCount: 0,
      );
    }
  }

  Future<Attendance?> getTodayAttendance(String uid, String subjectName) async {
    try {
      final today = DateTime.now();
      final dateOnly = DateTime(today.year, today.month, today.day);

      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .doc(subjectName)
          .collection('attendance')
          .doc(dateOnly.millisecondsSinceEpoch.toString())
          .get();

      if (doc.exists) {
        return Attendance.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting today\'s attendance: $e');
      return null;
    }
  }

  // Session scheduling for staff
  Future<void> saveSessionSchedule(
    String staffId,
    String classId,
    String subjectName,
    DateTime date,
    int numberOfSessions,
    Map<int, String> sessionTopics,
  ) async {
    try {
      final dateOnly = DateTime(date.year, date.month, date.day);
      final docId = '${dateOnly.millisecondsSinceEpoch}';

      await _db
          .collection('users')
          .doc(staffId)
          .collection('classes')
          .doc(classId)
          .collection('schedules')
          .doc(docId)
          .set({
            'staffId': staffId,
            'classId': classId,
            'subjectName': subjectName,
            'date': dateOnly,
            'numberOfSessions': numberOfSessions,
            'sessionTopics': sessionTopics.map(
              (k, v) => MapEntry(k.toString(), v),
            ),
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error saving session schedule: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getSessionSchedule(
    String staffId,
    String classId,
    DateTime date,
  ) async {
    try {
      final dateOnly = DateTime(date.year, date.month, date.day);
      final docId = '${dateOnly.millisecondsSinceEpoch}';

      final doc = await _db
          .collection('users')
          .doc(staffId)
          .collection('classes')
          .doc(classId)
          .collection('schedules')
          .doc(docId)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting session schedule: $e');
      return null;
    }
  }

  // Mark attendance for past dates
  Future<void> markAttendanceForPastDate(
    String uid,
    String subjectName,
    DateTime date,
    int sessionNumber,
    AttendanceStatus status,
    String? topic,
  ) async {
    try {
      final dateOnly = DateTime(date.year, date.month, date.day);
      final docId = '${dateOnly.millisecondsSinceEpoch}_$sessionNumber';

      final attendance = Attendance(
        id: docId,
        subjectId: subjectName,
        date: dateOnly,
        status: status,
        sessionNumber: sessionNumber,
        topic: topic,
      );

      await _db
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .doc(subjectName.trim().toLowerCase())
          .collection('attendance')
          .doc(docId)
          .set(attendance.toMap());
    } catch (e) {
      debugPrint('Error marking past attendance: $e');
      rethrow;
    }
  }

  // Auto-mark absent for students who didn't send requests
  Future<void> autoMarkAbsentForMissedRequests(
    String staffId,
    String classId,
    String subjectName,
    DateTime date,
  ) async {
    try {
      // Get session schedule for the date
      final schedule = await getSessionSchedule(staffId, classId, date);
      if (schedule == null) return;

      final numberOfSessions = schedule['numberOfSessions'] as int? ?? 0;
      if (numberOfSessions == 0) return;

      // Get all students in the class
      final classDoc = await _db
          .collection('users')
          .doc(staffId)
          .collection('classes')
          .doc(classId)
          .get();

      final studentIds = List<String>.from(
        classDoc.data()?['studentIds'] ?? [],
      );

      final dateOnly = DateTime(date.year, date.month, date.day);

      // For each student, check if they sent attendance requests
      for (var studentId in studentIds) {
        for (int session = 1; session <= numberOfSessions; session++) {
          // Check if there's a pending or approved request
          final requestSnapshot = await _db
              .collection('attendanceRequests')
              .where('studentId', isEqualTo: studentId)
              .where('staffId', isEqualTo: staffId)
              .where('subjectName', isEqualTo: subjectName)
              .where('date', isEqualTo: dateOnly)
              .where('sessionNumber', isEqualTo: session)
              .get();

          // If no request found, mark as absent
          if (requestSnapshot.docs.isEmpty) {
            final topicsData =
                schedule['sessionTopics'] as Map<dynamic, dynamic>? ?? {};
            final topic = topicsData[session.toString()]?.toString();

            await markAttendanceForPastDate(
              studentId,
              subjectName,
              dateOnly,
              session,
              AttendanceStatus.absent,
              topic,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error auto-marking absences: $e');
      rethrow;
    }
  }

  // GLOBAL SUBJECTS & REQUESTS

  // Create a global subject (Staff only) - Returns the new Subject ID
  Future<String> createGlobalSubject(Subject subject) async {
    try {
      final docRef = await _db.collection('subjects').add(subject.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating global subject: $e');
      rethrow;
    }
  }

  // Search global subjects
  Future<List<Subject>> searchGlobalSubjects(String query) async {
    try {
      // Simple prefix search
      final snapshot = await _db
          .collection('subjects')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: '${query}z')
          .get();

      return snapshot.docs
          .map((doc) => Subject.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error searching subjects: $e');
      return [];
    }
  }

  // Request to join a global subject
  Future<void> requestToJoinSubject(
    String studentId,
    String studentName,
    String subjectId,
    String subjectName,
  ) async {
    // Deprecated or basic version
    await requestToJoinSubjectWithOwner(
      studentId,
      studentName,
      Subject(id: subjectId, name: subjectName), // Minimal subject
    );
  }

  // Detailed Request to join
  Future<void> requestToJoinSubjectWithOwner(
    String studentId,
    String studentName,
    Subject subject,
  ) async {
    try {
      await _db.collection('joinRequests').add({
        'studentId': studentId,
        'studentName': studentName,
        'subjectId': subject.id,
        'subjectName': subject.name,
        'ownerId': subject.createdBy, // Staff ID
        'department': subject.department, // For matching
        'studentClass': subject.section, // For matching
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error requesting to join: $e');
      rethrow;
    }
  }

  // Fetch requests for staff
  Stream<QuerySnapshot> getStaffJoinRequests(String staffId) {
    return _db
        .collection('joinRequests')
        .where('ownerId', isEqualTo: staffId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Approve join request
  Future<void> approveJoinRequest(
    String requestId,
    String studentId,
    Subject globalSubject,
  ) async {
    try {
      final batch = _db.batch();

      // 1. Update request status
      final requestRef = _db.collection('joinRequests').doc(requestId);
      batch.update(requestRef, {'status': 'approved'});

      // 2. Add subject to student's local list
      // Use Normalized Name or Global ID?
      // Since 'markAttendance' uses name, we stick to that for now for compatibility.
      final docId = globalSubject.name.trim().toLowerCase();
      final studentSubjectRef = _db
          .collection('users')
          .doc(studentId)
          .collection('subjects')
          .doc(docId);

      // We might want to store the Global ID too
      final subjectData = globalSubject.toMap();
      subjectData['globalId'] = globalSubject.id;

      // 2a. Fetch Staff Name if available (for UI display)
      if (globalSubject.createdBy.isNotEmpty) {
        final staffDoc = await _db
            .collection('users')
            .doc(globalSubject.createdBy)
            .get();
        if (staffDoc.exists) {
          final staffName = staffDoc.data()?['name'] ?? 'Staff';
          subjectData['staffName'] = staffName;
        }
      }

      batch.set(studentSubjectRef, subjectData);

      // 3. Add Student to Staff's Class List (if we can find it)
      // We need to find the class document in users/{staffId}/classes
      // that matches the subject info.

      if (globalSubject.createdBy.isNotEmpty) {
        // This requires a query, which we can't do easily in a batch unless we know the ID.
        // So we should do the query before the batch, OR assume the UI calling this
        // knows the classId (which StaffRequestsScreen logic tries to find).
        // But strict separation of concerns suggested doing it here.
        // However, without classId, we can't add to subcollection efficiently.
        // Let's rely on the caller (StaffRequestsScreen) to do step 3
        // OR the client can update the assignedFaculty map.

        // Let's update the assignedFaculty map on the student
        final userRef = _db.collection('users').doc(studentId);
        // We can't use dot notation for dynamic keys in batch update easily if we don't know the exact map structure
        // but 'assignedFaculty.SubjectName': staffId works.
        batch.update(userRef, {
          'assignedFaculty.${globalSubject.name}': globalSubject.createdBy,
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error approving request: $e');
      rethrow;
    }
  }

  // Reject join request
  Future<void> rejectJoinRequest(String requestId) async {
    await _db.collection('joinRequests').doc(requestId).update({
      'status': 'rejected',
    });
  }

  // AUTOMATIC ATTENDANCE METHODS

  // Get automatic attendance setting for user
  Future<bool> getAutoAttendanceSetting(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data()?['autoAttendance'] ?? false;
    } catch (e) {
      debugPrint('Error getting auto attendance setting: $e');
      return false;
    }
  }

  // Set automatic attendance setting for user
  Future<void> setAutoAttendanceSetting(String uid, bool enabled) async {
    try {
      await _db.collection('users').doc(uid).update({
        'autoAttendance': enabled,
      });
    } catch (e) {
      debugPrint('Error setting auto attendance: $e');
      rethrow;
    }
  }

  // Check if manual attendance exists for a specific date and subject
  Future<bool> hasManualAttendanceForDate(
    String uid,
    String subjectName,
    DateTime date,
    int sessionNumber,
  ) async {
    try {
      final dateOnly = DateTime(date.year, date.month, date.day);
      final docId = '${dateOnly.millisecondsSinceEpoch}_$sessionNumber';

      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .doc(subjectName)
          .collection('attendance')
          .doc(docId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('Error checking manual attendance: $e');
      return false;
    }
  }

  // Mark automatic attendance for all eligible subjects
  Future<void> markAutomaticAttendance(String uid) async {
    try {
      // Check if auto attendance is enabled
      final isEnabled = await getAutoAttendanceSetting(uid);
      if (!isEnabled) return;

      // Get current day of week
      final now = DateTime.now();
      final dayName = _getDayName(now.weekday);

      // Get all subjects for the user
      final subjects = await getSubjects(uid);

      // Filter personal subjects (no staff assigned) with timetable for today
      final eligibleSubjects = subjects.where((subject) {
        return subject.staffName.isEmpty &&
            subject.timetable.containsKey(dayName) &&
            subject.timetable[dayName]! > 0;
      }).toList();

      // Mark attendance for each eligible subject
      for (var subject in eligibleSubjects) {
        final classesCount = subject.timetable[dayName]!;

        for (int session = 1; session <= classesCount; session++) {
          // Check if attendance already marked manually
          final hasManual = await hasManualAttendanceForDate(
            uid,
            subject.id,
            now,
            session,
          );

          if (!hasManual) {
            // Mark as present automatically
            final attendance = Attendance(
              id: '',
              subjectId: subject.id,
              date: DateTime(now.year, now.month, now.day),
              status: AttendanceStatus.present,
              sessionNumber: session,
              topic: null,
            );

            await markAttendance(uid, subject.id, attendance);
          }
        }
      }
    } catch (e) {
      debugPrint('Error marking automatic attendance: $e');
      rethrow;
    }
  }

  // Helper method to get day name from weekday number
  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Monday';
    }
  }
}
