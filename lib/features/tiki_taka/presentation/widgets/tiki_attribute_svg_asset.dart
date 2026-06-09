import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics_compat.dart'
    show RenderingStrategy;

import '../../domain/services/tiki_attribute_svg_preprocessor.dart';

/// Renders a bundled Tiki-Taka attribute SVG with CSS class fills inlined.
class TikiAttributeSvgAsset extends StatefulWidget {
  const TikiAttributeSvgAsset({
    super.key,
    required this.assetPath,
    required this.size,
    this.semanticsLabel,
    this.errorBuilder,
    this.rasterize = false,
  });

  final String assetPath;
  final double size;
  final String? semanticsLabel;
  final Widget Function(BuildContext context)? errorBuilder;

  /// Rasterize once for board headers and other dense SVG grids.
  final bool rasterize;

  static final Map<String, String> _preprocessedByAsset = {};
  static final Map<String, Future<String>> _loadFuturesByAsset = {};

  @visibleForTesting
  static void resetCacheForTest() {
    _preprocessedByAsset.clear();
    _loadFuturesByAsset.clear();
  }

  static Future<String> loadPreprocessed(String assetPath) {
    return _loadFuturesByAsset.putIfAbsent(assetPath, () {
      final cached = _preprocessedByAsset[assetPath];
      if (cached != null) {
        return Future<String>.value(cached);
      }

      return rootBundle.loadString(assetPath).then((raw) {
        final preprocessed = TikiAttributeSvgPreprocessor.preprocess(raw);
        _preprocessedByAsset[assetPath] = preprocessed;
        return preprocessed;
      });
    });
  }

  @override
  State<TikiAttributeSvgAsset> createState() => _TikiAttributeSvgAssetState();
}

class _TikiAttributeSvgAssetState extends State<TikiAttributeSvgAsset> {
  late final Future<String> _svgFuture;

  @override
  void initState() {
    super.initState();
    _svgFuture = TikiAttributeSvgAsset.loadPreprocessed(widget.assetPath);
  }

  @override
  void didUpdateWidget(covariant TikiAttributeSvgAsset oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _svgFuture = TikiAttributeSvgAsset.loadPreprocessed(widget.assetPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _svgFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(width: widget.size, height: widget.size);
        }

        final svg = snapshot.data;
        if (svg == null) {
          return _buildError(context);
        }

        return SvgPicture.string(
          svg,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          clipBehavior: Clip.hardEdge,
          excludeFromSemantics: widget.semanticsLabel == null,
          semanticsLabel: widget.semanticsLabel,
          renderingStrategy: widget.rasterize
              ? RenderingStrategy.raster
              : RenderingStrategy.picture,
          errorBuilder: (context, error, stackTrace) => _buildError(context),
        );
      },
    );
  }

  Widget _buildError(BuildContext context) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context);
    }
    return SizedBox(width: widget.size, height: widget.size);
  }
}
