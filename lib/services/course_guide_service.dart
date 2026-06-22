// services/course_guide_service.dart
import 'dart:math';

import '../models/course_model.dart';
import '../models/subject_model.dart';
import 'document_text_service.dart';
import 'firestore_service.dart';
import 'groq_service.dart';

const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Builds a Course Guide for a staff subject: AI orders the syllabus topics and
/// supplies prerequisites + resources, while scheduling onto real teaching days
/// (taught days minus holidays) and attendance-aware revision days is done
/// deterministically in Dart.
class CourseGuideService {
  final GroqService _groq = GroqService();
  final FirestoreService _firestore = FirestoreService();
  final DocumentTextService _docs = DocumentTextService();

  bool get aiAvailable => _groq.isConfigured;

  Future<String?> extractSyllabusText(Subject subject) async {
    if (subject.syllabusUrl == null) return null;
    return _docs.extractFromUrl(
      subject.syllabusUrl!,
      subject.syllabusFileName ?? 'syllabus.pdf',
    );
  }

  /// Best-effort holiday date extraction from the uploaded holiday document.
  Future<List<DateTime>> extractHolidayDates(Subject subject) async {
    if (subject.holidayUrl == null || !aiAvailable) return [];
    final text = await _docs.extractFromUrl(
      subject.holidayUrl!,
      subject.holidayFileName ?? 'holidays.pdf',
    );
    if (text == null || text.trim().isEmpty) return [];
    final json = await _groq.chatJson(
      'Extract calendar holiday dates from the text. Reply strict JSON: '
      '{"dates":["YYYY-MM-DD", ...]}. Only include dates clearly present.',
      'Current year is ${DateTime.now().year}.\n\n${_truncate(text, 4000)}',
      maxTokens: 1024,
    );
    final dates = <DateTime>[];
    for (final d in (json?['dates'] as List<dynamic>? ?? [])) {
      final parsed = DateTime.tryParse(d.toString());
      if (parsed != null) {
        dates.add(DateTime(parsed.year, parsed.month, parsed.day));
      }
    }
    return dates;
  }

  /// Generate and persist a Course Guide. Returns null if AI is unavailable or
  /// the model returns nothing usable.
  Future<CourseGuide?> generateGuide({
    required Subject subject,
    required CourseTest test,
    required String syllabusText,
    List<DateTime> holidays = const [],
  }) async {
    if (!_groq.isConfigured) return null;
    if (syllabusText.trim().isEmpty) return null;

    final json = await _groq.chatJson(
      _systemPrompt,
      _userPrompt(subject, test, syllabusText),
      maxTokens: 4096,
    );
    if (json == null) return null;

    final rawTopics = json['topics'] as List<dynamic>? ?? [];
    final topics = rawTopics
        .map((e) => _parseTopic(Map<String, dynamic>.from(e as Map)))
        .where((t) => t.topic.isNotEmpty)
        .toList();
    if (topics.isEmpty) return null;

    // Attendance-aware revision input: how often each taught topic was missed.
    final topicAbsence = await _topicAbsence(subject);

    final scheduled = _schedule(
      subject: subject,
      test: test,
      topics: topics,
      holidays: holidays,
      topicAbsence: topicAbsence,
    );

    final guide = CourseGuide(
      testId: test.id,
      testName: test.name,
      examDate: test.date,
      generatedAt: DateTime.now(),
      topics: scheduled,
    );
    await _firestore.saveGuide(subject.createdBy, subject.id, guide);
    return guide;
  }

  GuideTopic _parseTopic(Map<String, dynamic> m) {
    return GuideTopic(
      unit: (m['unit'] ?? '').toString(),
      topic: (m['topic'] ?? '').toString(),
      prerequisites: (m['prerequisites'] as List<dynamic>?)
              ?.map((x) => x.toString())
              .where((x) => x.isNotEmpty)
              .toList() ??
          [],
      resources: (m['resources'] as List<dynamic>?)
              ?.map((x) {
                final rm = Map<String, dynamic>.from(x as Map);
                return GuideResource(
                  title: (rm['title'] ?? '').toString(),
                  url: (rm['url'] ?? '').toString(),
                );
              })
              .where((r) => r.url.isNotEmpty)
              .toList() ??
          [],
    );
  }

