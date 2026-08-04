import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // ── Light theme base values ───────────────────────────────────────
  static const _lPrimary = Color(0xFF6366F1);
  static const _lPrimaryDark = Color(0xFF4F46E5);
  static const _lPrimaryLight = Color(0xFFA5B4FC);
  static const _lSecondary = Color(0xFF8B5CF6);
  static const _lSecondaryDark = Color(0xFF7C3AED);
  static const _lBackground = Color(0xFFF5F6FB);
  static const _lSurface = Color(0xFFFFFFFF);
  static const _lOnSurface = Color(0xFF13162B);
  static const _lOnSurfaceVar = Color(0xFF5E6478);
  static const _lOutline = Color(0xFFE2E5F0);
  static const _lError = Color(0xFFEF4444);
  static const _lWarning = Color(0xFFF59E0B);
  static const _lSuccess = Color(0xFF10B981);
  static const _lSurfaceVar = Color(0xFFECEFFB);
  static const _lCardBorder = Color(0xFFE8EAF6);

  static const gradientStart = Color(0xFF6366F1);
  static const gradientMid = Color(0xFF7C6CF6);
  static const gradientEnd = Color(0xFF8B5CF6);
  static const gradientAccent = Color(0xFFA5B4FC);

  // ── Runtime brightness flag ────────────────────────────────────────
  static bool _isDark = false;

  static void setThemeBrightness(Brightness b) =>
      _isDark = b == Brightness.dark;

  // ── Theme-aware getters ────────────────────────────────────────────
  static Color get primary => _isDark ? DarkColors.primary : _lPrimary;
  static Color get primaryDark => _isDark ? DarkColors.primaryDark : _lPrimaryDark;
  static Color get primaryLight => _isDark ? DarkColors.primaryLight : _lPrimaryLight;
  static Color get secondary => _isDark ? DarkColors.secondary : _lSecondary;
  static Color get secondaryDark => _isDark ? DarkColors.secondaryDark : _lSecondaryDark;
  static Color get background => _isDark ? DarkColors.background : _lBackground;
  static Color get surface => _isDark ? DarkColors.surface : _lSurface;
  static Color get onSurface => _isDark ? DarkColors.onSurface : _lOnSurface;
  static Color get onSurfaceVariant => _isDark ? DarkColors.onSurfaceVariant : _lOnSurfaceVar;
  static Color get outline => _isDark ? DarkColors.outline : _lOutline;
  static Color get error => _isDark ? DarkColors.error : _lError;
  static Color get warning => _isDark ? DarkColors.warning : _lWarning;
  static Color get success => _isDark ? DarkColors.success : _lSuccess;
  static Color get surfaceVariant => _isDark ? DarkColors.surfaceVariant : _lSurfaceVar;
  static Color get cardBorder => _isDark ? DarkColors.cardBorder : _lCardBorder;
}

class DarkColors {
  DarkColors._();

  static const primary = Color(0xFFA5B4FC);
  static const primaryDark = Color(0xFF6366F1);
  static const primaryLight = Color(0xFFC7D2FE);
  static const secondary = Color(0xFFA78BFA);
  static const secondaryDark = Color(0xFF8B5CF6);
  static const background = Color(0xFF0B0E1F);
  static const surface = Color(0xFF151935);
  static const onSurface = Color(0xFFE9EBF8);
  static const onSurfaceVariant = Color(0xFF8E93B3);
  static const outline = Color(0xFF232748);
  static const error = Color(0xFFF87171);
  static const warning = Color(0xFFFBBF24);
  static const success = Color(0xFF34D399);
  static const surfaceVariant = Color(0xFF1D2145);
  static const cardBorder = Color(0xFF232748);
}

