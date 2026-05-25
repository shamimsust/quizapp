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
import 'screens/admin/question_bank_screen.dart';
import 'screens/admin/bank_question_editor_screen.dart';

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
    refreshListenable:
        GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
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

      // 2. Admin Access Control
      if (user != null && role == 'admin') {
        if (onRoot || onAdminLogin) return '/admin';
        return null;
      }

      // 3. Security Redirection & Path Guarding
      if (goingAdmin) {
        if (onAdminLogin) return null;
        if (user == null) return '/admin/signin';
        if (role != 'admin') return '/admin/signin';
      }

      return null;
    },
    routes: [
      // GLOBAL SEXY LOADING SCREEN
      GoRoute(
        path: '/loading',
        builder: (context, state) => const PremiumAuthLoadingScreen(),
      ),

      GoRoute(path: '/', builder: (_, __) => const TokenLandingScreen()),

      // --- ADMIN ROUTES ---
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
      GoRoute(
          path: '/admin/signin', builder: (_, __) => const AdminSignInScreen()),
      GoRoute(
          path: '/admin/question-bank',
          builder: (_, __) => const QuestionBankScreen()),

      GoRoute(
        path: '/admin/exam-builder/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final bankParent = state.uri.queryParameters['bankParent'];
          return BankQuestionEditorScreen(
            questionId: id == 'new' ? null : id,
            parentId: bankParent ?? 'root',
          );
        },
      ),

      GoRoute(
          path: '/admin/exam-builder',
          builder: (_, __) => const ExamBuilderScreen()),
      GoRoute(
          path: '/admin/token-manager',
          builder: (_, __) => const TokenManagerScreen()),
      GoRoute(
          path: '/admin/exam-list', builder: (_, __) => const ExamListScreen()),
      GoRoute(
          path: '/admin/manual-grading',
          builder: (_, __) => const ManualGradingScreen()),
      GoRoute(
          path: '/admin/leaderboard',
          builder: (_, __) => const AdminLeaderboardScreen()),
      GoRoute(
          path: '/admin/exam-builder/questions/:examId',
          builder: (ctx, st) =>
              QuestionEditorScreen(examId: st.pathParameters['examId']!)),

      // --- STUDENT ROUTES ---
      GoRoute(
          path: '/e/:token',
          builder: (ctx, st) =>
              TokenLandingScreen(token: st.pathParameters['token'])),

      GoRoute(
          path: '/instructions/:examId',
          builder: (ctx, st) =>
              ExamInstructionsScreen(examId: st.pathParameters['examId']!)),

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
          builder: (ctx, st) =>
              ExamRoomScreen(attemptId: st.pathParameters['attemptId']!)),
      GoRoute(
          path: '/submitted/:attemptId',
          builder: (ctx, st) =>
              SubmissionScreen(attemptId: st.pathParameters['attemptId']!)),

      GoRoute(
          path: '/results', builder: (ctx, st) => const ResultLookupScreen()),

      GoRoute(
          path: '/result/:attemptId',
          builder: (ctx, st) =>
              ResultScreen(attemptId: st.pathParameters['attemptId']!)),
    ],
  );
});

// --- SEXY PREMIUMLOADING WIDGET ---
class PremiumAuthLoadingScreen extends StatefulWidget {
  const PremiumAuthLoadingScreen({super.key});

  @override
  State<PremiumAuthLoadingScreen> createState() =>
      _PremiumAuthLoadingScreenState();
}

class _PremiumAuthLoadingScreenState extends State<PremiumAuthLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A), // Deep Slate-900 Dark Background
              Color(0xFF1E293B), // Slate-800
              Color(0xFF020617), // Deep Slate-950
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Abstract tech lines / graphic flare overlay
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2264D7).withValues(alpha: 0.08),
                      blurRadius: 80,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer animated aura ring
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2264D7).withValues(alpha: 0.1),
                        ),
                      ),
                      // Core glowing orb
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2264D7).withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            )
                          ],
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          ),
                        ),
                        child: const Icon(
                          Icons
                              .shield_rounded, // Premium looking security token guard
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Typography Title Branding
                const Text(
                  "SECURE GATEWAY",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white70,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle Tracking text status
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            const Color(0xFF38BDF8).withValues(alpha: 0.8)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Verifying encrypted access credentials...",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
