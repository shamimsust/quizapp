import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  /// Stream to track the current login state across the app
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Gets the current user or null if not logged in
  User? get currentUser => _auth.currentUser;

  /// Used for the Admin panel to manage exams
  Future<User?> signInAdmin(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email, 
      password: password
    );
    return cred.user;
  }

  /// Used in 'token_landing_screen.dart' for students entering the exam
  Future<User?> signInStudentAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return cred.user;
  }

  /// Clears session for both Admins and Students
  Future<void> signOut() => _auth.signOut();
}