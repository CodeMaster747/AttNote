// services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/subject_model.dart';
import '../models/attendance_model.dart';
import '../models/course_model.dart';

/// Result of attempting to add a student to a staff subject by email.
enum AddStudentResult { added, alreadyAdded, notFound, notAStudent, isSelf, error }

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Subjects
  // ---------------------------------------------------------------------------

  /// Add a personal (student-owned) subject. Doc id is derived from the name.
  Future<void> addSubject(String uid, Subject subject) async {
    final docId = subject.name.trim().toLowerCase();
    await _db
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .doc(docId)
        .set(subject.toMap());
  }

  /// Create a staff-owned subject. Uses an auto-generated id so multiple
  /// subjects with the same name are allowed. Returns the new id.
  Future<String> createStaffSubject(String staffId, Subject subject) async {
    final ref = _db.collection('users').doc(staffId).collection('subjects').doc();
    final data = subject.toMap();
    data['ownerRole'] = 'staff';
    await ref.set(data);
    return ref.id;
  }

  /// Update arbitrary fields on a subject document.
  Future<void> updateSubject(
    String ownerId,
    String subjectId,
    Map<String, dynamic> data,
  ) async {
    await _db
        .collection('users')
        .doc(ownerId)
        .collection('subjects')
        .doc(subjectId)
        .update(data);
  }

  Future<List<Subject>> getSubjects(String uid) async {
    final snapshot =
        await _db.collection('users').doc(uid).collection('subjects').get();
    return snapshot.docs
        .map((doc) => Subject.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<Subject?> getSubject(String ownerId, String subjectId) async {
    final doc = await _db
        .collection('users')
        .doc(ownerId)
        .collection('subjects')
        .doc(subjectId)
        .get();
    if (!doc.exists) return null;
    return Subject.fromMap(doc.data()!, doc.id);
  }

  /// Delete a subject and its attendance. If it's a staff subject, also unlink
  /// every enrolled student (remove their mirrored copy).
  Future<void> deleteSubject(String uid, String subjectId) async {
    try {
      final subject = await getSubject(uid, subjectId);

      // Unlink mirrored copies from students for staff subjects.
      if (subject != null && subject.isStaffOwned) {
        for (final studentId in subject.studentIds) {
          await _deleteStudentMirror(studentId, subjectId);
        }
      }

      final batch = _db.batch();
      final attendanceSnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .doc(subjectId)
          .collection('attendance')
          .get();
      for (var doc in attendanceSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(
        _db.collection('users').doc(uid).collection('subjects').doc(subjectId),
      );
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting subject: $e');
      rethrow;
    }
  }

  Future<void> _deleteStudentMirror(String studentId, String subjectId) async {
    try {
      await _db
          .collection('users')
          .doc(studentId)
          .collection('subjects')
          .doc(subjectId)
          .delete();
    } catch (e) {
      debugPrint('Error removing student mirror: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Roster — add / remove students by email
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    final snapshot = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      // Some accounts may have a non-normalized email; try a raw match too.
      final raw = await _db
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      if (raw.docs.isEmpty) return null;
      final d = raw.docs.first;
      return {'id': d.id, ...d.data()};
    }
    final d = snapshot.docs.first;
    return {'id': d.id, ...d.data()};
  }

  /// Add a student (by email) to a staff subject and mirror the subject into
  /// the student's subjects subcollection so their attendance pipeline works.
  Future<AddStudentResult> addStudentToStaffSubjectByEmail(
    Subject staffSubject,
    String email,
  ) async {
    try {
      final user = await findUserByEmail(email);
      if (user == null) return AddStudentResult.notFound;
      final studentId = user['id'] as String;
      if ((user['role'] ?? 'student') != 'student') {
        return AddStudentResult.notAStudent;
      }
      if (studentId == staffSubject.createdBy) return AddStudentResult.isSelf;
      if (staffSubject.studentIds.contains(studentId)) {
        return AddStudentResult.alreadyAdded;
      }

      // 1. Add to staff subject roster.
      await _db
          .collection('users')
          .doc(staffSubject.createdBy)
          .collection('subjects')
          .doc(staffSubject.id)
          .update({
        'studentIds': FieldValue.arrayUnion([studentId]),
      });

      // 2. Mirror the subject into the student's collection (doc id = staff
      //    subject id) so attendance/analytics read it like any other subject.
      final mirror = staffSubject.toMap();
      mirror['ownerRole'] = 'student';
      mirror['linkedStaffId'] = staffSubject.createdBy;
      mirror['linkedStaffSubjectId'] = staffSubject.id;
      mirror['studentIds'] = <String>[]; // student copy doesn't carry a roster
      await _db
          .collection('users')
          .doc(studentId)
          .collection('subjects')
          .doc(staffSubject.id)
          .set(mirror, SetOptions(merge: true));

      return AddStudentResult.added;
    } catch (e) {
      debugPrint('Error adding student by email: $e');
      return AddStudentResult.error;
    }
  }

  Future<void> removeStudentFromStaffSubject(
    Subject staffSubject,
    String studentId,
  ) async {
    await _db
        .collection('users')
        .doc(staffSubject.createdBy)
        .collection('subjects')
        .doc(staffSubject.id)
        .update({
      'studentIds': FieldValue.arrayRemove([studentId]),
    });
    await _deleteStudentMirror(studentId, staffSubject.id);
  }

  Future<List<Map<String, dynamic>>> getRosterStudents(
    List<String> studentIds,
  ) async {
    final List<Map<String, dynamic>> result = [];
    for (final id in studentIds) {
      final doc = await _db.collection('users').doc(id).get();
      if (doc.exists) {
        result.add({'id': id, ...doc.data()!});
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Attendance
  // ---------------------------------------------------------------------------

  Future<void> markAttendance(
    String uid,
    String subjectId,
    Attendance attendance,
  ) async {
    final dayOnly = DateTime(
      attendance.date.year,
      attendance.date.month,
      attendance.date.day,
    );
    final docId = '${dayOnly.millisecondsSinceEpoch}_${attendance.sessionNumber}';
    await _db
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .doc(subjectId)
        .collection('attendance')
        .doc(docId)
        .set(attendance.toMap());
  }

  Future<List<Attendance>> getAttendance(String uid, String subjectId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .doc(subjectId)
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
    String subjectId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final attendanceList = await getAttendance(uid, subjectId);

      var filteredList = attendanceList;
      if (startDate != null && endDate != null) {
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        final end =
            DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        filteredList = attendanceList.where((a) {
          return a.date
                  .isAfter(start.subtract(const Duration(milliseconds: 1))) &&
              a.date.isBefore(end.add(const Duration(milliseconds: 1)));
        }).toList();
      }

      int totalClasses = filteredList.length;
      int presentCount =
          filteredList.where((a) => a.status == AttendanceStatus.present).length;
      int absentCount =
          filteredList.where((a) => a.status == AttendanceStatus.absent).length;
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

  /// Mark attendance for any date. [subjectId] is used directly as the document
  /// id (no normalization), keeping personal and staff-linked subjects aligned.
  Future<void> markAttendanceForPastDate(
    String uid,
    String subjectId,
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
        subjectId: subjectId,
        date: dateOnly,
        status: status,
        sessionNumber: sessionNumber,
        topic: topic,
      );
      await _db
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .doc(subjectId)
          .collection('attendance')
          .doc(docId)
          .set(attendance.toMap());
    } catch (e) {
      debugPrint('Error marking past attendance: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Day plans (per taught day: topic + notes)
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _dayPlans(
    String ownerId,
    String subjectId,
  ) =>
      _db
          .collection('users')
          .doc(ownerId)
          .collection('subjects')
          .doc(subjectId)
          .collection('dayPlans');

  Future<void> setDayPlan(
    String ownerId,
    String subjectId,
    DayPlan plan,
  ) async {
    await _dayPlans(ownerId, subjectId).doc(plan.id).set(plan.toMap());
  }

  Stream<List<DayPlan>> streamDayPlans(String ownerId, String subjectId) {
    return _dayPlans(ownerId, subjectId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => DayPlan.fromMap(d.data(), d.id)).toList());
  }

  Future<List<DayPlan>> getDayPlans(String ownerId, String subjectId) async {
    final s = await _dayPlans(ownerId, subjectId).orderBy('date').get();
    return s.docs.map((d) => DayPlan.fromMap(d.data(), d.id)).toList();
  }

  Future<void> deleteDayPlan(
    String ownerId,
    String subjectId,
    String dayId,
  ) async {
    await _dayPlans(ownerId, subjectId).doc(dayId).delete();
  }

  // ---------------------------------------------------------------------------
  // Collapsible content sections
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _sections(
    String ownerId,
    String subjectId,
  ) =>
      _db
          .collection('users')
          .doc(ownerId)
          .collection('subjects')
          .doc(subjectId)
          .collection('sections');

  Future<void> upsertSection(
    String ownerId,
    String subjectId,
    SubjectSection section,
  ) async {
    final ref = section.id.isEmpty
        ? _sections(ownerId, subjectId).doc()
        : _sections(ownerId, subjectId).doc(section.id);
    await ref.set(section.toMap(), SetOptions(merge: true));
  }

  Stream<List<SubjectSection>> streamSections(String ownerId, String subjectId) {
    return _sections(ownerId, subjectId)
        .orderBy('order')
        .snapshots()
        .map((s) =>
            s.docs.map((d) => SubjectSection.fromMap(d.data(), d.id)).toList());
  }

  Future<void> deleteSection(
    String ownerId,
    String subjectId,
    String sectionId,
  ) async {
    await _sections(ownerId, subjectId).doc(sectionId).delete();
  }

  // ---------------------------------------------------------------------------
  // Course Guide
  // ---------------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> _guideDoc(
    String ownerId,
    String subjectId,
  ) =>
      _db
          .collection('users')
          .doc(ownerId)
          .collection('subjects')
          .doc(subjectId)
          .collection('guide')
          .doc('current');

  Future<void> saveGuide(
    String ownerId,
    String subjectId,
    CourseGuide guide,
  ) async {
    await _guideDoc(ownerId, subjectId).set(guide.toMap());
  }

  Stream<CourseGuide?> streamGuide(String ownerId, String subjectId) {
    return _guideDoc(ownerId, subjectId).snapshots().map(
          (doc) => doc.exists ? CourseGuide.fromMap(doc.data()!) : null,
        );
  }

  Future<CourseGuide?> getGuide(String ownerId, String subjectId) async {
    final doc = await _guideDoc(ownerId, subjectId).get();
    return doc.exists ? CourseGuide.fromMap(doc.data()!) : null;
  }

  /// Count, per day, how many roster students were marked absent — used to make
  /// the Course Guide's revision days focus on poorly-attended topics.
  Future<Map<String, int>> getRosterAbsenceByDate(
    List<String> studentIds,
    String subjectId,
  ) async {
    final Map<String, int> byDate = {};
    for (final studentId in studentIds) {
      final snap = await _db
          .collection('users')
          .doc(studentId)
          .collection('subjects')
          .doc(subjectId)
          .collection('attendance')
          .where('status', isEqualTo: 'absent')
          .get();
      for (final doc in snap.docs) {
        final date = doc.data()['date']?.toDate();
        if (date == null) continue;
        final key = DayPlan.dateKey(date);
        byDate[key] = (byDate[key] ?? 0) + 1;
      }
    }
    return byDate;
  }

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _tests(
    String ownerId,
    String subjectId,
  ) =>
      _db
          .collection('users')
          .doc(ownerId)
          .collection('subjects')
          .doc(subjectId)
          .collection('tests');

  Future<void> upsertTest(
    String ownerId,
    String subjectId,
    CourseTest test,
  ) async {
    final ref = test.id.isEmpty
        ? _tests(ownerId, subjectId).doc()
        : _tests(ownerId, subjectId).doc(test.id);
    await ref.set(test.toMap(), SetOptions(merge: true));
  }

  Stream<List<CourseTest>> streamTests(String ownerId, String subjectId) {
    return _tests(ownerId, subjectId)
        .orderBy('date')
        .snapshots()
        .map((s) =>
            s.docs.map((d) => CourseTest.fromMap(d.data(), d.id)).toList());
  }

  Future<List<CourseTest>> getTests(String ownerId, String subjectId) async {
    final s = await _tests(ownerId, subjectId).orderBy('date').get();
    return s.docs.map((d) => CourseTest.fromMap(d.data(), d.id)).toList();
  }

  Future<void> deleteTest(
    String ownerId,
    String subjectId,
    String testId,
  ) async {
    await _tests(ownerId, subjectId).doc(testId).delete();
  }

  // ---------------------------------------------------------------------------
  // Automatic attendance (personal subjects only)
  // ---------------------------------------------------------------------------

  Future<bool> getAutoAttendanceSetting(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data()?['autoAttendance'] ?? false;
    } catch (e) {
      debugPrint('Error getting auto attendance setting: $e');
      return false;
    }
  }

  Future<void> setAutoAttendanceSetting(String uid, bool enabled) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .update({'autoAttendance': enabled});
    } catch (e) {
      debugPrint('Error setting auto attendance: $e');
      rethrow;
    }
  }

  Future<bool> hasManualAttendanceForDate(
    String uid,
    String subjectId,
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
          .doc(subjectId)
          .collection('attendance')
          .doc(docId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking manual attendance: $e');
      return false;
    }
  }

  Future<void> markAutomaticAttendance(String uid) async {
    try {
      final isEnabled = await getAutoAttendanceSetting(uid);
      if (!isEnabled) return;

      final now = DateTime.now();
      final dayName = _getDayName(now.weekday);
      final subjects = await getSubjects(uid);

      // Only personal subjects (not shared by a staff member).
      final eligibleSubjects = subjects.where((subject) {
        return !subject.isLinkedToStaff &&
            subject.timetable.containsKey(dayName) &&
            subject.timetable[dayName]! > 0;
      }).toList();

      for (var subject in eligibleSubjects) {
        final classesCount = subject.timetable[dayName]!;
        for (int session = 1; session <= classesCount; session++) {
          final hasManual =
              await hasManualAttendanceForDate(uid, subject.id, now, session);
          if (!hasManual) {
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

  String _getDayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[(weekday - 1).clamp(0, 6)];
  }
}
