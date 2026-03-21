import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Admin Screens
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_signin_screen.dart';
import 'screens/admin/exam_builder_screen.dart';
import 'screens/admin/token_manager_screen.dart';
import 'screens/admin/question_editor_screen.dart';
import 'screens/admin/manual_grading_screen.dart';
import 'screens/admin/exam_list_screen.dart'; 
import 'screens/admin/leaderboard_screen.dart'; 

// Student Screens
import 'screens/student/token_landing_screen.dart';
import 'screens/student/exam_room_screen.dart';
import 'screens/student/candidate_info_screen.dart';
import 'screens/student/exam_instructions_screen.dart';
import 'screens/student/submission_screen.dart';
import 'screens/student/result_screen.dart';
import 'screens/student/result_lookup_screen.dart'; 

import 'providers/auth_providers.dart';
import 'providers/role_provider.dart';
import 'utils/go_router_refresh_stream.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authStateProvider);
  final roleAsync = ref.watch(userRoleProvider);

  final user = authAsync.value;
  final role = roleAsync.value;

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
    redirect: (context, state) {
      final String loc = state.matchedLocation;
      final bool goingAdmin = loc.startsWith('/admin');
      final bool onAdminLogin = loc == '/admin/signin';
      final bool onRoot = loc == '/';
      final bool onLoading = loc == '/loading';

      // 1. Handle Loading States
      if (roleAsync.isLoading || roleAsync.isRefreshing) {
        return '/loading';
      }

      if (onLoading && !roleAsync.isLoading) {
        return '/'; 
      }

      // 2. Admin Access Control (If user is ALREADY verified as admin)
      if (user != null && role == 'admin') {
        if (onRoot || onAdminLogin) return '/admin';
        return null; 
      }

      // 3. Security Redirection & Path Guarding
      if (goingAdmin) {
        // ALLOW everyone to see the sign-in page regardless of session
        if (onAdminLogin) return null;

        // If trying to access admin screens without a session
        if (user == null) {
          return '/admin/signin';
        }

        // If logged in but NOT an admin (e.g. Anonymous Student session)
        // This ensures the "Admin Login" button actually navigates
        if (role != 'admin') {
          return '/admin/signin';
        }
      }

      return null;
    },
    routes: [
      // GLOBAL LOADING
      GoRoute(
        path: '/loading',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF2264D7)),
                SizedBox(height: 16),
                Text("Verifying access...", style: TextStyle(fontFamily: 'Inter', color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),

      GoRoute(path: '/', builder: (_, __) => const TokenLandingScreen()),
      
      // --- ADMIN ROUTES ---
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
      GoRoute(path: '/admin/signin', builder: (_, __) => const AdminSignInScreen()),
      GoRoute(path: '/admin/exam-builder', builder: (_, __) => const ExamBuilderScreen()),
      GoRoute(path: '/admin/token-manager', builder: (_, __) => const TokenManagerScreen()),
      GoRoute(path: '/admin/exam-list', builder: (_, __) => const ExamListScreen()),
      GoRoute(path: '/admin/manual-grading', builder: (_, __) => const ManualGradingScreen()),
      GoRoute(path: '/admin/leaderboard', builder: (_, __) => const AdminLeaderboardScreen()), 
      GoRoute(
          path: '/admin/exam-builder/questions/:examId',
          builder: (ctx, st) => QuestionEditorScreen(examId: st.pathParameters['examId']!)),

      // --- STUDENT ROUTES ---
      GoRoute(
          path: '/e/:token',
          builder: (ctx, st) => TokenLandingScreen(token: st.pathParameters['token'])),
      
      GoRoute(
          path: '/instructions/:examId',
          builder: (ctx, st) => ExamInstructionsScreen(examId: st.pathParameters['examId']!)),

      GoRoute(
        path: '/candidate/:examId', 
        builder: (ctx, st) {
          final idFromPath = st.pathParameters['examId'];
          final extra = st.extra as Map<String, dynamic>?;
          return CandidateInfoScreen(examId: idFromPath ?? extra?['examId']);
        },
      ),
      
      GoRoute(
        path: '/candidate',
        builder: (ctx, st) {
          final extra = st.extra as Map<String, dynamic>?;
          return CandidateInfoScreen(examId: extra?['examId']);
        },
      ),

      GoRoute(
          path: '/exam/:attemptId',
          builder: (ctx, st) => ExamRoomScreen(attemptId: st.pathParameters['attemptId']!)),
      GoRoute(
          path: '/submitted/:attemptId',
          builder: (ctx, st) => SubmissionScreen(attemptId: st.pathParameters['attemptId']!)),
      
      GoRoute(
          path: '/results',
          builder: (ctx, st) => const ResultLookupScreen()),

      GoRoute(
          path: '/result/:attemptId',
          builder: (ctx, st) => ResultScreen(attemptId: st.pathParameters['attemptId']!)),
    ],
  );
});