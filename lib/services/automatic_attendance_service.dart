// services/automatic_attendance_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';

class AutomaticAttendanceService {
  final FirestoreService _firestoreService = FirestoreService();

  // Initialize and check if we should mark attendance
  Future<void> checkAndMarkAttendance() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uid = user.uid;

      // Check if automatic attendance is enabled
      final isEnabled = await _firestoreService.getAutoAttendanceSetting(uid);
      if (!isEnabled) return;

      // Mark attendance for today
      await _firestoreService.markAutomaticAttendance(uid);

      debugPrint('Automatic attendance marked successfully');
    } catch (e) {
      debugPrint('Error in automatic attendance service: $e');
    }
  }

  // This can be called on app startup or at scheduled times
  Future<void> initialize() async {
    await checkAndMarkAttendance();
  }
}
