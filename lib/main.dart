import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'services/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(SubscriptionService.initialize());
  unawaited(SubscriptionService.validateSubscription());
  GoogleFonts.config.allowRuntimeFetching = true;
  runApp(const AIWireApp());
}

class AIWireApp extends StatefulWidget {
  const AIWireApp({super.key});
  @override
  State<AIWireApp> createState() => _AIWireAppState();
}

class _AIWireAppState extends State<AIWireApp> {
  @override
  void dispose() {
    SubscriptionService.dispose();
    super.dispose();
  }

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
