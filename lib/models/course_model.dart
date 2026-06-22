// models/course_model.dart
//
// Models for staff course management: tests, the per-taught-day plan, and the
// collapsible content sections shown on a subject.

/// A scheduled assessment with the portion (syllabus coverage) it covers.
class CourseTest {
  final String id;
  final String name;
  final DateTime date;
  final String portion;

  CourseTest({
    required this.id,
    required this.name,
    required this.date,
    required this.portion,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'date': date,
        'portion': portion,
      };

  factory CourseTest.fromMap(Map<String, dynamic> data, String id) => CourseTest(
        id: id,
        name: data['name'] ?? '',
        date: data['date']?.toDate() ?? DateTime.now(),
        portion: data['portion'] ?? '',
      );
}

/// What was (or will be) taught on a specific day, plus that day's notes.
class DayPlan {
  final String id; // date key: yyyy-MM-dd
  final DateTime date;
  final String topic;
  final String notes;

  DayPlan({
    required this.id,
    required this.date,
    required this.topic,
    required this.notes,
  });

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
        'date': DateTime(date.year, date.month, date.day),
        'topic': topic,
        'notes': notes,
      };

  factory DayPlan.fromMap(Map<String, dynamic> data, String id) => DayPlan(
        id: id,
        date: data['date']?.toDate() ?? DateTime.now(),
        topic: data['topic'] ?? '',
        notes: data['notes'] ?? '',
      );
}

/// A learning resource (article or YouTube video) for a guide topic.
class GuideResource {
  final String title;
  final String url;

  GuideResource({required this.title, required this.url});

  bool get isYouTube =>
      url.contains('youtube.com') || url.contains('youtu.be');

  Map<String, dynamic> toMap() => {'title': title, 'url': url};

  factory GuideResource.fromMap(Map<String, dynamic> d) => GuideResource(
        title: (d['title'] ?? '').toString(),
        url: (d['url'] ?? '').toString(),
      );
}

/// One topic in the generated teaching plan, with its scheduled date,
/// prerequisites and resources.
class GuideTopic {
  final String unit;
  final String topic;
  final DateTime? date;
  final bool isRevision;
  final List<String> prerequisites;
  final List<GuideResource> resources;

  GuideTopic({
    required this.unit,
    required this.topic,
    this.date,
    this.isRevision = false,
    this.prerequisites = const [],
    this.resources = const [],
  });

  GuideTopic copyWith({DateTime? date, bool? isRevision}) => GuideTopic(
        unit: unit,
        topic: topic,
        date: date ?? this.date,
        isRevision: isRevision ?? this.isRevision,
        prerequisites: prerequisites,
        resources: resources,
      );

  Map<String, dynamic> toMap() => {
        'unit': unit,
        'topic': topic,
        if (date != null) 'date': DateTime(date!.year, date!.month, date!.day),
        'isRevision': isRevision,
        'prerequisites': prerequisites,
        'resources': resources.map((r) => r.toMap()).toList(),
      };

  factory GuideTopic.fromMap(Map<String, dynamic> d) => GuideTopic(
        unit: (d['unit'] ?? '').toString(),
        topic: (d['topic'] ?? '').toString(),
        date: d['date']?.toDate(),
        isRevision: d['isRevision'] ?? false,
        prerequisites: (d['prerequisites'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        resources: (d['resources'] as List<dynamic>?)
                ?.map((e) => GuideResource.fromMap(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );
}

/// A generated Course Guide for a subject, tied to a specific test.
class CourseGuide {
  final String testId;
  final String testName;
  final DateTime examDate;
  final DateTime generatedAt;
  final List<GuideTopic> topics;

  CourseGuide({
    required this.testId,
    required this.testName,
    required this.examDate,
    required this.generatedAt,
    required this.topics,
  });

  Map<String, dynamic> toMap() => {
        'testId': testId,
        'testName': testName,
        'examDate': examDate,
        'generatedAt': generatedAt,
        'topics': topics.map((t) => t.toMap()).toList(),
      };

  factory CourseGuide.fromMap(Map<String, dynamic> d) => CourseGuide(
        testId: (d['testId'] ?? '').toString(),
        testName: (d['testName'] ?? '').toString(),
        examDate: d['examDate']?.toDate() ?? DateTime.now(),
        generatedAt: d['generatedAt']?.toDate() ?? DateTime.now(),
        topics: (d['topics'] as List<dynamic>?)
                ?.map((e) =>
                    GuideTopic.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            [],
      );
}

enum SubjectSectionType { dayWise, notes, custom }

/// A collapsible content row shown on a subject (e.g. "Day-wise", "Notes", or a
/// staff-defined custom row). [dayWise] and [notes] are derived/aggregated;
/// [custom] rows carry their own free-form [content].
class SubjectSection {
  final String id;
  final String title;
  final SubjectSectionType type;
  final int order;
  final String content;

  SubjectSection({
    required this.id,
    required this.title,
    this.type = SubjectSectionType.custom,
    this.order = 0,
    this.content = '',
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'type': type.name,
        'order': order,
        'content': content,
      };

  factory SubjectSection.fromMap(Map<String, dynamic> data, String id) =>
      SubjectSection(
        id: id,
        title: data['title'] ?? '',
        type: SubjectSectionType.values.firstWhere(
          (e) => e.name == data['type'],
          orElse: () => SubjectSectionType.custom,
        ),
        order: (data['order'] as num?)?.toInt() ?? 0,
        content: data['content'] ?? '',
      );
}
