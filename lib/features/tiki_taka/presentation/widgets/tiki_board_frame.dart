import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/models/tiki_attribute.dart';
import '../../domain/services/tiki_attribute_asset_manifest.dart';
import 'tiki_attribute_header.dart';

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

  @override
  Widget build(BuildContext context) {
    final band = headerExtent ?? 52.w;
    final lead = headerExtent ?? 52.w;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: band,
              child: Row(
                children: [
                  SizedBox(width: lead),
                  for (var index = 0; index < 3; index++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: index == 0 ? 0 : 4.w),
                        child: TikiAttributeHeader(
                          attribute: columnHeaders[index],
                          manifest: manifest,
                          axis: TikiHeaderAxis.column,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 4.h),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: lead,
                    child: Column(
                      children: [
                        for (var index = 0; index < 3; index++)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: index == 0 ? 0 : 4.h),
                              child: TikiAttributeHeader(
                                attribute: rowHeaders[index],
                                manifest: manifest,
                                axis: TikiHeaderAxis.row,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(child: board),
                ],
              ),
            ),
          ],
        );
      },
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
    return FutureBuilder<TikiAttributeAssetManifest>(
      future: manifestLoader?.call() ?? TikiAttributeAssetManifest.load(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TikiBoardFrame(
            rowHeaders: rowHeaders,
            columnHeaders: columnHeaders,
            manifest: TikiAttributeAssetManifest.forTest(const {}),
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
