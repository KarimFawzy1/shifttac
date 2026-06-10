import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/tiki_attribute.dart';
import '../../domain/services/tiki_attribute_asset_manifest.dart';
import 'tiki_attribute_svg_asset.dart';

/// Renders a club, league, or nation SVG, or position text for board headers.
class TikiAttributeIcon extends StatelessWidget {
  const TikiAttributeIcon({
    super.key,
    required this.attribute,
    required this.manifest,
    this.iconSize,
  });

  final TikiAttribute attribute;
  final TikiAttributeAssetManifest manifest;
  final double? iconSize;

  /// Tall club crests sit in a square slot; boost them to match league/nation weight.
  @visibleForTesting
  static const double clubVisualScale = 1.6;

  @visibleForTesting
  static double visualScaleFor(TikiAttribute attribute) {
    return attribute.type == 'club' ? clubVisualScale : 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final size = iconSize ?? 32.w;

    return Semantics(
      label: TikiAttributeSemantics.labelFor(attribute),
      child: _buildContent(size),
    );
  }

  Widget _buildContent(double size) {
    if (attribute.isPosition) {
      return _PositionLabel(attribute: attribute, maxSize: size);
    }

    final assetPath = manifest.pathForIconKey(attribute.iconKey);
    if (assetPath == null) {
      return _FallbackLabel(attribute: attribute, size: size);
    }

    if (attribute.type == 'club') {
      final renderSize = size * clubVisualScale;

      return SizedBox(
        width: size,
        height: size,
        child: ClipRect(
          child: Center(
            child: TikiAttributeSvgAsset(
              assetPath: assetPath,
              size: renderSize,
              rasterize: true,
              errorBuilder: (context) {
                return _FallbackLabel(attribute: attribute, size: size);
              },
            ),
          ),
        ),
      );
    }

    return TikiAttributeSvgAsset(
      assetPath: assetPath,
      size: size,
      rasterize: true,
      errorBuilder: (context) {
        return _FallbackLabel(attribute: attribute, size: size);
      },
    );
  }
}

class _PositionLabel extends StatelessWidget {
  const _PositionLabel({required this.attribute, required this.maxSize});

  final TikiAttribute attribute;
  final double maxSize;

  static const _labelFontSize = 20.0;

  /// Slot width for the widest code (`FWD`) at [_labelFontSize] so every
  /// position label renders at the same size and stays centered in the slot.
  static const _referenceLabelWidth = 48.0;
  static const _referenceLabelHeight = 24.0;

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppTextStyles.labelBold.copyWith(
      fontSize: _labelFontSize.sp,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: AppColors.onSurface,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : maxSize;
        final height =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : maxSize;

        return SizedBox(
          width: width,
          height: height,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: _referenceLabelWidth.sp,
                height: _referenceLabelHeight.sp,
                child: Center(
                  child: Text(
                    attribute.boardHeaderLabel,
                    style: labelStyle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FallbackLabel extends StatelessWidget {
  const _FallbackLabel({required this.attribute, required this.size});

  final TikiAttribute attribute;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFor(attribute.displayName);

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: AppSpacing.borderRadiusSm,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.all(2.w),
              child: Text(
                initials,
                style: AppTextStyles.labelBold.copyWith(
                  fontSize: 11.sp,
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _initialsFor(String displayName) {
  final parts = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
  if (displayName.length >= 2) {
    return displayName.substring(0, 2).toUpperCase();
  }
  return displayName.toUpperCase();
}

/// Shared accessibility labels for Tiki-Taka attribute headers.
abstract final class TikiAttributeSemantics {
  TikiAttributeSemantics._();

  static String labelFor(TikiAttribute attribute) {
    final typeLabel = switch (attribute.type) {
      'club' => 'Club',
      'nation' => 'Nation',
      'league' => 'League',
      'position' => 'Position',
      _ => 'Attribute',
    };
    return '$typeLabel: ${attribute.displayName}';
  }
}
