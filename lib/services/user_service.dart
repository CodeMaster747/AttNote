// services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> createOrUpdateUserProfile({
    required String uid,
    required String email,
    required String name,
    required String role, // 'student' or 'staff'
    String? rollNumber,
    String? studentClass,
    required String department,
  }) async {
    final docRef = _firestore.collection('users').doc(uid);

    final data = {
      'email': email,
      'name': name,
      'role': role,
      'department': department,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (role == 'student') {
      data['rollNumber'] = rollNumber ?? '';
      data['studentClass'] = studentClass ?? '';
    }

    await docRef.set(data, SetOptions(merge: true));
  }

  Future<DocumentSnapshot> getUserDoc(String uid) {
    return _firestore.collection('users').doc(uid).get();
  }
}
