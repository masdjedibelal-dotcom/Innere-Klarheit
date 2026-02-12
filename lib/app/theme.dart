import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const bg = Color(0xFFF6F2EE);
  const surface = Color(0xFFFFFFFF);
  const surfaceAlt = Color(0xFFFDF8F3);
  const primary = Color(0xFFF2B544);
  const onPrimary = Color(0xFF2B2420);
  const onBg = Color(0xFF2B2420);
  const muted = Color(0xFF7A6F67);
  const outline = Color(0x1F2B2420);
  const radiusMd = 16.0;

  final base = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: primary,
      onPrimary: onPrimary,
      background: bg,
      onBackground: onBg,
      surface: surface,
      onSurface: onBg,
      surfaceVariant: surfaceAlt,
      secondary: Color(0xFFE8DFF5),
      onSecondary: onBg,
      outline: outline,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: bg,
    dividerColor: outline,
    textTheme: base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.2,
        fontFamily: 'Playfair Display',
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        fontFamily: 'Playfair Display',
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.3,
        fontFamily: 'Inter',
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.45,
        fontFamily: 'Inter',
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 15,
        height: 1.45,
        fontFamily: 'Inter',
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        fontSize: 14,
        height: 1.45,
        fontFamily: 'Inter',
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        fontFamily: 'Inter',
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFamily: 'Inter',
      ),
      labelSmall: base.textTheme.labelSmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFamily: 'Inter',
      ),
    ).apply(
      bodyColor: onBg,
      displayColor: onBg,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: onBg,
        fontWeight: FontWeight.w700,
        fontSize: 22,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    iconTheme: const IconThemeData(color: muted),
    switchTheme: SwitchThemeData(
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return primary.withOpacity(0.35);
        }
        return outline.withOpacity(0.6);
      }),
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return primary;
        }
        return muted;
      }),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: surfaceAlt,
      selectedColor: primary.withOpacity(0.2),
      disabledColor: surfaceAlt,
      labelStyle: base.textTheme.labelMedium?.copyWith(color: muted),
      side: const BorderSide(color: Colors.transparent),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: bg,
      selectedItemColor: primary,
      unselectedItemColor: muted,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: muted,
      textColor: onBg,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    ),
    dividerTheme: DividerThemeData(
      thickness: 1,
      color: outline,
      space: 24,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: onBg,
        backgroundColor: surfaceAlt,
        side: const BorderSide(color: Colors.transparent),
        shape: const StadiumBorder(),
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: onPrimary,
        backgroundColor: primary,
        shape: const StadiumBorder(),
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: muted,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceAlt,
      hintStyle: TextStyle(color: muted.withOpacity(0.8)),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.transparent),
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: primary),
        borderRadius: BorderRadius.circular(radiusMd),
      ),
    ),
  );
}
