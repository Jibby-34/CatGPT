import 'package:flutter/material.dart';
// ADD BACK FOR ADS import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ADD BACK FOR ADS // Initialize Google Mobile Ads SDK
  // ADD BACK FOR ADS await MobileAds.instance.initialize();
  runApp(const CatTranslatorApp());
}

class CatTranslatorApp extends StatelessWidget {
  const CatTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = Colors.indigo;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CatGPT',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          secondary: Colors.tealAccent.shade700,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8FF),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black87,
        ),
      ),
      home: const HomePage(),
    );
  }
}