  Future<Map<String, int>> _topicAbsence(Subject subject) async {
    if (subject.studentIds.isEmpty) return {};
    final dayPlans =
        await _firestore.getDayPlans(subject.createdBy, subject.id);
    if (dayPlans.isEmpty) return {};
    final byDate = await _firestore.getRosterAbsenceByDate(
        subject.studentIds, subject.id);
    final Map<String, int> topicAbsence = {};
    for (final dp in dayPlans) {
      if (dp.topic.isEmpty) continue;
      final a = byDate[dp.id] ?? 0;
      final key = dp.topic.toLowerCase();
      topicAbsence[key] = (topicAbsence[key] ?? 0) + a;
    }
    return topicAbsence;
  }

  List<GuideTopic> _schedule({
    required Subject subject,
    required CourseTest test,
    required List<GuideTopic> topics,
    required List<DateTime> holidays,
    required Map<String, int> topicAbsence,
  }) {
    final taught = subject.taughtDays.isNotEmpty
        ? subject.taughtDays.toSet()
        : {'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'};
    final holidaySet =
        holidays.map((d) => DayPlan.dateKey(d)).toSet();

    // Available teaching dates from tomorrow up to the day before the exam.
    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day)
        .add(const Duration(days: 1));
    final exam = DateTime(test.date.year, test.date.month, test.date.day);
    final List<DateTime> available = [];
    while (cursor.isBefore(exam)) {
      final dayName = _weekdayNames[cursor.weekday - 1];
      if (taught.contains(dayName) && !holidaySet.contains(DayPlan.dateKey(cursor))) {
        available.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    // No room to schedule — return topics unscheduled but still useful.
    if (available.isEmpty) return topics;

    final d = available.length;
    final revisionCount = d < 3 ? 0 : max(1, (d * 0.15).ceil());
    final teachingDates = available.sublist(0, d - revisionCount);
    final revisionDates = available.sublist(d - revisionCount);

    final scheduled = <GuideTopic>[];

    // Spread topics across teaching dates (multiple per day if needed).
    final slots = teachingDates.isEmpty ? available : teachingDates;
    for (var i = 0; i < topics.length; i++) {
      final idx = slots.length == 1
          ? 0
          : ((i * slots.length) ~/ topics.length).clamp(0, slots.length - 1);
      scheduled.add(topics[i].copyWith(date: slots[idx], isRevision: false));
    }

    // Revision days: prioritise topics with the most absences, else last topics.
    if (revisionDates.isNotEmpty) {
      final ordered = [...topics];
      ordered.sort((a, b) {
        final aa = topicAbsence[a.topic.toLowerCase()] ?? 0;
        final bb = topicAbsence[b.topic.toLowerCase()] ?? 0;
        return bb.compareTo(aa);
      });
      for (var j = 0; j < revisionDates.length; j++) {
        final pick = ordered[j % ordered.length];
        scheduled.add(pick.copyWith(date: revisionDates[j], isRevision: true));
      }
    }

    scheduled.sort((a, b) {
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return a.date!.compareTo(b.date!);
    });
    return scheduled;
  }

  static const String _systemPrompt =
      'You are a curriculum planner. Given a syllabus and the portion for a '
      'test, return ONLY the topics within that portion, ordered in the best '
      'pedagogical teaching sequence (foundational topics before advanced ones). '
      'Reply with strict JSON of the form: '
      '{"topics":[{"unit":"Unit 1","topic":"...","prerequisites":["..."],'
      '"resources":[{"title":"...","url":"..."}]}]}. '
      'For each topic give 1-3 prerequisites (concepts needed first) and 2-3 '
      'resources. For a video resource, use a YouTube search URL of the form '
      'https://www.youtube.com/results?search_query=URL_ENCODED_TOPIC . Use '
      'reputable, real documentation/tutorial URLs for the others. Keep topic '
      'names concise.';

  String _userPrompt(Subject subject, CourseTest test, String syllabusText) {
    final portion = test.portion.isNotEmpty ? test.portion : 'the entire syllabus';
    return 'Subject: ${subject.name}\n'
        'Test: ${test.name}\n'
        'Portion to cover: $portion\n\n'
        'Syllabus:\n${_truncate(syllabusText, 6000)}';
  }

  static String _truncate(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);
}
