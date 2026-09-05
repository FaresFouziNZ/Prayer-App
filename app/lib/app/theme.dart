import 'package:flutter/material.dart';

import '../domain/tracker/prayer_status.dart';

/// Light and dark themes, following the system by default (SRS FR-UI-02).
///
/// Palette: deep teal-green (primary) for positive/jama'ah states, warm
/// amber-gold (secondary) for late/attention states, a muted blue
/// (tertiary) for on-time-alone, and the standard error red for missed —
/// see [PrayerColors] for the semantic mapping used across status pills,
/// the next-prayer card, and streak/Ramadan highlights.
class AppTheme {
  const AppTheme._();

  static const _primary = Color(0xFF1B6E5B);
  static const _secondary = Color(0xFFA1731F);
  static const _tertiary = Color(0xFF3A6EA5);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.light,
      secondary: _secondary,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFF3E1BE),
      onSecondaryContainer: const Color(0xFF3F2B00),
      tertiary: _tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFD6E4F5),
      onTertiaryContainer: const Color(0xFF0B2D4D),
      surface: const Color(0xFFFBF9F3),
      onSurface: const Color(0xFF1B1D1A),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF5F2E9),
      surfaceContainer: const Color(0xFFEFEBDF),
      surfaceContainerHigh: const Color(0xFFE9E4D6),
      surfaceContainerHighest: const Color(0xFFE3DDCD),
      outline: const Color(0xFF7C8579),
      outlineVariant: const Color(0xFFCBCEC1),
    );
    return _build(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.dark,
      secondary: const Color(0xFFE3B463),
      onSecondary: const Color(0xFF452F00),
      secondaryContainer: const Color(0xFF5F4212),
      onSecondaryContainer: const Color(0xFFFFE8C2),
      tertiary: const Color(0xFF9DC6F2),
      onTertiary: const Color(0xFF0A3357),
      tertiaryContainer: const Color(0xFF1F4C77),
      onTertiaryContainer: const Color(0xFFD7E8FB),
      surface: const Color(0xFF12140F),
      onSurface: const Color(0xFFE3E3DA),
      surfaceContainerLowest: const Color(0xFF0B0D09),
      surfaceContainerLow: const Color(0xFF1A1C16),
      surfaceContainer: const Color(0xFF1E211A),
      surfaceContainerHigh: const Color(0xFF292C24),
      surfaceContainerHighest: const Color(0xFF34372E),
      outline: const Color(0xFF8D9587),
      outlineVariant: const Color(0xFF44483E),
    );
    return _build(scheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final textTheme = base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelSmall: base.textTheme.labelSmall?.copyWith(
        letterSpacing: 0.6,
        fontWeight: FontWeight.w600,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.headlineMedium?.copyWith(color: scheme.onSurface),
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHigh,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.primary : null,
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 32),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}

/// Semantic colors for prayer status, reused for status pills, the
/// next-prayer card's phase tint, and streak/Ramadan highlights — kept as
/// plain [ColorScheme] role lookups (not a separate palette) so light/dark
/// contrast is handled once, in [AppTheme].
///
/// jama'ah = primary (best outcome), on-time-alone = tertiary (calm/info),
/// late = secondary (warm caution), missed = error, not-logged = outline.
class PrayerColors {
  const PrayerColors._();

  static Color of(ColorScheme scheme, PrayerStatus? status) => switch (status) {
        null => scheme.outline,
        PrayerStatus.jamaah => scheme.primary,
        PrayerStatus.onTimeAlone => scheme.tertiary,
        PrayerStatus.late => scheme.secondary,
        PrayerStatus.missed => scheme.error,
      };

  /// Soft background tint for the status pill/icon container.
  static Color containerOf(ColorScheme scheme, PrayerStatus? status) => switch (status) {
        null => scheme.surfaceContainerHighest,
        PrayerStatus.jamaah => scheme.primaryContainer,
        PrayerStatus.onTimeAlone => scheme.tertiaryContainer,
        PrayerStatus.late => scheme.secondaryContainer,
        PrayerStatus.missed => scheme.errorContainer,
      };

  /// Foreground color for text/icons drawn on [containerOf].
  static Color onContainerOf(ColorScheme scheme, PrayerStatus? status) => switch (status) {
        null => scheme.onSurfaceVariant,
        PrayerStatus.jamaah => scheme.onPrimaryContainer,
        PrayerStatus.onTimeAlone => scheme.onTertiaryContainer,
        PrayerStatus.late => scheme.onSecondaryContainer,
        PrayerStatus.missed => scheme.onErrorContainer,
      };

  static IconData iconOf(PrayerStatus? status) => switch (status) {
        null => Icons.radio_button_unchecked,
        PrayerStatus.jamaah => Icons.groups_rounded,
        PrayerStatus.onTimeAlone => Icons.check_circle_rounded,
        PrayerStatus.late => Icons.watch_later_rounded,
        PrayerStatus.missed => Icons.cancel_rounded,
      };
}
