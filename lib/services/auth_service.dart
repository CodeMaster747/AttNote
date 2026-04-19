// services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/google_oauth_web_client_id.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? _createDefaultGoogleSignIn();

  static GoogleSignIn _createDefaultGoogleSignIn() {
    if (kIsWeb) {
      return GoogleSignIn(clientId: kGoogleOAuthWebClientId);
    }
    return GoogleSignIn();
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Human-readable messages for [FirebaseAuthException.code].
  static String messageForAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
      case 'network_error':
        return 'Network error. Check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Email/password registration + Firestore user document.
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String role,
    required String department,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'unknown',
        message: 'Account created but user is null.',
      );
    }

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': name,
      'email': email,
      'role': role,
      'department': department,
      'rollNumber': '',
      'studentClass': '',
      'downloadCount': 0,
      'photoUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return cred;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Returns `null` if the user cancelled the Google sign-in flow.
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  /// Creates `users/{uid}` if missing (e.g. first Google sign-in). Optionally syncs photo URL.
  Future<void> ensureUserDocument(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'name': user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'User',
        'email': user.email ?? '',
        'role': 'student',
        'department': '',
        'rollNumber': '',
        'studentClass': '',
        'downloadCount': 0,
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    if (user.photoURL != null && user.photoURL!.isNotEmpty) {
      final data = snap.data();
      final existing = data?['photoUrl'] as String?;
      if (existing != user.photoURL) {
        await ref.update({'photoUrl': user.photoURL});
      }
    }
  }

  /// Ensures Firestore profile exists, then returns the user document for routing.
  Future<DocumentSnapshot<Map<String, dynamic>>> prepareSession(User user) async {
    await ensureUserDocument(user);
    final doc =
        await _firestore.collection('users').doc(user.uid).get();
    return doc;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google sign-out: $e');
    }
  }

  // Legacy compatibility
  Future<User?> signIn(String email, String password) async {
    try {
      final cred = await signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user;
    } catch (e) {
      debugPrint('Sign in error: $e');
      return null;
    }
  }

  Future<User?> register(
    String email,
    String password,
    String name,
    String role,
    String department,
  ) async {
    try {
      final cred = await registerWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
        role: role,
        department: department,
      );
      return cred.user;
    } catch (e) {
      debugPrint('Registration error: $e');
      rethrow;
    }
  }
}
