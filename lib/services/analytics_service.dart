// services/analytics_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/attendance_model.dart';

class AnalyticsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Calculate attendance analytics for a user across all subjects
  Future<AttendanceAnalytics> getAttendanceAnalytics(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final userDoc = _db.collection('users').doc(userId);
      final subjectsSnapshot = await userDoc.collection('subjects').get();

      Map<DateTime, List<Attendance>> attendanceByDate = {};
      Map<String, AttendanceStats> subjectWiseStats = {};
      int totalPresent = 0;
      int totalAbsent = 0;
      int totalCancelled = 0;

      // Fetch attendance for each subject
      for (var subjectDoc in subjectsSnapshot.docs) {
        final subjectName = subjectDoc.id;
        Query<Map<String, dynamic>> attendanceQuery = userDoc
            .collection('subjects')
            .doc(subjectName)
            .collection('attendance')
            .orderBy('date');

        if (startDate != null) {
          attendanceQuery = attendanceQuery.where(
            'date',
            isGreaterThanOrEqualTo: startDate,
          );
        }
        if (endDate != null) {
          attendanceQuery = attendanceQuery.where(
            'date',
            isLessThanOrEqualTo: endDate,
          );
        }

        final attendanceSnapshot = await attendanceQuery.get();
        final attendanceList = attendanceSnapshot.docs
            .map((doc) => Attendance.fromMap(doc.data(), doc.id))
            .toList();

        // Calculate subject-wise stats
        int subjectPresent = 0;
        int subjectAbsent = 0;
        int subjectCancelled = 0;

        for (var attendance in attendanceList) {
          // Group by date (ignore time)
          final dateOnly = DateTime(
            attendance.date.year,
            attendance.date.month,
            attendance.date.day,
          );

          attendanceByDate.putIfAbsent(dateOnly, () => []);
          attendanceByDate[dateOnly]!.add(attendance);

          // Count by status
          switch (attendance.status) {
            case AttendanceStatus.present:
              subjectPresent++;
              totalPresent++;
              break;
            case AttendanceStatus.absent:
              subjectAbsent++;
              totalAbsent++;
              break;
            case AttendanceStatus.cancelled:
              subjectCancelled++;
              totalCancelled++;
              break;
          }
        }

        subjectWiseStats[subjectName] = AttendanceStats(
          totalClasses: attendanceList.length,
          presentCount: subjectPresent,
          absentCount: subjectAbsent,
          cancelledCount: subjectCancelled,
        );
      }

      // Calculate attendance percentage over time
      Map<DateTime, double> attendanceOverTime = {};
      attendanceByDate.forEach((date, attendances) {
        int present = attendances
            .where((a) => a.status == AttendanceStatus.present)
            .length;
        int cancelled = attendances
            .where((a) => a.status == AttendanceStatus.cancelled)
            .length;
        int total = attendances.length;

        if (total - cancelled > 0) {
          attendanceOverTime[date] = (present / (total - cancelled)) * 100;
        }
      });

      return AttendanceAnalytics(
        attendanceOverTime: attendanceOverTime,
        subjectWiseStats: subjectWiseStats,
        totalPresent: totalPresent,
        totalAbsent: totalAbsent,
        totalCancelled: totalCancelled,
      );
    } catch (e) {
      debugPrint('Error calculating analytics: $e');
      return AttendanceAnalytics(
        attendanceOverTime: {},
        subjectWiseStats: {},
        totalPresent: 0,
        totalAbsent: 0,
        totalCancelled: 0,
      );
    }
  }

  /// Get topic revision suggestions based on absence patterns
  /// Returns top 3 topics/dates with highest absences
  Future<List<TopicRevisionSuggestion>> getTopicRevisionSuggestions(
    String staffId,
    String classId,
    String subjectName,
  ) async {
    try {
      // Get all students in this class
      final classDoc = await _db
          .collection('users')
          .doc(staffId)
          .collection('classes')
          .doc(classId)
          .get();

      if (!classDoc.exists) {
        return [];
      }

      final studentIds = List<String>.from(
        classDoc.data()?['studentIds'] ?? [],
      );
      if (studentIds.isEmpty) {
        return [];
      }

      // Map to track absences by topic/date
      Map<String, TopicData> topicAbsences = {};

      // Fetch attendance for each student
      for (var studentId in studentIds) {
        final attendanceSnapshot = await _db
            .collection('users')
            .doc(studentId)
            .collection('subjects')
            .doc(subjectName.trim().toLowerCase())
            .collection('attendance')
            .where('status', isEqualTo: 'absent')
            .get();

        for (var doc in attendanceSnapshot.docs) {
          final attendance = Attendance.fromMap(doc.data(), doc.id);
          final topic = attendance.topic ?? '';
          final date = attendance.date;

          // Use topic as key if available, otherwise use date
          final key = topic.isNotEmpty
              ? 'topic_$topic'
              : 'date_${date.millisecondsSinceEpoch}';

          if (!topicAbsences.containsKey(key)) {
            topicAbsences[key] = TopicData(
              topic: topic,
              date: topic.isEmpty ? date : null,
              absentCount: 0,
            );
          }

          topicAbsences[key]!.absentCount++;
        }
      }

      // Convert to list and sort by absent count
      final suggestions = topicAbsences.values
          .map(
            (data) => TopicRevisionSuggestion(
              topic: data.topic,
              date: data.date,
              absentCount: data.absentCount,
              totalStudents: studentIds.length,
              subjectName: subjectName,
            ),
          )
          .toList();

      suggestions.sort((a, b) => b.absentCount.compareTo(a.absentCount));

      // Return top 3
      return suggestions.take(3).toList();
    } catch (e) {
      debugPrint('Error getting topic revision suggestions: $e');
      return [];
    }
  }

  /// Get attendance data for a specific date range (for charts)
  Future<Map<DateTime, double>> getAttendanceTrend(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final analytics = await getAttendanceAnalytics(
      userId,
      startDate: startDate,
      endDate: endDate,
    );
    return analytics.attendanceOverTime;
  }
}

// Helper class for tracking topic absence data
class TopicData {
  String topic;
  DateTime? date;
  int absentCount;

  TopicData({required this.topic, this.date, required this.absentCount});
}
