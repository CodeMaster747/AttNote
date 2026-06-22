// services/attendance_prediction_service.dart
import 'dart:math';

import '../models/attendance_model.dart';
import '../models/subject_model.dart';
import 'firestore_service.dart';
import 'groq_service.dart';

enum RiskLevel { safe, atRisk, below }

/// Deterministic attendance risk assessment for a single subject, optionally
/// enriched with a plain-language insight from Groq.
class AttendanceRisk {
  AttendanceRisk({
    required this.subjectId,
    required this.subjectName,
    required this.present,
    required this.absent,
    required this.missableClasses,
    required this.classesToRecover,
    required this.absencesPerWeek,
    required this.projectedBelowDate,
    this.aiInsight,
  });

  final String subjectId;
  final String subjectName;
  final int present;
  final int absent;

  /// Additional classes that can be missed while staying >= 75%.
  final int missableClasses;

  /// If below 75%, consecutive classes to attend to reach 75% again.
  final int classesToRecover;

  /// Recent absence pace (absences over the last 4 weeks / 4).
  final double absencesPerWeek;

  /// When attendance would dip below 75% if the recent pace continues.
  final DateTime? projectedBelowDate;

  String? aiInsight;

  static const double threshold = 75.0;

  int get effectiveTotal => present + absent;
  bool get hasData => effectiveTotal > 0;
  double get currentPct =>
      hasData ? (present / effectiveTotal) * 100 : 0;

  RiskLevel get level {
    if (!hasData) return RiskLevel.safe;
    if (currentPct < threshold) return RiskLevel.below;
    final soon = projectedBelowDate != null &&
        projectedBelowDate!
            .isBefore(DateTime.now().add(const Duration(days: 21)));
    if (missableClasses <= 1 || soon) return RiskLevel.atRisk;
    return RiskLevel.safe;
  }
}

class AttendancePredictionService {
  final FirestoreService _firestore = FirestoreService();
  final GroqService _groq = GroqService();

  bool get aiAvailable => _groq.isConfigured;

  Future<AttendanceRisk> computeRisk(String uid, Subject subject) async {
    final records = await _firestore.getAttendance(uid, subject.id);
    return _fromRecords(subject, records);
  }

  Future<List<AttendanceRisk>> computeAll(String uid) async {
    final subjects = await _firestore.getSubjects(uid);
    final List<AttendanceRisk> risks = [];
    for (final s in subjects) {
      final records = await _firestore.getAttendance(uid, s.id);
      risks.add(_fromRecords(s, records));
    }
    // Most urgent first: below, then at-risk, then by ascending percentage.
    risks.sort((a, b) {
      int rank(RiskLevel l) =>
          l == RiskLevel.below ? 0 : (l == RiskLevel.atRisk ? 1 : 2);
      final byLevel = rank(a.level).compareTo(rank(b.level));
      if (byLevel != 0) return byLevel;
      return a.currentPct.compareTo(b.currentPct);
    });
    return risks;
  }

  AttendanceRisk _fromRecords(Subject subject, List<Attendance> records) {
    final present =
        records.where((a) => a.status == AttendanceStatus.present).length;
    final absent =
        records.where((a) => a.status == AttendanceStatus.absent).length;
    final total = present + absent;

    // Buffer of further absences while staying >= 75%.
    final missable = total == 0
        ? 0
        : max(0, (present / 0.75).floor() - total);

    // If below 75%, consecutive present classes needed to reach 75%.
    final pct = total == 0 ? 0.0 : (present / total) * 100;
    final recover = pct >= AttendanceRisk.threshold
        ? 0
        : max(0, (3 * total - 4 * present).ceil());

    // Recent absence pace over the last 28 days.
    final cutoff = DateTime.now().subtract(const Duration(days: 28));
    final recentAbsences = records
        .where((a) =>
            a.status == AttendanceStatus.absent && a.date.isAfter(cutoff))
        .length;
    final absencesPerWeek = recentAbsences / 4.0;

    DateTime? projected;
    if (pct >= AttendanceRisk.threshold && absencesPerWeek > 0) {
      final weeks = missable / absencesPerWeek;
      projected = DateTime.now().add(Duration(days: (weeks * 7).round()));
    }

    return AttendanceRisk(
      subjectId: subject.id,
      subjectName: subject.name,
      present: present,
      absent: absent,
      missableClasses: missable,
      classesToRecover: recover,
      absencesPerWeek: absencesPerWeek,
      projectedBelowDate: projected,
    );
  }

  /// Ask Groq for a short, friendly explanation + recommendation. Returns null
  /// (and callers should show the deterministic numbers alone) if AI is off or
  /// the request fails.
  Future<String?> generateInsight(AttendanceRisk risk) async {
    if (!_groq.isConfigured || !risk.hasData) return null;

    final dateStr = risk.projectedBelowDate == null
        ? 'not trending below 75% at the current pace'
        : '${risk.projectedBelowDate!.day}/${risk.projectedBelowDate!.month}/${risk.projectedBelowDate!.year}';

    final facts = '''
Subject: ${risk.subjectName}
Present: ${risk.present}
Absent: ${risk.absent}
Current attendance: ${risk.currentPct.toStringAsFixed(1)}%
Required minimum: 75%
Classes that can still be missed while staying >=75%: ${risk.missableClasses}
Classes to attend back-to-back to recover to 75% (if below): ${risk.classesToRecover}
Recent absence pace: ${risk.absencesPerWeek.toStringAsFixed(1)} per week
Projected date of dropping below 75%: $dateStr''';

    return _groq.chat(
      'You are a concise academic attendance advisor. Reply in at most 2 short '
      'sentences, plain text, no markdown. Be specific and actionable using the '
      'numbers provided.',
      'Explain this student\'s attendance risk and give one clear '
      'recommendation.\n\n$facts',
      maxTokens: 160,
      temperature: 0.5,
    );
  }
}
