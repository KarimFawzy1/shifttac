import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/tiki_attribute.dart';
import '../../domain/services/tiki_attribute_asset_manifest.dart';
import 'tiki_attribute_icon.dart';

/// Whether the header sits on the left (row) or top (column) of the board.
enum TikiHeaderAxis { row, column }

/// Single board header cell for a club, league, nation, or position attribute.
class TikiAttributeHeader extends StatelessWidget {
  const TikiAttributeHeader({
    super.key,
    required this.attribute,
    required this.manifest,
    required this.axis,
    this.iconSize,
    this.expand = false,
  });

  final TikiAttribute attribute;
  final TikiAttributeAssetManifest manifest;
  final TikiHeaderAxis axis;
  final double? iconSize;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final resolvedIconSize = iconSize ?? (axis == TikiHeaderAxis.column ? 30.w : 28.w);

    final header = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderRadiusSm,
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 4.w,
          vertical: 4.h,
        ),
        child: Center(
          child: TikiAttributeIcon(
            attribute: attribute,
            manifest: manifest,
            iconSize: resolvedIconSize,
          ),
        ),
      ),
    );

    return Semantics(
      label: TikiAttributeSemantics.labelFor(attribute),
      container: true,
      child: ExcludeSemantics(
        child: expand
            ? SizedBox(width: double.infinity, height: double.infinity, child: header)
            : header,
      ),
    );
  }
}
