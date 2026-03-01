import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "app_colors.dart";

class AppTheme {
  const AppTheme._();

  static const double radius = 16;
  static const double chipRadius = 999;
  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.sage,
      surface: Colors.white,
      onSurface: AppColors.text,
      error: AppColors.error,
      onError: Colors.white,
      outline: AppColors.border,
    );

    final base = GoogleFonts.interTextTheme();
    final textTheme = base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 28,
        height: 32 / 28,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: AppColors.body,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: AppColors.body,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w400,
        color: AppColors.muted,
      ),
      labelMedium: base.labelMedium?.copyWith(
        color: AppColors.muted,
      ),
    );

    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.white,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(0, 52)),
          shape: WidgetStateProperty.all(rounded),
          backgroundColor: WidgetStateProperty.all(AppColors.primary),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return 1;
            }
            return 2;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(0, 52)),
          shape: WidgetStateProperty.all(rounded),
          foregroundColor: WidgetStateProperty.all(AppColors.primary),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.border),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.sageSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.2,
          ),
        ),
        hintStyle: textTheme.bodySmall?.copyWith(color: AppColors.muted),
        labelStyle: textTheme.bodySmall?.copyWith(color: AppColors.muted),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: rounded,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: AppColors.sageSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return textTheme.bodySmall?.copyWith(color: AppColors.muted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary);
          }
          return const IconThemeData(color: AppColors.muted);
        }),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: AppColors.sageSoft,
        selectedColor: AppColors.sage,
        labelStyle: textTheme.bodySmall?.copyWith(color: AppColors.body),
        secondaryLabelStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
    );
  }
}
