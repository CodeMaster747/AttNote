// models/attendance_model.dart
enum AttendanceStatus { present, absent, cancelled }

class Attendance {
  final String id;
  final String subjectId;
  final DateTime date;
  final AttendanceStatus status;
  final int sessionNumber;
  final String? topic; // Optional topic for the session

  Attendance({
    required this.id,
    required this.subjectId,
    required this.date,
    required this.status,
    required this.sessionNumber,
    this.topic,
  });

  Map<String, dynamic> toMap() => {
    'subjectId': subjectId,
    'date': date,
    'status': status.name,
    'sessionNumber': sessionNumber,
    if (topic != null) 'topic': topic,
  };

  factory Attendance.fromMap(Map<String, dynamic> data, String id) =>
      Attendance(
        id: id,
        subjectId: data['subjectId'] ?? '',
        date: data['date']?.toDate() ?? DateTime.now(),
        status: AttendanceStatus.values.firstWhere(
          (e) => e.name == data['status'],
          orElse: () => AttendanceStatus.absent,
        ),
        sessionNumber: data['sessionNumber'] ?? 1,
        topic: data['topic'],
      );
}

class AttendanceStats {
  final int totalClasses;
  final int presentCount;
  final int absentCount;
  final int cancelledCount;
  final double attendancePercentage;

  AttendanceStats({
    required this.totalClasses,
    required this.presentCount,
    required this.absentCount,
    required this.cancelledCount,
  }) : attendancePercentage = (totalClasses - cancelledCount) > 0
           ? (presentCount / (totalClasses - cancelledCount)) * 100
           : 0.0;
}

// Model for staff session scheduling
class SessionSchedule {
  final String id;
  final String staffId;
  final String classId;
  final String subjectName;
  final DateTime date;
  final int numberOfSessions;
  final Map<int, String> sessionTopics; // sessionNumber -> topic

  SessionSchedule({
    required this.id,
    required this.staffId,
    required this.classId,
    required this.subjectName,
    required this.date,
    required this.numberOfSessions,
    required this.sessionTopics,
  });

  Map<String, dynamic> toMap() => {
    'staffId': staffId,
    'classId': classId,
    'subjectName': subjectName,
    'date': date,
    'numberOfSessions': numberOfSessions,
    'sessionTopics': sessionTopics,
  };

  factory SessionSchedule.fromMap(Map<String, dynamic> data, String id) {
    final topicsData = data['sessionTopics'] as Map<dynamic, dynamic>? ?? {};
    final sessionTopics = <int, String>{};
    topicsData.forEach((key, value) {
      sessionTopics[int.parse(key.toString())] = value.toString();
    });

    return SessionSchedule(
      id: id,
      staffId: data['staffId'] ?? '',
      classId: data['classId'] ?? '',
      subjectName: data['subjectName'] ?? '',
      date: data['date']?.toDate() ?? DateTime.now(),
      numberOfSessions: data['numberOfSessions'] ?? 1,
      sessionTopics: sessionTopics,
    );
  }
}

// Model for ML-based topic revision suggestions
class TopicRevisionSuggestion {
  final String topic;
  final DateTime? date; // null if topic is assigned, otherwise the date
  final int absentCount;
  final int totalStudents;
  final String subjectName;

  TopicRevisionSuggestion({
    required this.topic,
    this.date,
    required this.absentCount,
    required this.totalStudents,
    required this.subjectName,
  });

  double get absentPercentage =>
      totalStudents > 0 ? (absentCount / totalStudents) * 100 : 0.0;

  String get displayName => topic.isNotEmpty
      ? topic
      : (date != null ? 'Session on ${_formatDate(date!)}' : 'Unknown');

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Model for attendance analytics data
class AttendanceAnalytics {
  final Map<DateTime, double> attendanceOverTime; // date -> percentage
  final Map<String, AttendanceStats> subjectWiseStats; // subject -> stats
  final int totalPresent;
  final int totalAbsent;
  final int totalCancelled;

  AttendanceAnalytics({
    required this.attendanceOverTime,
    required this.subjectWiseStats,
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalCancelled,
  });

  int get totalClasses => totalPresent + totalAbsent + totalCancelled;

  double get overallPercentage => (totalClasses - totalCancelled) > 0
      ? (totalPresent / (totalClasses - totalCancelled)) * 100
      : 0.0;
}
