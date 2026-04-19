// models/user_model.dart
// import 'package:cloud_firestore/cloud_firestore.dart';

class UserData {
  final String id;
  final String name;
  final String email;
  final String role; // 'student' or 'staff'
  final String? rollNumber; // For students
  final String? studentClass; // e.g. "VB" for students
  final String department;
  final int downloadCount;
  final DateTime createdAt;
  final String? photoUrl;

  UserData({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.rollNumber,
    this.studentClass,
    required this.department,
    required this.downloadCount,
    required this.createdAt,
    this.photoUrl,
  });

  factory UserData.fromMap(String id, Map<String, dynamic> data) => UserData(
        id: id,
        name: data['name'] ?? '',
        email: data['email'] ?? '',
        role: data['role'] ?? 'student',
        rollNumber: data['rollNumber'],
        studentClass: data['studentClass'],
        department: data['department'] ?? '',
        downloadCount: data['downloadCount'] ?? 0,
        createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
        photoUrl: data['photoUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'uid': id,
        'name': name,
        'email': email,
        'role': role,
        'rollNumber': rollNumber ?? '',
        'studentClass': studentClass ?? '',
        'department': department,
        'downloadCount': downloadCount,
        'createdAt': createdAt,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };
}
