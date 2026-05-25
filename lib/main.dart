import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  
  // Create a notifier to track when the engine is fully ready
  final ValueNotifier<bool> isInitialized = ValueNotifier(false);

  // Run the app wrapper immediately so Flutter can paint a sexy screen right away
  runApp(
    ValueNotifierBuilder(
      notifier: isInitialized,
      builder: (context, ready) {
        if (!ready) {
          // 1. This displays INSTANTLY on boot while Firebase initializes
          return const PreBootLoadingScreen();
        }
        // 2. Swaps to your main application once Firebase finishes loading
        return const ProviderScope(child: MyApp());
      },
    ),
  );

  // Initialize Firebase in the background while the loading screen is spinning
  Future.microtask(() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      debugPrint("Firebase Init Error: $e");
    } finally {
      isInitialized.value = true; // Flips the switch to launch your router
    }
  });
}

// A simple helper widget to handle value listening at the root level
class ValueNotifierBuilder extends StatelessWidget {
  final ValueNotifier<bool> notifier;
  final Widget Function(BuildContext, bool) builder;
  const ValueNotifierBuilder({super.key, required this.notifier, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, value, _) => builder(context, value),
    );
  }
}

// --- THE INSTANT BOOT LOADING SCREEN ---
class PreBootLoadingScreen extends StatelessWidget {
  const PreBootLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F172A), // Deep Slate dark-ambient vibe
                Color(0xFF1E293B),
                Color(0xFF020617),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing circular ring asset simulation
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2264D7).withValues(alpha: 0.12),
                      ),
                    ),
                    const SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text(
                  "INITIALIZING SYSTEM",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white60,
                    letterSpacing: 3.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- YOUR ORIGINAL CORE APPLICATION ---
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appRouter = ref.watch(routerProvider);
    const Color brandBlue = Color(0xFF2264D7); 

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Exam Platform',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: brandBlue),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.light().textTheme,
        ).apply(
          fontFamilyFallback: ['SolaimanLipi'],
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: brandBlue,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: ['SolaimanLipi'],
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      routerConfig: appRouter,
    );
  }
}