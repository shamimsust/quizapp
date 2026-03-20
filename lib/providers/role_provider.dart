import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

enum UserRole { admin, student, unknown }

final userRoleProvider = StreamProvider<String?>((ref) {
  // We use asyncExpand to transform the Auth stream into a Role stream
  return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
    if (user == null) {
      return Stream.value(null);
    }
    
    if (user.isAnonymous) {
      return Stream.value('student');
    }

    // For permanent users (Admins), we listen to the Realtime Database
    final roleRef = FirebaseDatabase.instance.ref('users/${user.uid}/role');
    
    return roleRef.onValue.map((event) {
      final value = event.snapshot.value?.toString();
      // Important: If a user is logged in but has no role in DB, 
      // we return 'unknown' instead of null to tell the router we FINISHED loading.
      return value ?? 'unknown';
    });
  });
});

// Helper providers (unchanged)
final isAdminProvider = Provider<bool>((ref) {
  final role = ref.watch(userRoleProvider).value;
  return role == 'admin';
});

final effectiveRoleProvider = Provider<UserRole>((ref) {
  final roleAsync = ref.watch(userRoleProvider);
  return roleAsync.when(
    data: (role) {
      if (role == 'admin') return UserRole.admin;
      if (role == 'student') return UserRole.student;
      return UserRole.unknown;
    },
    loading: () => UserRole.unknown,
    error: (_, __) => UserRole.unknown,
  );
});