import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../look_engine.dart';
import '../makeup_layer.dart';
import '../painters/makeup_overlay_painter.dart';
import '../utils.dart';

class CachedMakeupLayer extends StatefulWidget {
  final MakeupLayer layer;
  final ValueNotifier<double> globalOpacity;
  final ValueNotifier<double> layerOpacity;

  final Face face;
  final LookResult look;
  final FaceProfile? faceProfile;
  final MakeupLookPreset preset;

  const CachedMakeupLayer({
    super.key,
    required this.layer,
    required this.globalOpacity,
    required this.layerOpacity,
    required this.face,
    required this.look,
    required this.faceProfile,
    required this.preset,
  });

  @override
  State<CachedMakeupLayer> createState() => _CachedMakeupLayerState();
}

class _CachedMakeupLayerState extends State<CachedMakeupLayer> {
  ui.Image? _cachedLayer;
  Size? _lastSize;
  int? _lastSignature;
  bool _isRendering = false;

  @override
  void dispose() {
    _cachedLayer?.dispose();
    super.dispose();
  }

  int _signature(Size size) {
    return Object.hash(
      widget.layer,
      widget.face,
      widget.look.lipstickColor,
      widget.look.blushColor,
      widget.look.eyeshadowColor,
      widget.faceProfile?.faceShape,
      widget.preset,
      size.width.round(),
      size.height.round(),
    );
  }

  Future<void> _renderLayer(Size size) async {
    if (_isRendering) return;
    if (size.width <= 0 || size.height <= 0) return;

    final signature = _signature(size);

    if (_cachedLayer != null &&
        _lastSignature == signature &&
        _lastSize == size) {
      return;
    }

    _isRendering = true;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Offset.zero & size,
    );

    MakeupOverlayPainter(
      image: null,

      face: widget.face,

      lipstickColor: widget.look.lipstickColor,
      blushColor: widget.look.blushColor,
      eyeshadowColor: widget.look.eyeshadowColor,

      // Render once at full strength.
      // Slider will only fade this cached image.
      intensity: 1.0,

      lipstickOpacity: 1.0,
      blushOpacity: 1.0,
      contourOpacity: 1.0,
      eyeshadowOpacity: 1.0,
      eyelinerOpacity: 1.0,
      browOpacity: 1.0,

      faceShape:
          widget.faceProfile?.faceShape ??
          FaceShape.unknown,

      preset: widget.preset,

      eyelinerStyle:
          LookEngine.eyelinerStyleFromPreset(
        widget.preset,
      ),

      lipFinish: LipFinish.glossy,

      skinColor: null,
      sceneLuminance: 0.5,

      profile: widget.faceProfile,

      makeupLayer: widget.layer,
    ).paint(canvas, size);

    final picture = recorder.endRecording();

    final image = await picture.toImage(
      size.width.ceil(),
      size.height.ceil(),
    );

    picture.dispose();

    if (!mounted) {
      image.dispose();
      _isRendering = false;
      return;
    }

    final old = _cachedLayer;

    setState(() {
      _cachedLayer = image;
      _lastSize = size;
      _lastSignature = signature;
      _isRendering = false;
    });

    old?.dispose();
  }

  double _opacity() {
    final global = widget.globalOpacity.value.clamp(0.0, 1.0);

    if (widget.layer == MakeupLayer.contour) {
      return global;
    }

    return (global * widget.layerOpacity.value).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final size = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _renderLayer(size);
          }
        });

        final image = _cachedLayer;

        if (image == null) {
          return const SizedBox.expand();
        }

        return AnimatedBuilder(
          animation: Listenable.merge([
            widget.globalOpacity,
            widget.layerOpacity,
          ]),
          builder: (_, __) {
            return Opacity(
              opacity: _opacity(),
              child: RawImage(
                image: image,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.low,
              ),
            );
          },
        );
      },
    );
  }
}