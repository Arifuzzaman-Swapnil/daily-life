// Builds Material ThemeData for light and dark from the generated tokens.
// Components should prefer `context.dl.<token>` over ColorScheme roles so both themes stay exact.
import 'package:flutter/material.dart';

import 'dl_tokens.dart';

class DLTheme {
  static ThemeData light() => _build(DLColors.light, Brightness.light);
  static ThemeData dark() => _build(DLColors.dark, Brightness.dark);

  static ThemeData _build(DLColors c, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.actionPrimary,
      onPrimary: c.onActionPrimary,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.danger,
      onError: c.onDanger,
      surface: c.surface,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.surfaceSunken,
      outline: c.borderStrong,
      outlineVariant: c.divider,
      scrim: c.scrim,
    );
    final text = TextTheme(
      displaySmall: DLText.textDisplay,
      headlineMedium: DLText.textH1,
      headlineSmall: DLText.textH2,
      titleMedium: DLText.textH3,
      bodyLarge: DLText.textBodyLg,
      bodyMedium: DLText.textBody,
      bodySmall: DLText.textBodySm,
      labelLarge: DLText.textButton,
      labelMedium: DLText.textLabel,
      labelSmall: DLText.textCaption,
    ).apply(bodyColor: c.textPrimary, displayColor: c.textPrimary);
    const r12 = BorderRadius.all(Radius.circular(DLRadius.md));
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      fontFamily: DLText.family,
      textTheme: text,
      extensions: [c],
      dividerColor: c.divider,
      appBarTheme: AppBarTheme(backgroundColor: c.background, foregroundColor: c.textPrimary, elevation: 0, scrolledUnderElevation: 0, toolbarHeight: 64, titleTextStyle: DLText.textH2.copyWith(color: c.textPrimary)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: DLText.textBodyLg.copyWith(color: c.textSecondary),
        border: OutlineInputBorder(borderRadius: r12, borderSide: BorderSide(color: c.borderStrong)),
        enabledBorder: OutlineInputBorder(borderRadius: r12, borderSide: BorderSide(color: c.borderStrong)),
        focusedBorder: OutlineInputBorder(borderRadius: r12, borderSide: BorderSide(color: c.accent, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: r12, borderSide: BorderSide(color: c.danger, width: 2)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: r12, borderSide: BorderSide(color: c.danger, width: 2)),
        errorStyle: DLText.textBodySm.copyWith(color: c.dangerText),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: c.actionPrimary, foregroundColor: c.onActionPrimary, minimumSize: const Size.fromHeight(DLSize.controlLg), shape: const RoundedRectangleBorder(borderRadius: r12), textStyle: DLText.textButton)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: c.accentText, backgroundColor: c.surface, side: BorderSide(color: c.borderStrong), minimumSize: const Size.fromHeight(DLSize.controlLg), shape: const RoundedRectangleBorder(borderRadius: r12), textStyle: DLText.textButton)),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.surfaceRaised, showDragHandle: true, dragHandleColor: c.borderStrong, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(DLRadius.xl)))),
      dialogTheme: DialogThemeData(backgroundColor: c.surfaceRaised, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(DLRadius.xl)))),
      snackBarTheme: SnackBarThemeData(backgroundColor: c.textPrimary, contentTextStyle: DLText.textBody.copyWith(color: c.background), behavior: SnackBarBehavior.floating, shape: const RoundedRectangleBorder(borderRadius: r12)),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.actionPrimary : c.borderStrong),
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) && b == Brightness.dark ? const Color(0xFF0B1120) : Colors.white),
      ),
    );
  }
}
