import 'dart:ui';

import 'package:flutter/material.dart';

import '../../domain/services/tiki_attribute_asset_manifest.dart';

/// Preloads Tiki-Taka assets that are expensive on first use so the first
/// player-search open after a cold start stays smooth.
class TikiTakaWarmupLayer extends StatefulWidget {
  const TikiTakaWarmupLayer({super.key, required this.child});

  final Widget child;

  @override
  State<TikiTakaWarmupLayer> createState() => _TikiTakaWarmupLayerState();
}

class _TikiTakaWarmupLayerState extends State<TikiTakaWarmupLayer> {
  bool _warmupVisible = true;

  @override
  void initState() {
    super.initState();
    TikiAttributeAssetManifest.preload();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _warmupVisible = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_warmupVisible)
          Positioned(
            left: 0,
            top: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.001,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: const SizedBox(width: 2, height: 2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
