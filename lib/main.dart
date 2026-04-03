import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // This is the only web-specific line you need
  usePathUrlStrategy();
  
  runApp(const ProviderScope(child: MyApp()));
}

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