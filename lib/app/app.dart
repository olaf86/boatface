import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/home/presentation/home_screen.dart';

class BoatfaceApp extends ConsumerWidget {
  const BoatfaceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    const Color splashBlue = Color(0xFF22B7E8);
    const Color deepWater = Color(0xFF0B4F9C);
    const Color foamWhite = Color(0xFFF6FCFF);
    const Color sunYellow = Color(0xFFFFC83D);
    const Color coral = Color(0xFFFF6F61);
    final ColorScheme colorScheme =
        ColorScheme.fromSeed(
          seedColor: splashBlue,
          brightness: Brightness.light,
        ).copyWith(
          primary: deepWater,
          onPrimary: Colors.white,
          secondary: sunYellow,
          onSecondary: const Color(0xFF2A1D00),
          tertiary: coral,
          onTertiary: Colors.white,
          surface: foamWhite,
          surfaceContainerHighest: const Color(0xFFDFF6FF),
          onSurface: const Color(0xFF11314C),
          outline: const Color(0xFF7DB7D6),
          outlineVariant: const Color(0xFFB7DCEE),
          error: const Color(0xFFD43D2C),
        );
    final TextTheme baseTextTheme = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
    ).textTheme;
    final TextTheme textTheme =
        GoogleFonts.mPlusRounded1cTextTheme(baseTextTheme).copyWith(
          displayLarge: GoogleFonts.baloo2(
            textStyle: baseTextTheme.displayLarge,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
          displayMedium: GoogleFonts.baloo2(
            textStyle: baseTextTheme.displayMedium,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
          displaySmall: GoogleFonts.baloo2(
            textStyle: baseTextTheme.displaySmall,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
          headlineLarge: GoogleFonts.baloo2(
            textStyle: baseTextTheme.headlineLarge,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
          headlineMedium: GoogleFonts.baloo2(
            textStyle: baseTextTheme.headlineMedium,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
          headlineSmall: GoogleFonts.baloo2(
            textStyle: baseTextTheme.headlineSmall,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
          titleLarge: GoogleFonts.baloo2(
            textStyle: baseTextTheme.titleLarge,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
          titleMedium: GoogleFonts.mPlusRounded1c(
            textStyle: baseTextTheme.titleMedium,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
          bodyLarge: GoogleFonts.mPlusRounded1c(
            textStyle: baseTextTheme.bodyLarge,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
          bodyMedium: GoogleFonts.mPlusRounded1c(
            textStyle: baseTextTheme.bodyMedium,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
          labelLarge: GoogleFonts.mPlusRounded1c(
            textStyle: baseTextTheme.labelLarge,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        );

    return MaterialApp(
      title: 'Boatface',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        textTheme: textTheme,
        scaffoldBackgroundColor: const Color(0xFFEAF9FF),
        canvasColor: foamWhite,
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFEAF9FF),
          foregroundColor: colorScheme.primary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: textTheme.headlineSmall,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          margin: EdgeInsets.zero,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: colorScheme.surfaceContainerHighest,
          selectedColor: colorScheme.secondary.withValues(alpha: 0.2),
          disabledColor: colorScheme.surfaceContainerHighest,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          labelStyle: textTheme.labelMedium ?? textTheme.bodySmall!,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: textTheme.titleMedium,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.primary,
            side: BorderSide(color: colorScheme.outline, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: textTheme.titleMedium,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          labelStyle: textTheme.bodyMedium,
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 10,
          ),
          iconColor: colorScheme.primary,
        ),
        dividerTheme: DividerThemeData(
          color: colorScheme.outlineVariant,
          thickness: 1,
          space: 1,
        ),
      ),
      builder: (BuildContext context, Widget? child) {
        return _AppBackground(child: child ?? const SizedBox.shrink());
      },
      home: authState.isSignedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}

class _AppBackground extends StatelessWidget {
  const _AppBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFFE8FBFF),
            Color(0xFFCDEFFF),
            Color(0xFFFDF8E7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -80,
            right: -40,
            child: _Bubble(size: 220, color: const Color(0x55FFFFFF)),
          ),
          Positioned(
            top: 120,
            left: -50,
            child: _Bubble(size: 140, color: const Color(0x40FFFFFF)),
          ),
          Positioned(
            bottom: -70,
            right: 40,
            child: _Bubble(size: 180, color: const Color(0x30FFFFFF)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -20,
            child: Container(
              height: 180,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[Color(0x00000000), Color(0x5522B7E8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
