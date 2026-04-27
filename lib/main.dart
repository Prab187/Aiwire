import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'services/subscription_service.dart';
import 'services/firestore_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp()
        .timeout(const Duration(seconds: 5));
  } catch (_) {
    // Firebase unavailable — app runs without Firestore cache
  }
  unawaited(SubscriptionService.initialize());
  unawaited(SubscriptionService.validateSubscription());
  // Kick off background cache refresh — non-blocking
  unawaited(FirestoreService.refreshIfStale());
  GoogleFonts.config.allowRuntimeFetching = true;
  runApp(const AIWireApp());
}

class AIWireApp extends StatelessWidget {
  const AIWireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIWire',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.black, brightness: Brightness.dark)
            .copyWith(surfaceTint: Colors.transparent),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
