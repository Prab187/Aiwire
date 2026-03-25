import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'services/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // In production, secrets should be injected via environment variables or a
  // backend proxy — not bundled as assets. The .env file is optional here.
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // .env not present in production builds — that's expected
  }
  await SubscriptionService.initialize();
  unawaited(SubscriptionService.validateSubscription());
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
            seedColor: Colors.black, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
