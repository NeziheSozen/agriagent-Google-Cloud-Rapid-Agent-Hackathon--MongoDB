import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium Material 3 dark theme for AgriAgent.
///
/// Uses an earthy color palette — farm greens, harvest golds, and deep darks —
/// with Outfit for display/headings and Inter for body/labels.
class AgriAgentTheme {
  AgriAgentTheme._();

  // ── Color Palette ──────────────────────────────────────────────────────
  static const Color harvestGold = Color(0xFFFFB300);
  static const Color deepDark = Color(0xFF1A1D23);
  static const Color cardSurface = Color(0xFF242830);
  static const Color cardSurfaceLight = Color(0xFF2A2F38);
  static const Color errorRed = Color(0xFFEF5350);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color successGreen = Color(0xFF66BB6A);
  static const Color infoBlue = Color(0xFF42A5F5);

  // ── Light Theme Palette ────────────────────────────────────────────────
  static const Color sand = Color(0xFFF7F1E5); // Lighter sand
  static const Color skyBlue = Color(0xFF7FC7CC);
  static const Color deepSea = Color(0xFF092F33);
  static const Color mossGreen = Color(0xFF4B5B34);
  static const Color terracotta = Color(0xFFAF5031);
  static const Color cherryBlossom = Color(0xFFFDABA5);
  static const Color redWine = Color(0xFF980204);
  static const Color sunshine = Color(0xFFEA8913);

  // Severity colors
  static const Color severityLow = Color(0xFF66BB6A);
  static const Color severityMedium = Color(0xFFFFCA28);
  static const Color severityHigh = Color(0xFFFF9800);
  static const Color severityCritical = Color(0xFFEF5350);

  // Crop-type palette
  static const Color cropCereal = Color(0xFFFFB74D);
  static const Color cropLegume = Color(0xFF81C784);
  static const Color cropOilseed = Color(0xFFFFF176);
  static const Color cropVegetable = Color(0xFFE57373);
  static const Color cropIndustrial = Color(0xFFCE93D8);

