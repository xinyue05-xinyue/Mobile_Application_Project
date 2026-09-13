import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color primary = Color(0xFFC84F62);
  static const Color background = Color(0xFFFFF8F6);

  static const Color donor = Color(0xFFE5394F);
  static const Color donorBackground = Color(0xFFFFF8F9);
  static const Color donorHeader = Color(0xFFC6283E);
  static const Color donorMutedOutline = Color(0xFFB99299);
  static const TextStyle donorHeaderTitleStyle = TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static ButtonStyle get donorMutedOutlinedButtonStyle =>
      OutlinedButton.styleFrom(
        foregroundColor: light.colorScheme.primary,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: donorMutedOutline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      );

  static ButtonStyle get donorPrimaryButtonStyle => FilledButton.styleFrom(
    backgroundColor: donorHeader,
    foregroundColor: Colors.white,
    disabledBackgroundColor: donorMutedOutline.withValues(alpha: .28),
    disabledForegroundColor: ink.withValues(alpha: .48),
    minimumSize: const Size(0, 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  static const Color organisation = Color(0xFFE86A3C);
  static const Color organisationBackground = Color(0xFFFFF9F5);
  static const Color organisationHeader = Color(0xFFC84A1F);
  static const TextStyle organisationHeaderTitleStyle = TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static const Color hospital = Color(0xFFD6457F);
  static const Color hospitalBackground = Color(0xFFFFF5F9);
  static const Color hospitalHeader = Color(0xFFB72E68);
  static const TextStyle hospitalHeaderTitleStyle = TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static const Color systemAdmin = Color(0xFFA94444);
  static const Color systemAdminBackground = Color(0xFFFCF0F0);
  static const Color systemAdminHeader = Color(0xFF7E2E2E);
  static const TextStyle systemAdminHeaderTitleStyle = TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static const List<Color> donorPalette = [
    donorBackground,
    Color(0xFFFFC1C8),
    Color(0xFFFF6B7A),
    Color(0xFFE5394F),
    donorHeader,
  ];
  static const List<Color> organisationPalette = [
    organisationBackground,
    Color(0xFFFFD7B8),
    Color(0xFFFF9A5A),
    Color(0xFFE86A3C),
    organisationHeader,
  ];
  static const List<Color> hospitalPalette = [
    hospitalBackground,
    Color(0xFFF9C7DA),
    Color(0xFFF1709C),
    Color(0xFFD6457F),
    hospitalHeader,
  ];
  static const List<Color> systemAdminPalette = [
    systemAdminBackground,
    Color(0xFFE8C7C7),
    Color(0xFFC86B6B),
    Color(0xFFA94444),
    systemAdminHeader,
  ];
  static const Color ink = Color(0xFF2C2325);
  static const Color muted = Color(0xFF716568);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: const Color(0xFFFFFCFB),
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      useMaterial3: true,
      fontFamilyFallback: const ['Segoe UI', 'Roboto'],
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: ink,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
        headlineMedium: TextStyle(
          color: ink,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        titleLarge: TextStyle(color: ink, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: ink, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: ink, height: 1.35),
        bodyMedium: TextStyle(color: ink, height: 1.35),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFCFB),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF0DEDE)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFEEDDDD)),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: const Color(0xFFFFEDE9),
        indicatorColor: const Color(0xFFFFD6D2),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? primary : muted,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFCFB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE4D7D7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE4D7D7)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: Color(0xFFB99299)),
        ),
      ),
    );
  }

  static ThemeData forRole(Color accent) {
    final base = light;
    final palette = switch (accent) {
      donor => donorPalette,
      organisation => organisationPalette,
      hospital => hospitalPalette,
      systemAdmin => systemAdminPalette,
      _ => [
        Color.alphaBlend(accent.withValues(alpha: .04), background),
        Color.alphaBlend(accent.withValues(alpha: .10), background),
        Color.alphaBlend(accent.withValues(alpha: .35), background),
        accent,
        accent,
      ],
    };
    final lightest = palette[0];
    final lightTone = palette[1];
    final medium = palette[2];
    final deep = palette[3];
    final deepest = palette[4];
    final roleBackground = Color.alphaBlend(
      lightest.withValues(alpha: .48),
      background,
    );
    final navigationBackground = lightest;
    final indicator = lightTone;
    final generatedScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: const Color(0xFFFFFCFB),
    );
    final scheme = generatedScheme.copyWith(
      primary: deep,
      primaryContainer: indicator,
      onPrimary: Colors.white,
      secondary: medium,
      onSecondary: deepest,
      surfaceContainerHighest: lightest,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: roleBackground,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: deepest,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
          color: Colors.white,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: const Color(0xFFFFFCFB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: deep.withValues(alpha: .18)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: navigationBackground,
        indicatorColor: indicator,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? deepest : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? deepest : muted,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: deep,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: deep,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: deep.withValues(alpha: .62)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: deep,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: deep),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: indicator,
        checkmarkColor: deepest,
        side: BorderSide(color: deep.withValues(alpha: .28)),
      ),
    );
  }
}
