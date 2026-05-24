import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../look_engine.dart';
import '../makeup_layer.dart';
import '../painters/makeup_overlay_painter.dart';
import '../utils.dart';
import 'cached_makeup_layer.dart';

class MakeupPreviewValues {
  final double globalIntensity;
  final double lipOpacity;
  final double blushOpacity;
  final double eyeOpacity;
  final double linerOpacity;
  final double browOpacity;

  const MakeupPreviewValues({
    required this.globalIntensity,
    required this.lipOpacity,
    required this.blushOpacity,
    required this.eyeOpacity,
    required this.linerOpacity,
    required this.browOpacity,
  });

  MakeupPreviewValues copyWith({
    double? globalIntensity,
    double? lipOpacity,
    double? blushOpacity,
    double? eyeOpacity,
    double? linerOpacity,
    double? browOpacity,
  }) {
    return MakeupPreviewValues(
      globalIntensity: globalIntensity ?? this.globalIntensity,
      lipOpacity: lipOpacity ?? this.lipOpacity,
      blushOpacity: blushOpacity ?? this.blushOpacity,
      eyeOpacity: eyeOpacity ?? this.eyeOpacity,
      linerOpacity: linerOpacity ?? this.linerOpacity,
      browOpacity: browOpacity ?? this.browOpacity,
    );
  }
}

class FacePreviewCard extends StatelessWidget {
  final ui.Image? uiImage;
  final String? scannedImagePath;
  final bool canOverlay;
  final Face? faceForOverlay;
  final LookResult? look;
  final FaceProfile? faceProfile;
  final MakeupLookPreset preset;
  final ValueNotifier<MakeupPreviewValues> previewValues;
  final MakeupLayer makeupLayer;

  // 1. Add optional color fields to FacePreviewCard
  final Color? customLipColor;
  final Color? customBlushColor;
  final Color? customEyeshadowColor;

  const FacePreviewCard({
    super.key,
    required this.uiImage,
    required this.scannedImagePath,
    required this.canOverlay,
    required this.faceForOverlay,
    required this.look,
    required this.faceProfile,
    required this.preset,
    required this.previewValues,
    this.makeupLayer = MakeupLayer.full,
    // 2. Add parameters to the constructor
    this.customLipColor,
    this.customBlushColor,
    this.customEyeshadowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFD9E9), width: 1.4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: _PreviewLayer(
          uiImage: uiImage,
          scannedImagePath: scannedImagePath,
          canOverlay: canOverlay,
          faceForOverlay: faceForOverlay,
          look: look,
          faceProfile: faceProfile,
          preset: preset,
          previewValues: previewValues,
          makeupLayer: makeupLayer,
          // 3. Pass colors to _PreviewLayer
          customLipColor: customLipColor,
          customBlushColor: customBlushColor,
          customEyeshadowColor: customEyeshadowColor,
        ),
      ),
    );
  }
}

class _PreviewLayer extends StatelessWidget {
  final ui.Image? uiImage;
  final String? scannedImagePath;
  final bool canOverlay;
  final Face? faceForOverlay;
  final LookResult? look;
  final FaceProfile? faceProfile;
  final MakeupLookPreset preset;
  final ValueNotifier<MakeupPreviewValues> previewValues;
  final MakeupLayer makeupLayer;

  // 4. Add fields to _PreviewLayer
  final Color? customLipColor;
  final Color? customBlushColor;
  final Color? customEyeshadowColor;

  const _PreviewLayer({
    required this.uiImage,
    required this.scannedImagePath,
    required this.canOverlay,
    required this.faceForOverlay,
    required this.look,
    required this.faceProfile,
    required this.preset,
    required this.previewValues,
    required this.makeupLayer,
    // 5. Add parameters to _PreviewLayer constructor
    this.customLipColor,
    this.customBlushColor,
    this.customEyeshadowColor,
  });

  @override
  Widget build(BuildContext context) {
    if (uiImage != null && canOverlay && look != null && faceForOverlay != null) {
      final imageWidth = uiImage!.width.toDouble();
      final imageHeight = uiImage!.height.toDouble();

      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: imageWidth,
          height: imageHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: RawImage(
                  image: uiImage,
                  fit: BoxFit.fill,
                ),
              ),
              // Wrap the overlay Stack with ValueListenableBuilder
              if (canOverlay && faceForOverlay != null && look != null)
                ValueListenableBuilder<MakeupPreviewValues>(
                  valueListenable: previewValues,
                  builder: (context, values, _) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedMakeupLayer(
                          layer: MakeupLayer.brows,
                          globalOpacity: values.globalIntensity,
                          layerOpacity: values.browOpacity,
                          face: faceForOverlay!,
                          look: look!,
                          faceProfile: faceProfile,
                          preset: preset,
                        ),
                        CachedMakeupLayer(
                          layer: MakeupLayer.eyeshadow,
                          globalOpacity: values.globalIntensity,
                          layerOpacity: values.eyeOpacity,
                          face: faceForOverlay!,
                          look: look!,
                          faceProfile: faceProfile,
                          preset: preset,
                          customEyeshadowColor: customEyeshadowColor,
                        ),
                        CachedMakeupLayer(
                          layer: MakeupLayer.eyeliner,
                          globalOpacity: values.globalIntensity,
                          layerOpacity: values.linerOpacity,
                          face: faceForOverlay!,
                          look: look!,
                          faceProfile: faceProfile,
                          preset: preset,
                        ),
                        CachedMakeupLayer(
                          layer: MakeupLayer.blush,
                          globalOpacity: values.globalIntensity,
                          layerOpacity: values.blushOpacity,
                          face: faceForOverlay!,
                          look: look!,
                          faceProfile: faceProfile,
                          preset: preset,
                          customBlushColor: customBlushColor,
                        ),
                        CachedMakeupLayer(
                          layer: MakeupLayer.contour,
                          globalOpacity: values.globalIntensity,
                          layerOpacity: values.globalIntensity,
                          face: faceForOverlay!,
                          look: look!,
                          faceProfile: faceProfile,
                          preset: preset,
                        ),
                        CachedMakeupLayer(
                          layer: MakeupLayer.lips,
                          globalOpacity: values.globalIntensity,
                          layerOpacity: values.lipOpacity,
                          face: faceForOverlay!,
                          look: look!,
                          faceProfile: faceProfile,
                          preset: preset,
                          customLipColor: customLipColor,
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      );
    }

    if (scannedImagePath != null) {
      return Image.file(
        File(scannedImagePath!),
        fit: BoxFit.cover,
        alignment: Alignment.center,
      );
    }

    return const Center(
      child: Icon(
        Icons.face_retouching_natural,
        size: 72,
        color: Color(0xFFFFB6D4),
      ),
    );
  }
}