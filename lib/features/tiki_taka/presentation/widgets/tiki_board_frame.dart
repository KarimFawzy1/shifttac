import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/models/tiki_attribute.dart';
import '../../domain/services/tiki_attribute_asset_manifest.dart';
import 'tiki_attribute_header.dart';
import 'tiki_taka_board.dart';

/// Lays out three row headers, three column headers, and a centered board child.
class TikiBoardFrame extends StatelessWidget {
  const TikiBoardFrame({
    super.key,
    required this.rowHeaders,
    required this.columnHeaders,
    required this.manifest,
    required this.board,
    this.headerExtent,
  }) : assert(rowHeaders.length == 3, 'rowHeaders must contain 3 attributes'),
       assert(
         columnHeaders.length == 3,
         'columnHeaders must contain 3 attributes',
       );

  final List<TikiAttribute> rowHeaders;
  final List<TikiAttribute> columnHeaders;
  final TikiAttributeAssetManifest manifest;
  final Widget board;
  final double? headerExtent;

  static const int _gridCount = 3;

  @override
  Widget build(BuildContext context) {
    final lead = headerExtent ?? 52.w;
    final topBand = headerExtent ?? 52.w;
    final gap = AppSpacing.gridGutter.w;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalInset = 0.w;
        final usableWidth = constraints.maxWidth - (2 * horizontalInset);
        var cellSize = ((usableWidth - lead - 5 * gap) / _gridCount).toDouble();
        cellSize = math.max(0, cellSize);

        var gridExtent = 4 * gap + _gridCount * cellSize;
        var frameHeight = topBand + gap + gridExtent;

        if (frameHeight > constraints.maxHeight) {
          cellSize = ((constraints.maxHeight - topBand - 5 * gap) / _gridCount)
              .toDouble();
          cellSize = math.max(0, cellSize);
          gridExtent = 4 * gap + _gridCount * cellSize;
          frameHeight = topBand + gap + gridExtent;
        }

        final frameWidth = lead + gap + gridExtent;
        final resolvedBoard = switch (board) {
          TikiTakaBoard(:final onOutcomeRevealComplete) => TikiTakaBoard(
            cellAspectRatio: 1,
            onOutcomeRevealComplete: onOutcomeRevealComplete,
          ),
          _ => board,
        };

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalInset),
          child: Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: frameWidth,
              height: frameHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: topBand,
                    child: Row(
                      children: [
                        SizedBox(width: lead + gap),
                        SizedBox(
                          width: gridExtent,
                          child: _HeaderGridRow(
                            gap: gap,
                            cellWidth: cellSize,
                            children: [
                              for (var index = 0; index < _gridCount; index++)
                                TikiAttributeHeader(
                                  attribute: columnHeaders[index],
                                  manifest: manifest,
                                  axis: TikiHeaderAxis.column,
                                  expand: true,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: gap),
                  SizedBox(
                    height: gridExtent,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: lead,
                          child: _HeaderGridColumn(
                            gap: gap,
                            cellHeight: cellSize,
                            children: [
                              for (var index = 0; index < _gridCount; index++)
                                TikiAttributeHeader(
                                  attribute: rowHeaders[index],
                                  manifest: manifest,
                                  axis: TikiHeaderAxis.row,
                                  expand: true,
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: gap),
                        SizedBox(
                          width: gridExtent,
                          height: gridExtent,
                          child: resolvedBoard,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderGridRow extends StatelessWidget {
  const _HeaderGridRow({
    required this.gap,
    required this.cellWidth,
    required this.children,
  });

  final double gap;
  final double cellWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: gap),
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) SizedBox(width: gap),
          SizedBox(width: cellWidth, child: children[index]),
        ],
      ],
    );
  }
}

class _HeaderGridColumn extends StatelessWidget {
  const _HeaderGridColumn({
    required this.gap,
    required this.cellHeight,
    required this.children,
  });

  final double gap;
  final double cellHeight;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: gap),
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) SizedBox(height: gap),
          SizedBox(
            height: cellHeight,
            width: double.infinity,
            child: children[index],
          ),
        ],
        SizedBox(height: gap),
      ],
    );
  }
}

/// Loads the G2 manifest once, then renders [TikiBoardFrame].
class TikiBoardFrameLoader extends StatelessWidget {
  const TikiBoardFrameLoader({
    super.key,
    required this.rowHeaders,
    required this.columnHeaders,
    required this.board,
    this.headerExtent,
    this.manifestLoader,
  });

  final List<TikiAttribute> rowHeaders;
  final List<TikiAttribute> columnHeaders;
  final Widget board;
  final double? headerExtent;
  final Future<TikiAttributeAssetManifest> Function()? manifestLoader;

  @override
  Widget build(BuildContext context) {
    final cachedManifest = TikiAttributeAssetManifest.loaded;
    if (cachedManifest != null) {
      return TikiBoardFrame(
        rowHeaders: rowHeaders,
        columnHeaders: columnHeaders,
        manifest: cachedManifest,
        board: board,
        headerExtent: headerExtent,
      );
    }

    return FutureBuilder<TikiAttributeAssetManifest>(
      future: manifestLoader?.call() ?? TikiAttributeAssetManifest.load(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TikiBoardFrame(
            rowHeaders: rowHeaders,
            columnHeaders: columnHeaders,
            manifest: TikiAttributeAssetManifest.empty(),
            board: board,
            headerExtent: headerExtent,
          );
        }
        final manifest = snapshot.data;
        if (manifest == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return TikiBoardFrame(
          rowHeaders: rowHeaders,
          columnHeaders: columnHeaders,
          manifest: manifest,
          board: board,
          headerExtent: headerExtent,
        );
      },
    );
  }
}
