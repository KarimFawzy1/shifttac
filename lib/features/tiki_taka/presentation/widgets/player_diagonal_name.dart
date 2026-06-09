import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Player name shown diagonally inside a filled board cell.
class PlayerDiagonalName extends StatelessWidget {
  const PlayerDiagonalName({
    super.key,
    required this.displayName,
  });

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Transform.rotate(
          angle: -math.pi / 4,
          child: Text(
            displayName,
            style: AppTextStyles.labelBold.copyWith(
              fontSize: 11.sp,
              color: AppColors.onSurface,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}
