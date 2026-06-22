
class AttendancePart {
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  AttendancePart({
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'startDate': startDate,
        'endDate': endDate,
      };

  factory AttendancePart.fromMap(Map<String, dynamic> data) => AttendancePart(
        name: data['name'] ?? '',
        startDate: data['startDate']?.toDate() ?? DateTime.now(),
        endDate: data['endDate']?.toDate() ?? DateTime.now(),
      );
}

/// A subject owned either by a student (personal) or a staff member.
///
/// A student gains a staff-owned subject only when that staff adds the
/// student by email; a mirrored copy is then written into the student's
/// subjects subcollection with [linkedStaffId] / [linkedStaffSubjectId] set so
/// the existing per-user attendance pipeline keeps working unchanged.
class Subject {
  final String id;
  final String name;
  final String createdBy; // owner uid (staff or student)
  final String ownerRole; // 'student' | 'staff'
  final String staffName; // display name of the owning staff (linked copies)
  final String department;
  final String section;
  final List<AttendancePart> attendanceParts;
  final Map<String, int> timetable; // weekday name -> number of classes
  final List<String> taughtDays; // weekday names the subject is taught
  final List<String> studentIds; // staff-side roster
  final bool courseGuideEnabled;

  // Linkage for a student's mirrored copy of a staff subject.
  final String linkedStaffId;
  final String linkedStaffSubjectId;

  // Optional reference files (Course Guide).
  final String? syllabusUrl;
  final String? syllabusFileName;
  final String? holidayUrl;
  final String? holidayFileName;

  Subject({
    required this.id,
    required this.name,
    this.createdBy = '',
    this.ownerRole = 'student',
    this.staffName = '',
    this.department = '',
    this.section = '',
    this.attendanceParts = const [],
    this.timetable = const {},
    this.taughtDays = const [],
    this.studentIds = const [],
    this.courseGuideEnabled = false,
    this.linkedStaffId = '',
    this.linkedStaffSubjectId = '',
    this.syllabusUrl,
    this.syllabusFileName,
    this.holidayUrl,
    this.holidayFileName,
  });

  /// Owned by a staff member (the staff's source-of-truth document).
  bool get isStaffOwned => ownerRole == 'staff';

  /// A student's copy that is shared with / managed by a staff member.
  bool get isLinkedToStaff => linkedStaffId.isNotEmpty;

  /// True for any subject that involves a staff member (for display).
  bool get hasStaff => isStaffOwned || isLinkedToStaff || staffName.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'name': name,
        'createdBy': createdBy,
        'ownerRole': ownerRole,
        'staffName': staffName,
        'department': department,
        'section': section,
        'attendanceParts': attendanceParts.map((x) => x.toMap()).toList(),
        'timetable': timetable,
        'taughtDays': taughtDays,
        'studentIds': studentIds,
        'courseGuideEnabled': courseGuideEnabled,
        'linkedStaffId': linkedStaffId,
        'linkedStaffSubjectId': linkedStaffSubjectId,
        if (syllabusUrl != null) 'syllabusUrl': syllabusUrl,
        if (syllabusFileName != null) 'syllabusFileName': syllabusFileName,
        if (holidayUrl != null) 'holidayUrl': holidayUrl,
        if (holidayFileName != null) 'holidayFileName': holidayFileName,
      };

  factory Subject.fromMap(Map<String, dynamic> data, String id) => Subject(
        id: id,
        name: data['name'] ?? '',
        createdBy: data['createdBy'] ?? '',
        ownerRole: data['ownerRole'] ?? 'student',
        staffName: data['staffName'] ?? '',
        department: data['department'] ?? '',
        section: data['section'] ?? '',
        attendanceParts: (data['attendanceParts'] as List<dynamic>?)
                ?.map((x) => AttendancePart.fromMap(x))
                .toList() ??
            [],
        timetable: (data['timetable'] as Map<dynamic, dynamic>?)?.map(
              (key, value) => MapEntry(key.toString(), (value as num).toInt()),
            ) ??
            {},
        taughtDays: (data['taughtDays'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        studentIds: (data['studentIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        courseGuideEnabled: data['courseGuideEnabled'] ?? false,
        linkedStaffId: data['linkedStaffId'] ?? '',
        linkedStaffSubjectId: data['linkedStaffSubjectId'] ?? '',
        syllabusUrl: data['syllabusUrl'] as String?,
        syllabusFileName: data['syllabusFileName'] as String?,
        holidayUrl: data['holidayUrl'] as String?,
        holidayFileName: data['holidayFileName'] as String?,
      );

  Subject copyWith({
    String? name,
    String? staffName,
    String? department,
    String? section,
    List<AttendancePart>? attendanceParts,
    Map<String, int>? timetable,
    List<String>? taughtDays,
    List<String>? studentIds,
    bool? courseGuideEnabled,
    String? syllabusUrl,
    String? syllabusFileName,
    String? holidayUrl,
    String? holidayFileName,
  }) =>
      Subject(
        id: id,
        name: name ?? this.name,
        createdBy: createdBy,
        ownerRole: ownerRole,
        staffName: staffName ?? this.staffName,
        department: department ?? this.department,
        section: section ?? this.section,
        attendanceParts: attendanceParts ?? this.attendanceParts,
        timetable: timetable ?? this.timetable,
        taughtDays: taughtDays ?? this.taughtDays,
        studentIds: studentIds ?? this.studentIds,
        courseGuideEnabled: courseGuideEnabled ?? this.courseGuideEnabled,
        linkedStaffId: linkedStaffId,
        linkedStaffSubjectId: linkedStaffSubjectId,
        syllabusUrl: syllabusUrl ?? this.syllabusUrl,
        syllabusFileName: syllabusFileName ?? this.syllabusFileName,
        holidayUrl: holidayUrl ?? this.holidayUrl,
        holidayFileName: holidayFileName ?? this.holidayFileName,
      );
}
