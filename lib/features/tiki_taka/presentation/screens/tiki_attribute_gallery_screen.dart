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
import '../widgets/tiki_attribute_icon.dart';
import '../widgets/tiki_attribute_svg_asset.dart';

/// Scrollable list of every bundled club PNG and nation SVG at gameplay size.
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
      child: FutureBuilder<List<TikiGalleryAsset>>(
        future: TikiAttributeAssetManifest.loadGalleryAssets(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final assets = snapshot.data;
          if (assets == null || assets.isEmpty) {
            return Center(
              child: Text(
                'Could not load attribute assets.',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            );
          }

          final clubCount = assets.where((asset) => asset.isClub).length;
          final nationCount = assets.length - clubCount;

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
                '$clubCount clubs · $nationCount nations',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              SizedBox(height: AppSpacing.stackMd.h),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: assets.length,
                  separatorBuilder: (context, index) =>
                      SizedBox(height: AppSpacing.stackSm.h),
                  itemBuilder: (context, index) {
                    final asset = assets[index];

                    return _GalleryRow(
                      asset: asset,
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
    required this.asset,
    required this.iconSize,
  });

  final TikiGalleryAsset asset;
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
            _GalleryAssetIcon(asset: asset, iconSize: iconSize),
            SizedBox(width: AppSpacing.stackSm.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.label,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  Text(
                    asset.isClub ? 'Club' : 'Nation',
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryAssetIcon extends StatelessWidget {
  const _GalleryAssetIcon({
    required this.asset,
    required this.iconSize,
  });

  final TikiGalleryAsset asset;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (asset.isClub) {
      final renderSize = iconSize * TikiAttributeIcon.clubVisualScale;

      return SizedBox(
        width: iconSize,
        height: iconSize,
        child: ClipRect(
          child: Center(
            child: Image.asset(
              asset.path,
              width: renderSize,
              height: renderSize,
              fit: BoxFit.contain,
              semanticLabel: asset.label,
              errorBuilder: (context, error, stackTrace) {
                return _AssetErrorPlaceholder(size: iconSize);
              },
            ),
          ),
        ),
      );
    }

    return TikiAttributeSvgAsset(
      assetPath: asset.path,
      size: iconSize,
      rasterize: true,
      semanticsLabel: asset.label,
      errorBuilder: (context) => _AssetErrorPlaceholder(size: iconSize),
    );
  }
}

class _AssetErrorPlaceholder extends StatelessWidget {
  const _AssetErrorPlaceholder({required this.size});

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