// ── Theme builders ──────────────────────────────────────────────────

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: AppColors._lPrimary,
      onPrimary: Colors.white,
      primaryContainer: AppColors._lPrimaryLight.withValues(alpha: 0.15),
      onPrimaryContainer: AppColors._lPrimaryDark,
      secondary: AppColors._lSecondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors._lSecondary.withValues(alpha: 0.12),
      onSecondaryContainer: AppColors._lSecondaryDark,
      tertiary: AppColors._lWarning,
      surface: AppColors._lSurface,
      onSurface: AppColors._lOnSurface,
      surfaceContainerHighest: AppColors._lSurfaceVar,
      onSurfaceVariant: AppColors._lOnSurfaceVar,
      outline: AppColors._lOutline,
      error: AppColors._lError,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors._lBackground,
    cardTheme: const CardThemeData(
      elevation: 1,
      shadowColor: Color(0x1413162B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors._lSurface,
      foregroundColor: AppColors._lOnSurface,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: AppColors._lOutline, thickness: 0.5),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors._lSurface,
      indicatorColor: AppColors._lPrimary.withValues(alpha: 0.12),
      elevation: 8,
      shadowColor: const Color(0x1413162B),
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
  return _applyTypography(base);
}

ThemeData buildDarkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: DarkColors.primary,
      onPrimary: DarkColors.background,
      primaryContainer: DarkColors.primaryLight.withValues(alpha: 0.15),
      onPrimaryContainer: DarkColors.primary,
      secondary: DarkColors.secondary,
      onSecondary: DarkColors.background,
      secondaryContainer: DarkColors.secondary.withValues(alpha: 0.12),
      onSecondaryContainer: DarkColors.secondaryDark,
      tertiary: DarkColors.warning,
      surface: DarkColors.surface,
      onSurface: DarkColors.onSurface,
      surfaceContainerHighest: DarkColors.surfaceVariant,
      onSurfaceVariant: DarkColors.onSurfaceVariant,
      outline: DarkColors.outline,
      error: DarkColors.error,
      onError: DarkColors.background,
    ),
    scaffoldBackgroundColor: DarkColors.background,
    cardTheme: const CardThemeData(
      elevation: 0,
      color: DarkColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: DarkColors.cardBorder),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: DarkColors.surface,
      foregroundColor: DarkColors.onSurface,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: DarkColors.outline, thickness: 0.5),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: DarkColors.surface,
      indicatorColor: DarkColors.primary.withValues(alpha: 0.15),
      elevation: 8,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
  return _applyTypography(base);
}

ThemeData _applyTypography(ThemeData theme) {  final body = GoogleFonts.poppinsTextTheme(theme.textTheme);
  return theme.copyWith(
    textTheme: body,
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: theme.brightness == Brightness.dark
            ? DarkColors.onSurface
            : AppColors._lOnSurface,
      ),
    ),
    snackBarTheme: theme.snackBarTheme.copyWith(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

/// Theme-aware palette resolved from the current [BuildContext]. Calling
/// `Theme.of` inside these getters creates a dependency on the Theme so the
/// widgets rebuild whenever the app theme changes at runtime.
extension AppColorsX on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  Color get appSurface => _isDark ? DarkColors.surface : AppColors._lSurface;
  Color get appBackground =>
      _isDark ? DarkColors.background : AppColors._lBackground;
  Color get appOnSurface =>
      _isDark ? DarkColors.onSurface : AppColors._lOnSurface;
  Color get appOnSurfaceVariant =>
      _isDark ? DarkColors.onSurfaceVariant : AppColors._lOnSurfaceVar;
  Color get appSurfaceVariant =>
      _isDark ? DarkColors.surfaceVariant : AppColors._lSurfaceVar;
  Color get appCardBorder =>
      _isDark ? DarkColors.cardBorder : AppColors._lCardBorder;
  Color get appPrimary => _isDark ? DarkColors.primary : AppColors._lPrimary;
  Color get appPrimaryDark =>
      _isDark ? DarkColors.primaryDark : AppColors._lPrimaryDark;
  Color get appPrimaryLight =>
      _isDark ? DarkColors.primaryLight : AppColors._lPrimaryLight;
  Color get appSecondary =>
      _isDark ? DarkColors.secondary : AppColors._lSecondary;
  Color get appSecondaryDark =>
      _isDark ? DarkColors.secondaryDark : AppColors._lSecondaryDark;
  Color get appError => _isDark ? DarkColors.error : AppColors._lError;
  Color get appWarning => _isDark ? DarkColors.warning : AppColors._lWarning;
  Color get appSuccess => _isDark ? DarkColors.success : AppColors._lSuccess;
  Color get appOutline => _isDark ? DarkColors.outline : AppColors._lOutline;
}
