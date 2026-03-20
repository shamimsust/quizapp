import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider((_) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  // Using watch is safer for UI-reactive providers
  return ref.watch(authServiceProvider).authStateChanges();
});

final userIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).value?.uid;
});