  // ── Gradient presets ───────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF388E3C), mossGreen, Color(0xFF66BB6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF57F17), Color(0xFFFFB300), Color(0xFFFFD54F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF242830), Color(0xFF1A1D23)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x15FFFFFF), Color(0x05FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Theme Data ─────────────────────────────────────────────────────────
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: mossGreen,
      brightness: Brightness.light,
      primary: mossGreen,
      secondary: sunshine,
      surface: sand,
      error: redWine,
      onSurface: deepSea,
    );

    final textTheme = _buildTextTheme().apply(
      bodyColor: deepSea,
      displayColor: deepSea,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: sand,
      textTheme: textTheme,
      fontFamily: GoogleFonts.inter().fontFamily,
      
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: sand,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: deepSea,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: deepSea),
      ),
      
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: deepSea.withOpacity(0.06)),
        ),
        margin: const EdgeInsets.all(8),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mossGreen,
          foregroundColor: sand,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: mossGreen,
        unselectedItemColor: deepSea.withOpacity(0.4),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        selectedIconTheme: const IconThemeData(color: mossGreen),
        unselectedIconTheme: IconThemeData(color: deepSea.withOpacity(0.4)),
        indicatorColor: mossGreen.withOpacity(0.15),
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: mossGreen,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: deepSea.withOpacity(0.4),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: mossGreen,
      brightness: Brightness.dark,
      secondary: harvestGold,
      surface: deepDark,
      error: errorRed,
    );

    final textTheme = _buildTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: deepDark,
      textTheme: textTheme,
      fontFamily: GoogleFonts.inter().fontFamily,

      // ── AppBar ─────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: deepDark,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),

      // ── Card ───────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        margin: const EdgeInsets.all(8),
      ),

      // ── Elevated Button ────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mossGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // ── Outlined Button ────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: mossGreen,
          side: const BorderSide(color: mossGreen, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // ── Text Button ───────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: mossGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // ── Chip ──────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: cardSurface,
        selectedColor: mossGreen.withOpacity(0.2),
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        labelStyle: textTheme.labelSmall,
      ),

      // ── Bottom Nav ────────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardSurface,
        selectedItemColor: mossGreen,
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Navigation Rail ───────────────────────────────────────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cardSurface,
        selectedIconTheme: const IconThemeData(color: mossGreen),
        unselectedIconTheme: const IconThemeData(color: Colors.white38),
        indicatorColor: mossGreen.withOpacity(0.15),
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: mossGreen,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          color: Colors.white38,
        ),
      ),

      // ── Navigation Drawer ─────────────────────────────────────────────
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: cardSurface,
        indicatorColor: mossGreen.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelLarge?.copyWith(
              color: mossGreen,
              fontWeight: FontWeight.w600,
            );
          }
          return textTheme.labelLarge?.copyWith(color: Colors.white60);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: mossGreen);
          }
          return const IconThemeData(color: Colors.white38);
        }),
      ),

      // ── Dropdown ──────────────────────────────────────────────────────
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: mossGreen, width: 2),
          ),
        ),
      ),

      // ── Input Decoration ──────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: mossGreen, width: 2),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: Colors.white54),
        hintStyle: textTheme.bodyMedium?.copyWith(color: Colors.white30),
      ),

      // ── Tab Bar ───────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: mossGreen,
        unselectedLabelColor: Colors.white38,
        indicatorColor: mossGreen,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: textTheme.labelLarge,
        dividerColor: Colors.transparent,
      ),

      // ── Divider ───────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.06),
        thickness: 1,
        space: 1,
      ),

      // ── Tooltip ───────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cardSurfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
      ),

      // ── Snack Bar ─────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardSurfaceLight,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Typography ───────────────────────────────────────────────────────
  static TextTheme _buildTextTheme() {
    final outfitTheme = GoogleFonts.outfitTextTheme();
    final interTheme = GoogleFonts.interTextTheme();

    return TextTheme(
      // Display – Outfit
      displayLarge: outfitTheme.displayLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
      ),
      displayMedium: outfitTheme.displayMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      displaySmall: outfitTheme.displaySmall?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),

      // Headline – Outfit
      headlineLarge: outfitTheme.headlineLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: outfitTheme.headlineMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: outfitTheme.headlineSmall?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),

      // Title – Outfit
      titleLarge: outfitTheme.titleLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: outfitTheme.titleMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: outfitTheme.titleSmall?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),

      // Body – Inter
      bodyLarge: interTheme.bodyLarge?.copyWith(
        color: Colors.white.withOpacity(0.87),
        height: 1.6,
      ),
      bodyMedium: interTheme.bodyMedium?.copyWith(
        color: Colors.white.withOpacity(0.75),
        height: 1.5,
      ),
      bodySmall: interTheme.bodySmall?.copyWith(
        color: Colors.white.withOpacity(0.6),
        height: 1.5,
      ),

      // Label – Inter
      labelLarge: interTheme.labelLarge?.copyWith(
        color: Colors.white.withOpacity(0.87),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      labelMedium: interTheme.labelMedium?.copyWith(
        color: Colors.white.withOpacity(0.75),
        fontWeight: FontWeight.w500,
      ),
      labelSmall: interTheme.labelSmall?.copyWith(
        color: Colors.white.withOpacity(0.6),
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  /// Returns the crop-type color for timeline rendering.
  static Color cropTypeColor(String cropName) {
    final lower = cropName.toLowerCase();
    if (['wheat', 'barley', 'corn', 'maize', 'rice', 'oat', 'rye']
        .any((c) => lower.contains(c))) {
      return cropCereal;
    }
    if (['chickpea', 'lentil', 'bean', 'pea', 'soybean']
        .any((c) => lower.contains(c))) {
      return cropLegume;
    }
    if (['sunflower', 'canola', 'rapeseed', 'sesame', 'olive']
        .any((c) => lower.contains(c))) {
      return cropOilseed;
    }
    if (['tomato', 'pepper', 'cucumber', 'lettuce', 'onion', 'potato']
        .any((c) => lower.contains(c))) {
      return cropVegetable;
    }
    if (['cotton', 'sugar beet', 'tobacco', 'hemp']
        .any((c) => lower.contains(c))) {
      return cropIndustrial;
    }
    return mossGreen;
  }

  /// Returns a severity color.
  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return severityLow;
      case 'medium':
        return severityMedium;
      case 'high':
        return severityHigh;
      case 'critical':
        return severityCritical;
      default:
        return Colors.grey;
    }
  }

  /// Returns a trend color for price movements.
  static Color trendColor(String trend) {
    switch (trend.toLowerCase()) {
      case 'up':
      case 'rising':
        return successGreen;
      case 'stable':
      case 'flat':
        return harvestGold;
      case 'down':
      case 'falling':
        return errorRed;
      default:
        return Colors.grey;
    }
  }

  /// Returns a trend icon for price movements.
  static IconData trendIcon(String trend) {
    switch (trend.toLowerCase()) {
      case 'up':
      case 'rising':
        return Icons.trending_up_rounded;
      case 'stable':
      case 'flat':
        return Icons.trending_flat_rounded;
      case 'down':
      case 'falling':
        return Icons.trending_down_rounded;
      default:
        return Icons.remove_rounded;
    }
  }
}
