import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color _brandBlue = Color(0xFF2563EB);
  static const Color _brandTeal = Color(0xFF18C7D8);
  static const Color _brandPurple = Color(0xFF3438F2);
  static const Color _brandPink = Color(0xFFEC4899);
  static const Color _brandOrange = Color(0xFFF97316);
  static const Color _brandGreen = Color(0xFF10B981);
  static const Color _brandRed = Color(0xFFEF4444);
  static const Color _brandIndigo = Color(0xFF3438F2);
  static const Color _brandCyan = Color(0xFF18C7D8);

  // Background Colors
  static const Color _lightBackground = Color(0xFFF4F7FB);
  static const Color _darkBackground = Color(0xFF0E1624);
  static const Color _lightBackgroundWarm = Color(0xFFFDF8F2);
  static const Color _darkBackgroundWarm = Color(0xFF1A1612);
  static const Color _lightBackgroundCool = Color(0xFFF0F4F8);
  static const Color _darkBackgroundCool = Color(0xFF0F172A);

  // ==================== ORIGINAL BLUE THEME ====================
  static final ColorScheme _lightScheme =
      ColorScheme.fromSeed(
        seedColor: _brandBlue,
        brightness: Brightness.light,
        primary: _brandBlue,
        secondary: _brandTeal,
        surface: const Color(0xFFFFFFFF),
        error: const Color(0xFFDC2626),
      ).copyWith(
        surfaceContainer: const Color(0xFFF8FAFD),
        surfaceContainerHigh: const Color(0xFFF1F5FB),
        outline: const Color(0xFFD7DFEA),
        outlineVariant: const Color(0xFFE6ECF4),
      );

  static final ColorScheme _darkScheme =
      ColorScheme.fromSeed(
        seedColor: _brandBlue,
        brightness: Brightness.dark,
        primary: const Color(0xFF7CA8FF),
        secondary: const Color(0xFF5DE3F0),
        surface: const Color(0xFF152235),
        error: const Color(0xFFFF8D8D),
      ).copyWith(
        surfaceContainer: const Color(0xFF1A2B44),
        surfaceContainerHigh: const Color(0xFF213754),
        outline: const Color(0xFF3D4D66),
        outlineVariant: const Color(0xFF324159),
      );

  // ==================== PURPLE THEME ====================
  static final ColorScheme _lightPurpleScheme =
      ColorScheme.fromSeed(
        seedColor: _brandPurple,
        brightness: Brightness.light,
        primary: _brandPurple,
        secondary: _brandCyan,
        surface: const Color(0xFFFFFFFF),
        error: const Color(0xFFDC2626),
      ).copyWith(
        surfaceContainer: const Color(0xFFF9F6FF),
        surfaceContainerHigh: const Color(0xFFF3EEFF),
        outline: const Color(0xFFD9D0E8),
        outlineVariant: const Color(0xFFE8E0F5),
      );

  static final ColorScheme _darkPurpleScheme =
      ColorScheme.fromSeed(
        seedColor: _brandPurple,
        brightness: Brightness.dark,
        primary: const Color(0xFF7C8CFF),
        secondary: const Color(0xFF5DE3F0),
        surface: const Color(0xFF1A1528),
        error: const Color(0xFFFF8D8D),
      ).copyWith(
        surfaceContainer: const Color(0xFF221D33),
        surfaceContainerHigh: const Color(0xFF2D2540),
        outline: const Color(0xFF4A4263),
        outlineVariant: const Color(0xFF3D3555),
      );

  // ==================== ORANGE THEME ====================
  static final ColorScheme _lightOrangeScheme =
      ColorScheme.fromSeed(
        seedColor: _brandOrange,
        brightness: Brightness.light,
        primary: _brandOrange,
        secondary: _brandRed,
        surface: const Color(0xFFFFFFFF),
        error: const Color(0xFFDC2626),
      ).copyWith(
        surfaceContainer: const Color(0xFFFFF8F2),
        surfaceContainerHigh: const Color(0xFFFFF1E6),
        outline: const Color(0xFFE8D5C4),
        outlineVariant: const Color(0xFFF2E6D9),
      );

  static final ColorScheme _darkOrangeScheme =
      ColorScheme.fromSeed(
        seedColor: _brandOrange,
        brightness: Brightness.dark,
        primary: const Color(0xFFFDA46D),
        secondary: const Color(0xFFFF8A8A),
        surface: const Color(0xFF281A12),
        error: const Color(0xFFFF8D8D),
      ).copyWith(
        surfaceContainer: const Color(0xFF33221A),
        surfaceContainerHigh: const Color(0xFF402E24),
        outline: const Color(0xFF66554A),
        outlineVariant: const Color(0xFF4D3E35),
      );

  // ==================== GREEN THEME ====================
  static final ColorScheme _lightGreenScheme =
      ColorScheme.fromSeed(
        seedColor: _brandGreen,
        brightness: Brightness.light,
        primary: _brandGreen,
        secondary: _brandTeal,
        surface: const Color(0xFFFFFFFF),
        error: const Color(0xFFDC2626),
      ).copyWith(
        surfaceContainer: const Color(0xFFF2FFF5),
        surfaceContainerHigh: const Color(0xFFE6F9EC),
        outline: const Color(0xFFC8E0D0),
        outlineVariant: const Color(0xFFDCEFE2),
      );

  static final ColorScheme _darkGreenScheme =
      ColorScheme.fromSeed(
        seedColor: _brandGreen,
        brightness: Brightness.dark,
        primary: const Color(0xFF5EEAA0),
        secondary: const Color(0xFF39D0BE),
        surface: const Color(0xFF122818),
        error: const Color(0xFFFF8D8D),
      ).copyWith(
        surfaceContainer: const Color(0xFF1A3322),
        surfaceContainerHigh: const Color(0xFF22422E),
        outline: const Color(0xFF3D664E),
        outlineVariant: const Color(0xFF2D4D3B),
      );

  // ==================== INDIGO THEME ====================
  static final ColorScheme _lightIndigoScheme =
      ColorScheme.fromSeed(
        seedColor: _brandIndigo,
        brightness: Brightness.light,
        primary: _brandIndigo,
        secondary: _brandTeal,
        surface: const Color(0xFFFFFFFF),
        error: const Color(0xFFDC2626),
      ).copyWith(
        surfaceContainer: const Color(0xFFF5F3FF),
        surfaceContainerHigh: const Color(0xFFEDE9FE),
        outline: const Color(0xFFD1CAE6),
        outlineVariant: const Color(0xFFE2DCF5),
      );

  static final ColorScheme _darkIndigoScheme =
      ColorScheme.fromSeed(
        seedColor: _brandIndigo,
        brightness: Brightness.dark,
        primary: const Color(0xFF7C8CFF),
        secondary: const Color(0xFF5DE3F0),
        surface: const Color(0xFF141328),
        error: const Color(0xFFFF8D8D),
      ).copyWith(
        surfaceContainer: const Color(0xFF1D1B35),
        surfaceContainerHigh: const Color(0xFF282544),
        outline: const Color(0xFF4A4766),
        outlineVariant: const Color(0xFF3A3855),
      );

  // ==================== ROSE/RED THEME ====================
  static final ColorScheme _lightRoseScheme =
      ColorScheme.fromSeed(
        seedColor: _brandPink,
        brightness: Brightness.light,
        primary: _brandPink,
        secondary: _brandRed,
        surface: const Color(0xFFFFFFFF),
        error: const Color(0xFFDC2626),
      ).copyWith(
        surfaceContainer: const Color(0xFFFFF2F8),
        surfaceContainerHigh: const Color(0xFFFFEAF2),
        outline: const Color(0xFFE8CDDA),
        outlineVariant: const Color(0xFFF2E0E8),
      );

  static final ColorScheme _darkRoseScheme =
      ColorScheme.fromSeed(
        seedColor: _brandPink,
        brightness: Brightness.dark,
        primary: const Color(0xFFF98BC6),
        secondary: const Color(0xFFFF8A8A),
        surface: const Color(0xFF281220),
        error: const Color(0xFFFF8D8D),
      ).copyWith(
        surfaceContainer: const Color(0xFF331A2A),
        surfaceContainerHigh: const Color(0xFF402436),
        outline: const Color(0xFF664A59),
        outlineVariant: const Color(0xFF4D3745),
      );

  // ==================== CYAN THEME ====================
  static final ColorScheme _lightCyanScheme =
      ColorScheme.fromSeed(
        seedColor: _brandCyan,
        brightness: Brightness.light,
        primary: _brandCyan,
        secondary: _brandBlue,
        surface: const Color(0xFFFFFFFF),
        error: const Color(0xFFDC2626),
      ).copyWith(
        surfaceContainer: const Color(0xFFF0FDFF),
        surfaceContainerHigh: const Color(0xFFE3F9FC),
        outline: const Color(0xFFC5E3E8),
        outlineVariant: const Color(0xFFD9EFF2),
      );

  static final ColorScheme _darkCyanScheme =
      ColorScheme.fromSeed(
        seedColor: _brandCyan,
        brightness: Brightness.dark,
        primary: const Color(0xFF5DE3F0),
        secondary: const Color(0xFF7CA8FF),
        surface: const Color(0xFF102228),
        error: const Color(0xFFFF8D8D),
      ).copyWith(
        surfaceContainer: const Color(0xFF182E35),
        surfaceContainerHigh: const Color(0xFF1F3C45),
        outline: const Color(0xFF3D626D),
        outlineVariant: const Color(0xFF2D4B55),
      );

  // ==================== BLUE (Original) ====================
  static final ThemeData lightTheme = _buildTheme(
    scheme: _lightScheme,
    scaffoldBackground: _lightBackground,
  );

  static final ThemeData darkTheme = _buildTheme(
    scheme: _darkScheme,
    scaffoldBackground: _darkBackground,
  );

  // ==================== PURPLE ====================
  static final ThemeData lightPurpleTheme = _buildTheme(
    scheme: _lightPurpleScheme,
    scaffoldBackground: _lightBackgroundCool,
  );

  static final ThemeData darkPurpleTheme = _buildTheme(
    scheme: _darkPurpleScheme,
    scaffoldBackground: _darkBackgroundCool,
  );

  // ==================== ORANGE ====================
  static final ThemeData lightOrangeTheme = _buildTheme(
    scheme: _lightOrangeScheme,
    scaffoldBackground: _lightBackgroundWarm,
  );

  static final ThemeData darkOrangeTheme = _buildTheme(
    scheme: _darkOrangeScheme,
    scaffoldBackground: _darkBackgroundWarm,
  );

  // ==================== GREEN ====================
  static final ThemeData lightGreenTheme = _buildTheme(
    scheme: _lightGreenScheme,
    scaffoldBackground: _lightBackgroundCool,
  );

  static final ThemeData darkGreenTheme = _buildTheme(
    scheme: _darkGreenScheme,
    scaffoldBackground: _darkBackgroundCool,
  );

  // ==================== INDIGO ====================
  static final ThemeData lightIndigoTheme = _buildTheme(
    scheme: _lightIndigoScheme,
    scaffoldBackground: _lightBackgroundCool,
  );

  static final ThemeData darkIndigoTheme = _buildTheme(
    scheme: _darkIndigoScheme,
    scaffoldBackground: _darkBackgroundCool,
  );

  // ==================== ROSE ====================
  static final ThemeData lightRoseTheme = _buildTheme(
    scheme: _lightRoseScheme,
    scaffoldBackground: _lightBackgroundWarm,
  );

  static final ThemeData darkRoseTheme = _buildTheme(
    scheme: _darkRoseScheme,
    scaffoldBackground: _darkBackgroundWarm,
  );

  // ==================== CYAN ====================
  static final ThemeData lightCyanTheme = _buildTheme(
    scheme: _lightCyanScheme,
    scaffoldBackground: _lightBackgroundCool,
  );

  static final ThemeData darkCyanTheme = _buildTheme(
    scheme: _darkCyanScheme,
    scaffoldBackground: _darkBackgroundCool,
  );

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color scaffoldBackground,
  }) {
    final bool isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: scaffoldBackground,
      canvasColor: scheme.surface,
      cardColor: scheme.surfaceContainer,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 70,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        titleSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.5,
          color: scheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: scheme.onSurfaceVariant,
        ),
        bodySmall: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
        ),
        labelMedium: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        labelSmall: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isDark ? 1 : 2,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
        errorStyle: TextStyle(color: scheme.error, fontSize: 12),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: isDark ? 2 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 0,
      ),
      iconTheme: IconThemeData(color: scheme.primary, size: 24),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        elevation: isDark ? 4 : 2,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(color: scheme.onSurface),
        secondaryLabelStyle: TextStyle(color: scheme.onPrimaryContainer),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(color: scheme.onSurfaceVariant);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(color: scheme.primary),
        unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

