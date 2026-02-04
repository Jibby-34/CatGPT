import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'pages/home_page.dart';
import 'pages/onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock screen orientation to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Google Mobile Ads SDK
  await MobileAds.instance.initialize();

  // Load saved theme mode and onboarding status before app starts
  final prefs = await SharedPreferences.getInstance();
  
  // Migrate from old boolean isDarkMode to new string themeMode
  String themeMode;
  if (prefs.containsKey('themeMode')) {
    themeMode = prefs.getString('themeMode') ?? 'system';
  } else if (prefs.containsKey('isDarkMode')) {
    // Migrate old boolean preference to new string preference
    final oldIsDarkMode = prefs.getBool('isDarkMode') ?? false;
    themeMode = oldIsDarkMode ? 'dark' : 'light';
    await prefs.setString('themeMode', themeMode);
    await prefs.remove('isDarkMode');
  } else {
    // Default to system for new users
    themeMode = 'system';
  }
  
  final onboardingCompleted = prefs.getBool('onboardingCompleted') ?? false;

  runApp(CatTranslatorApp(
    themeMode: themeMode,
    onboardingCompleted: onboardingCompleted,
  ));
}

class CatTranslatorApp extends StatefulWidget {
  final String themeMode;
  final bool onboardingCompleted;
  const CatTranslatorApp({
    super.key,
    required this.themeMode,
    required this.onboardingCompleted,
  });

  @override
  State<CatTranslatorApp> createState() => _CatTranslatorAppState();
}

class _CatTranslatorAppState extends State<CatTranslatorApp> {
  late String _themeMode;
  late bool _onboardingCompleted;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.themeMode;
    _onboardingCompleted = widget.onboardingCompleted;
  }

  void _changeTheme(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode);
    setState(() => _themeMode = mode);
  }

  void _completeOnboarding() {
    setState(() => _onboardingCompleted = true);
  }

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF6366F1); // Modern indigo

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CatGPT',
      themeMode: _themeMode == 'system' 
          ? ThemeMode.system 
          : (_themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF14B8A6),
          tertiary: const Color(0xFF8B5CF6),
          surface: Colors.white,
          surfaceContainerHighest: const Color(0xFFF8FAFC),
        ),
        scaffoldBackgroundColor: const Color(0xFFFAFBFF),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xFF1E293B),
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: Color(0xFF1E293B),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8),
          displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.1),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.1),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          primary: const Color(0xFF818CF8),
          secondary: const Color(0xFF2DD4BF),
          tertiary: const Color(0xFFA78BFA),
          surface: const Color(0xFF1E293B),
          surfaceContainerHighest: const Color(0xFF334155),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: const Color(0xFF1E293B),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8),
          displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.1),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.1),
        ),
      ),
      home: _onboardingCompleted
          ? HomePage(
              themeMode: _themeMode,
              onThemeChanged: _changeTheme,
            )
          : OnboardingPage(
              onComplete: _completeOnboarding,
            ),
    );
  }
}
