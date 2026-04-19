
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



class Subject {
  final String id;
  final String name;
  final bool isGlobal;
  final String createdBy; // Staff ID
  final String staffName; // Staff Name (for Global Subjects)
  final String department;
  final String section;
  final List<AttendancePart> attendanceParts;
  final Map<String, int> timetable; // Day name -> number of classes

  Subject({
    required this.id,
    required this.name,
    this.isGlobal = false,
    this.createdBy = '',
    this.staffName = '',
    this.department = '',
    this.section = '',
    this.attendanceParts = const [],
    this.timetable = const {},
  });
  
  Map<String, dynamic> toMap() => {
    'name': name,
    'isGlobal': isGlobal,
    'createdBy': createdBy,
    'staffName': staffName,
    'department': department,
    'section': section,
    'attendanceParts': attendanceParts.map((x) => x.toMap()).toList(),
    'timetable': timetable,
  };

  factory Subject.fromMap(Map<String, dynamic> data, String id) =>
      Subject(
        id: id, 
        name: data['name'] ?? '',
        isGlobal: data['isGlobal'] ?? false,
        createdBy: data['createdBy'] ?? '',
        staffName: data['staffName'] ?? '',
        department: data['department'] ?? '',
        section: data['section'] ?? '',
        attendanceParts: (data['attendanceParts'] as List<dynamic>?)
            ?.map((x) => AttendancePart.fromMap(x))
            .toList() ?? [],
        timetable: (data['timetable'] as Map<dynamic, dynamic>?)?.map(
          (key, value) => MapEntry(key.toString(), value as int),
        ) ?? {},
      );
}

// Model for staff class information (unchanged but context)
class ClassInfo {
  final String id;
  final String subjectName;
  final String department;
  final String className;
  final String subjectId;

  ClassInfo({
    required this.id,
    required this.subjectName,
    required this.department,
    required this.className,
    required this.subjectId,
  });

  factory ClassInfo.fromMap(Map<String, dynamic> data, String id) => ClassInfo(
        id: id,
        subjectId: data['subjectId'] ?? '',
        subjectName: data['subjectName'] ?? '',
        department: data['department'] ?? '',
        className: data['className'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'subjectName': subjectName,
        'department': department,
        'className': className,
        'subjectId': subjectId,
      };
}
