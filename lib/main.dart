import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'providers/items_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/signin_screen.dart';
import 'services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    // Disable debug prints for cleaner development
    debugPrintRebuildDirtyWidgets = false;
  }
  await initializeFirebase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ItemsProvider(),
      child: MaterialApp(
        title: 'Expyr',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: AppTheme.primaryGreen,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppTheme.primaryGreen,
            primary: AppTheme.primaryGreen,
          ),
          scaffoldBackgroundColor: AppTheme.neutralWhite,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppTheme.white,
            elevation: 0,
          ),
          useMaterial3: true,
          fontFamily: 'Inter',
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF85D45C),
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              borderSide: BorderSide(color: AppTheme.primaryGreen),
            ),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
