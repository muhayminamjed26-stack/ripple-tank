import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'utils/constants.dart';

class RippleTankApp extends StatelessWidget {
  const RippleTankApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.accent,
      onPrimary: Colors.black,
      secondary: AppColors.accent2,
      surface: AppColors.surface,
    );

    return MaterialApp(
      title: 'Ripple Tank – محاكي حوض الأمواج',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: AppColors.bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          foregroundColor: AppColors.text,
          elevation: 0,
          centerTitle: false,
        ),
        sliderTheme: const SliderThemeData(
          trackHeight: 3,
          overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface2,
          contentTextStyle: TextStyle(color: AppColors.text),
        ),
        dividerColor: AppColors.border,
      ),
      home: const HomeScreen(),
    );
  }
}