// Theme Manager Class
class MyTheme {
  // Theme types
  static const String themeBlue = 'blue';
  static const String themePurple = 'purple';
  static const String themeOrange = 'orange';
  static const String themeGreen = 'green';
  static const String themeIndigo = 'indigo';
  static const String themeRose = 'rose';
  static const String themeCyan = 'cyan';

  // Get light theme by name
  static ThemeData getLightTheme(String themeName) {
    switch (themeName) {
      case themePurple:
        return AppTheme.lightPurpleTheme;
      case themeOrange:
        return AppTheme.lightOrangeTheme;
      case themeGreen:
        return AppTheme.lightGreenTheme;
      case themeIndigo:
        return AppTheme.lightIndigoTheme;
      case themeRose:
        return AppTheme.lightRoseTheme;
      case themeCyan:
        return AppTheme.lightCyanTheme;
      case themeBlue:
      default:
        return AppTheme.lightTheme;
    }
  }

  // Get dark theme by name
  static ThemeData getDarkTheme(String themeName) {
    switch (themeName) {
      case themePurple:
        return AppTheme.darkPurpleTheme;
      case themeOrange:
        return AppTheme.darkOrangeTheme;
      case themeGreen:
        return AppTheme.darkGreenTheme;
      case themeIndigo:
        return AppTheme.darkIndigoTheme;
      case themeRose:
        return AppTheme.darkRoseTheme;
      case themeCyan:
        return AppTheme.darkCyanTheme;
      case themeBlue:
      default:
        return AppTheme.darkTheme;
    }
  }

  // Get all available themes for settings page
  static List<ThemeOption> getAvailableThemes() {
    return [
      ThemeOption(name: 'Blue', themeKey: themeBlue, color: Colors.blue),
      ThemeOption(name: 'Purple', themeKey: themePurple, color: Colors.purple),
      ThemeOption(name: 'Orange', themeKey: themeOrange, color: Colors.orange),
      ThemeOption(name: 'Green', themeKey: themeGreen, color: Colors.green),
      ThemeOption(name: 'Indigo', themeKey: themeIndigo, color: Colors.indigo),
      ThemeOption(name: 'Rose', themeKey: themeRose, color: Colors.pink),
      ThemeOption(name: 'Cyan', themeKey: themeCyan, color: Colors.cyan),
    ];
  }

  // Legacy support - defaults to blue theme
  static ThemeData get lightTheme => AppTheme.lightTheme;
  static ThemeData get darkTheme => AppTheme.darkTheme;
}

// Theme option model
class ThemeOption {
  final String name;
  final String themeKey;
  final Color color;

  const ThemeOption({
    required this.name,
    required this.themeKey,
    required this.color,
  });
}
