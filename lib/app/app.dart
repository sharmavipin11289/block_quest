import 'package:flutter/material.dart';

import '../features/home/presentation/home_screen.dart';
import 'theme/app_colors.dart';

class BlockQuestApp extends StatelessWidget {
  const BlockQuestApp({super.key});

  static ThemeData get appTheme {
    final textTheme = ThemeData.dark().textTheme.apply(fontFamily: 'Baloo2');
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Baloo2',
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: textTheme.copyWith(
        bodySmall: textTheme.bodySmall!.copyWith(fontSize: 14),
        bodyMedium: textTheme.bodyMedium!.copyWith(fontSize: 17),
        bodyLarge: textTheme.bodyLarge!.copyWith(fontSize: 19),
        labelSmall: textTheme.labelSmall!.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: textTheme.labelMedium!.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        labelLarge: textTheme.labelLarge!.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.gradientMiddle,
            brightness: Brightness.dark,
          ).copyWith(
            primary: AppColors.filled,
            secondary: AppColors.accent,
            surface: AppColors.panel,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gradientMiddle,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Baloo2',
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          textStyle: const TextStyle(
            fontFamily: 'Baloo2',
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(48),
          padding: const EdgeInsets.all(12),
        ),
      ),
      useMaterial3: true,
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Block Quest',
    debugShowCheckedModeBanner: false,
    theme: appTheme,
    home: const SplashScreen(),
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.gradientTop,
    body: LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        return SizedBox.expand(
          child: Image.asset(
            'assets/images/splash_screen.png',
            fit: isLandscape ? BoxFit.contain : BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        );
      },
    ),
  );
}
