import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../look_engine.dart';
import '../makeup_layer.dart';
import '../painters/makeup_overlay_painter.dart';
import '../utils.dart';

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
              RepaintBoundary(
                child: ValueListenableBuilder<MakeupPreviewValues>(
                  valueListenable: previewValues,
                  builder: (context, values, _) {
                    return CustomPaint(
                      size: Size(imageWidth, imageHeight),
                      painter: MakeupOverlayPainter(
                        image: null,
                        face: faceForOverlay!,
                        lipstickColor: look!.lipstickColor,
                        blushColor: look!.blushColor,
                        eyeshadowColor: look!.eyeshadowColor,
                        intensity: values.globalIntensity,
                        lipstickOpacity: values.lipOpacity,
                        blushOpacity: values.blushOpacity,
                        contourOpacity: values.blushOpacity,
                        eyeshadowOpacity: values.eyeOpacity,
                        eyelinerOpacity: values.linerOpacity,
                        browOpacity: values.browOpacity,
                        faceShape: faceProfile?.faceShape ?? FaceShape.oval,
                        preset: preset,
                        debugMode: false,
                        isLiveMode: false,
                        eyelinerStyle: LookEngine.eyelinerStyleFromPreset(preset),
                        lipFinish: LipFinish.glossy,
                        skinColor: faceProfile != null
                            ? Color.fromARGB(
                                255,
                                faceProfile!.avgR,
                                faceProfile!.avgG,
                                faceProfile!.avgB,
                              )
                            : null,
                        sceneLuminance: 0.5,
                        leftCheekLuminance: 0.5,
                        rightCheekLuminance: 0.5,
                        profile: faceProfile,
                        makeupLayer: makeupLayer,
                      ),
                    );
                  },
                ),
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