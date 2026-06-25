import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour palette
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  static const Color background  = Color(0xFF0A0C10);
  static const Color surface     = Color(0xFF13171E);
  static const Color card        = Color(0xFF181D26);
  static const Color accent      = Color(0xFFFF6B35);
  static const Color accentDim   = Color(0x22FF6B35); // ~13 % opacity
  static const Color textPrimary = Color(0xFFF0F2F5);
  static const Color textMuted   = Color(0xFF6B7A90);
  static const Color border      = Color(0xFF232A36);
  static const Color error       = Color(0xFFFF4757);
  static const Color success     = Color(0xFF4ECCA3);

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF6B35), Color(0xFFFF3B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Quick helper — a gradient [BoxDecoration] with rounded corners.
  static BoxDecoration gradientBox({double radius = 12}) => BoxDecoration(
        gradient: accentGradient,
        borderRadius: BorderRadius.circular(radius),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme
// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.accent,
        onPrimary: Colors.white,
        secondary: Color(0xFFFF8B5E),
        onSecondary: Colors.white,
        error: AppColors.error,
        onError: Colors.white,
        onSurface: AppColors.textPrimary,
        outline: AppColors.border,
        surfaceTint: Colors.transparent,
      ),

      // ── AppBar ─────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actionsIconTheme: IconThemeData(color: AppColors.textPrimary),
      ),

      // ── NavigationBar (Material 3) ─────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: AppColors.accentDim,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.accent, size: 22);
          }
          return const IconThemeData(color: AppColors.textMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          );
        }),
      ),

      // ── FAB ────────────────────────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: CircleBorder(),
      ),

      // ── Input fields ───────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
      ),

      // ── Card ───────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Misc ───────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
          color: AppColors.border, thickness: 1, space: 1),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle:
            const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        actionTextColor: AppColors.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        contentTextStyle:
            const TextStyle(color: AppColors.textMuted, fontSize: 14),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        textStyle:
            const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      ),

      // ── Text ───────────────────────────────────────────────────────────────
      textTheme: const TextTheme(
        headlineLarge:  TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 30),
        headlineMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 24),
        headlineSmall:  TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 20),
        titleLarge:     TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
        titleMedium:    TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        titleSmall:     TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
        bodyLarge:      TextStyle(color: AppColors.textPrimary, fontSize: 16),
        bodyMedium:     TextStyle(color: AppColors.textMuted,   fontSize: 14),
        bodySmall:      TextStyle(color: AppColors.textMuted,   fontSize: 12),
        labelLarge:     TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
        labelMedium:    TextStyle(color: AppColors.textMuted,   fontSize: 12),
        labelSmall:     TextStyle(color: AppColors.textMuted,   fontSize: 11),
      ),
    );
  }
}
