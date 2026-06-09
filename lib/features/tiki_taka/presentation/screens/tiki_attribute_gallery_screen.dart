import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/image_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../domain/services/tiki_attribute_asset_manifest.dart';
import '../widgets/tiki_attribute_header.dart';
import '../widgets/tiki_attribute_svg_asset.dart';

/// Scrollable list of every bundled Tiki-Taka attribute SVG at gameplay size.
class TikiAttributeGalleryScreen extends StatelessWidget {
  const TikiAttributeGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final iconSize = TikiAttributeHeader.gameplayIconSize(
      TikiHeaderAxis.column,
    );

    return AppScaffold(
      fullWidthHeader: true,
      header: ScreenHeader(
        leadingIconAsset: IconConstant.back,
        onLeadingPressed: () => Navigator.of(context).pop(),
        leadingSemanticLabel: 'Back',
      ),
      child: FutureBuilder<TikiAttributeAssetManifest>(
        future: TikiAttributeAssetManifest.load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final manifest = snapshot.data;
          if (manifest == null) {
            return Center(
              child: Text(
                'Could not load attribute assets.',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            );
          }

          final assetPaths = manifest.allAssetPaths;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tiki-Taka Attributes',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleMd.copyWith(color: AppColors.primary),
              ),
              SizedBox(height: AppSpacing.unit.h),
              Text(
                '${assetPaths.length} SVGs',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              SizedBox(height: AppSpacing.stackMd.h),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: assetPaths.length,
                  separatorBuilder: (context, index) =>
                      SizedBox(height: AppSpacing.stackSm.h),
                  itemBuilder: (context, index) {
                    final assetPath = assetPaths[index];
                    final label =
                        TikiAttributeAssetManifest.displayNameForAssetPath(
                      assetPath,
                    );

                    return _GalleryRow(
                      assetPath: assetPath,
                      label: label,
                      iconSize: iconSize,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GalleryRow extends StatelessWidget {
  const _GalleryRow({
    required this.assetPath,
    required this.label,
    required this.iconSize,
  });

  final String assetPath;
  final String label;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMist,
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.stackSm.w,
          vertical: AppSpacing.stackSm.h,
        ),
        child: Row(
          children: [
            TikiAttributeSvgAsset(
              assetPath: assetPath,
              size: iconSize,
              rasterize: true,
              semanticsLabel: label,
              errorBuilder: (context) => _SvgErrorPlaceholder(size: iconSize),
            ),
            SizedBox(width: AppSpacing.stackSm.w),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SvgErrorPlaceholder extends StatelessWidget {
  const _SvgErrorPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: AppSpacing.borderRadiusSm,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Icon(
          Icons.image_not_supported_outlined,
          size: size * 0.4,
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}
