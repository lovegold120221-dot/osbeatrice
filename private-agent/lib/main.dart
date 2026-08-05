import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:developer';
import 'config/feature_flags.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'overlay_main.dart';
import 'theme/beatrice_theme.dart';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        canvasColor: Colors.transparent,
        scaffoldBackgroundColor: Colors.transparent,
        cardColor: Colors.white,
        dialogBackgroundColor: Colors.transparent,
        primaryColor: const Color(0xFF4F46E5),
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          background: Colors.transparent,
          primary: Color(0xFF4F46E5),
          surface: Colors.white,
          onSurface: Color(0xFF1E293B),
          onPrimary: Colors.white,
        ),
      ),
      builder: (context, child) {
        return Container(color: Colors.transparent, child: child);
      },
      home: const OverlayApp(),
    ),
  );
}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void Function(String task)? onOverlayTask;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (error) {
    // The UI remains usable if Firebase is temporarily unavailable; the task
    // bridge reports its own connection failure rather than crashing startup.
    log('Firebase initialization failed: $error');
  }

  if (FeatureFlags.floatingOverlayEnabled) {
    FlutterOverlayWindow.overlayListener.listen((event) {
      log("Main app received from overlay: $event");
      if (event is String && event.trim().isNotEmpty) {
        if (onOverlayTask != null) {
          onOverlayTask!(event.trim());
        } else {
          log("Warning: overlay task received but no handler registered yet");
        }
      }
    });
  }

  final prefs = await SharedPreferences.getInstance();
  final themeStr = prefs.getString('themeMode');
  if (themeStr == 'dark') {
    themeNotifier.value = ThemeMode.dark;
  } else {
    themeNotifier.value = ThemeMode.light;
  }

  final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

  runApp(BeatriceOSApp(onboardingCompleted: onboardingCompleted));
}

class BeatriceOSApp extends StatelessWidget {
  final bool onboardingCompleted;
  const BeatriceOSApp({super.key, required this.onboardingCompleted});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, ThemeMode currentMode, child) {
        return MaterialApp(
          title: 'Beatrice OS',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: BeatriceTheme.text,
            scaffoldBackgroundColor: BeatriceTheme.black,
            textTheme: BeatriceTheme.textTheme(ThemeData.dark().textTheme),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFFFFF),
              secondary: Color(0xFF60A5FA),
              surface: Color(0xFF1A1A1A),
              onSurface: Color(0xFFF5F5F5),
              surfaceContainerHighest: Color(0xFF212121),
              error: Color(0xFFF87171),
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Color(0xFFF5F5F5),
              iconTheme: IconThemeData(color: Color(0xFFF5F5F5)),
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              ),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              color: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(
                  color: Color(0xFF2A2A2A),
                  width: 1.2,
                ), // Slate-200
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: BeatriceTheme.text,
            scaffoldBackgroundColor: BeatriceTheme.black,
            textTheme: BeatriceTheme.textTheme(ThemeData.dark().textTheme),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFFFFF),
              secondary: Color(0xFF60A5FA),
              surface: Color(0xFF1A1A1A),
              onSurface: Color(0xFFF5F5F5),
              surfaceContainerHighest: Color(0xFF212121),
              error: Color(0xFFF87171),
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Color(0xFFF5F5F5),
              iconTheme: IconThemeData(color: Color(0xFFF5F5F5)),
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              ),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              color: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: const Color(0xFF2A2A2A), width: 1.2),
              ),
            ),
          ),
          home: onboardingCompleted
              ? const HomeScreen()
              : const OnboardingScreen(),
        );
      },
    );
  }
}
