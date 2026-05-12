import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.onPrimaryContainer,
          inversePrimary: AppColors.inversePrimary,
          secondary: AppColors.secondary,
          onSecondary: AppColors.onSecondary,
          secondaryContainer: AppColors.secondaryContainer,
          onSecondaryContainer: AppColors.onSecondaryContainer,
          tertiary: AppColors.tertiary,
          onTertiary: AppColors.onTertiary,
          tertiaryContainer: AppColors.tertiaryContainer,
          onTertiaryContainer: AppColors.onTertiaryContainer,
          error: AppColors.error,
          onError: AppColors.onError,
          errorContainer: AppColors.errorContainer,
          onErrorContainer: AppColors.onErrorContainer,
          surface: AppColors.surface,
          onSurface: AppColors.onSurface,
          onSurfaceVariant: AppColors.onSurfaceVariant,
          outline: AppColors.outline,
          outlineVariant: AppColors.outlineVariant,
          surfaceTint: AppColors.surfaceTint,
          surfaceDim: AppColors.surfaceDim,
          surfaceBright: AppColors.surfaceBright,
          inverseSurface: AppColors.inverseSurface,
          onInverseSurface: AppColors.inverseOnSurface,
          surfaceContainerLowest: AppColors.surfaceContainerLowest,
          surfaceContainerLow: AppColors.surfaceContainerLow,
          surfaceContainer: AppColors.surfaceContainer,
          surfaceContainerHigh: AppColors.surfaceContainerHigh,
          surfaceContainerHighest: AppColors.surfaceContainerHighest,
          primaryFixed: AppColors.primaryFixed,
          primaryFixedDim: AppColors.primaryFixedDim,
          onPrimaryFixed: AppColors.onPrimaryFixed,
          onPrimaryFixedVariant: AppColors.onPrimaryFixedVariant,
          secondaryFixed: AppColors.secondaryFixed,
          secondaryFixedDim: AppColors.secondaryFixedDim,
          onSecondaryFixed: AppColors.onSecondaryFixed,
          onSecondaryFixedVariant: AppColors.onSecondaryFixedVariant,
          tertiaryFixed: AppColors.tertiaryFixed,
          tertiaryFixedDim: AppColors.tertiaryFixedDim,
          onTertiaryFixed: AppColors.onTertiaryFixed,
          onTertiaryFixedVariant: AppColors.onTertiaryFixedVariant,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.warmIvory,
      textTheme: AppTextStyles.materialTextTheme,
      dividerColor: AppColors.outlineVariant,
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusLg),
      ),
    );
  }
}
