import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'look_engine.dart';

/// Configuration for blush style per look
class BlushStyleProfile {
  final double strength; // 0.4–1.0
  final double verticalPlacement; // -0.1 to +0.1 (lower/higher)
  final double horizontalSpread; // 0.8–1.2 (temple vs centered)
  final double softness; // 0.5–1.5 (soft vs bold)
  final Color? overrideColor;
  
  const BlushStyleProfile({
    this.strength = 1.0,
    this.verticalPlacement = 0.0,
    this.horizontalSpread = 1.0,
    this.softness = 1.0,
    this.overrideColor,
  });
}

class BlushPainter {
  final Face face;
  final Color blushColor;
  final double intensity;
  final FaceShape faceShape;
  final String? lookStyle;
  final bool isLiveMode;
  final bool debugMode;

  /// Optional sampled skin color (FaceProfile avgR/G/B)
  final Color? skinColor;

  /// NEW: overall scene luminance (0..1). Compute this once and pass in.
  /// If null, fallback to skinColor luminance (or default 0.55).
  final double? sceneLuminance;

  /// Anti-jitter smoothing key (use face.trackingId)
  final int faceId;

  // Tuning knobs for cheek anchor positioning
  static const double anchorUpFactor = 0.02;
  static const double anchorOutFactor = 0.03;
  static const double anchorInLimitFactor = 0.08;

  BlushPainter({
    required this.face,
    required this.blushColor,
    required this.intensity,
    required this.faceShape,
    this.lookStyle,
    this.isLiveMode = true,
    this.debugMode = false,
    this.skinColor,
    this.sceneLuminance,
    this.faceId = -1,
  });

  // -----------------------------
  // Anti-jitter smoothing (EMA) - Now conditional
  // -----------------------------
  static final Map<int, List<ui.Offset>> _ovalSmoothers = <int, List<ui.Offset>>{};
  static final Map<int, ui.Offset> _leftAnchorSmoothers = <int, ui.Offset>{};
  static final Map<int, ui.Offset> _rightAnchorSmoothers = <int, ui.Offset>{};

  // Reset method for still images
  static void resetSmoothers() {
    _ovalSmoothers.clear();
    _leftAnchorSmoothers.clear();
    _rightAnchorSmoothers.clear();
  }

  // Non-linear intensity curve - GENTLER VERSION
  double _applyIntensityCurve(double intensity) {
    // Much gentler curve for smooth blending
    if (intensity <= 0.4) {
      return intensity * 0.8; // Very gentle in low range
    } else if (intensity <= 0.7) {
      return 0.32 + (intensity - 0.4) * 0.8; // Smooth transition
    } else {
      return 0.56 + (intensity - 0.7) * 1.2; // Moderate ramp in high range
    }
  }

  // Look engine blush style profiles - SOFTER VERSION
  BlushStyleProfile _getBlushStyleProfile(String? lookStyle) {
    switch (lookStyle) {
      case 'natural':
        return BlushStyleProfile(
          strength: 0.6,
          verticalPlacement: 0.0,
          horizontalSpread: 1.0,
          softness: 1.4,
        );
      case 'glam':
        return BlushStyleProfile(
          strength: 0.9,
          verticalPlacement: 0.02,
          horizontalSpread: 0.95,
          softness: 1.0,
          overrideColor: null,
        );
      case 'emo':
        return BlushStyleProfile(
          strength: 0.35,
          verticalPlacement: -0.01,
          horizontalSpread: 0.9,
          softness: 1.8,
          overrideColor: blushColor.withRed((blushColor.red * 0.9).toInt())
            .withGreen((blushColor.green * 0.8).toInt()),
        );
      case 'soft':
        return BlushStyleProfile(
          strength: 0.4,
          verticalPlacement: 0.01,
          horizontalSpread: 1.1,
          softness: 1.6,
        );
      case 'bold':
        return BlushStyleProfile(
          strength: 1.0,
          verticalPlacement: 0.0,
          horizontalSpread: 0.98,
          softness: 0.9,
        );
      default:
        return BlushStyleProfile(
          strength: 0.7,
          verticalPlacement: 0.0,
          horizontalSpread: 1.0,
          softness: 1.2,
        );
    }
  }

  int _faceKey() => (faceId == -1) ? face.boundingBox.hashCode : faceId;

  void paint(Canvas canvas, Size size) {
    // Apply gentle non-linear intensity curve
    final k0 = _applyIntensityCurve(intensity.clamp(0.0, 1.0));
    if (k0 <= 0.0) return;

    final box = face.boundingBox;
    final faceW = box.width;
    final faceH = box.height;

    // Reset smoothers if not in live mode
    if (!isLiveMode) {
      resetSmoothers();
    }

    // Face-shape tuning
    double cheekYFactor;
    double lift;
    double widthFactor;
    double inwardFactor;

    switch (faceShape) {
      case FaceShape.round:
        cheekYFactor = 0.58;
        lift = 1.22;
        widthFactor = 1.10;
        inwardFactor = 1.06;
        break;
      case FaceShape.square:
        cheekYFactor = 0.64;
        lift = 0.92;
        widthFactor = 0.98;
        inwardFactor = 0.96;
        break;
      case FaceShape.oval:
        cheekYFactor = 0.62;
        lift = 1.06;
        widthFactor = 1.02;
        inwardFactor = 1.00;
        break;
      case FaceShape.heart:
        cheekYFactor = 0.60;
        lift = 1.14;
        widthFactor = 1.00;
        inwardFactor = 1.03;
        break;
      case FaceShape.unknown:
        cheekYFactor = 0.62;
        lift = 1.0;
        widthFactor = 1.0;
        inwardFactor = 1.0;
        break;
    }

    // Get blush style profile
    final blushProfile = _getBlushStyleProfile(lookStyle);
    final lookStrength = blushProfile.strength;
    final blushColorToUse = blushProfile.overrideColor ?? blushColor;
    
    // Core opacity multiplier from profile
    final coreOpacityMultiplier = blushProfile.softness < 1.0 ? 1.1 : 
                                  blushProfile.softness > 1.5 ? 0.6 : 0.8;

    // Tone adaptation (auto-visibility boost from skin/blush tone)
    final autoBoost = _computeAutoBoost(blush: blushColorToUse, skin: skinColor);

    // ✅ FIXED: New scene luminance handling - NO aggressive boost in dark
    final l = (sceneLuminance ?? (skinColor != null ? _luminance01(skinColor!) : 0.55))
        .clamp(0.0, 1.0);

    // Instead of boosting pigment in dark scenes,
    // we keep k stable and handle darkness via feather/blur changes.
    final darkT = ((0.35 - l) / 0.35).clamp(0.0, 1.0);   // 0=normal, 1=very dark
    final brightT = ((l - 0.75) / 0.25).clamp(0.0, 1.0); // 0=normal, 1=very bright

    // k behavior:
    // - dark: slight increase only (NOT big), avoid harsh edges
    // - bright: tiny decrease to avoid looking "painted"
    final darkKBoost = ui.lerpDouble(1.00, 1.08, darkT)!;
    final brightKCut = ui.lerpDouble(1.00, 0.92, brightT)!;

    final k = (k0 * lookStrength * autoBoost * darkKBoost * brightKCut).clamp(0.0, 1.0);

    // ✅ FIXED: Adaptive feather/blur in dark scenes
    final sigmaBase = max(faceW, faceH) * 0.012;

    var sigmaSoft = sigmaBase * 2.0;
    var sigmaFeather = sigmaBase * 3.3;
    var sigmaDiffuse = sigmaBase * 4.4;

    // Dark scene: increase feather + diffuse so edges disappear
    sigmaFeather *= ui.lerpDouble(1.0, 1.35, darkT)!;
    sigmaDiffuse *= ui.lerpDouble(1.0, 1.45, darkT)!;

    // Bright scene: slightly reduce blur so it doesn't look too foggy
    sigmaFeather *= ui.lerpDouble(1.0, 0.92, brightT)!;
    sigmaDiffuse *= ui.lerpDouble(1.0, 0.92, brightT)!;

    // Apply blush profile softness
    sigmaSoft *= blushProfile.softness;
    sigmaFeather *= blushProfile.softness;
    sigmaDiffuse *= blushProfile.softness;

    // Landmark-based placement
    final leftCheekPts = _contourOffsets(face.contours[FaceContourType.leftCheek]?.points);
    final rightCheekPts = _contourOffsets(face.contours[FaceContourType.rightCheek]?.points);

    // Face oval (for clipping + fallback placement)
    final faceOvalPts = _contourOffsets(face.contours[FaceContourType.face]?.points);

    if (faceOvalPts.length < 10) {
      _fallbackBlush(
        canvas: canvas,
        box: box,
        faceW: faceW,
        faceH: faceH,
        cheekYFactor: cheekYFactor,
        lift: lift,
        widthFactor: widthFactor,
        kCore: k,
        kEdge: k * 0.7,
        sigmaSoft: sigmaSoft,
        sigmaFeather: sigmaFeather,
        darkT: darkT,
        blushColor: blushColorToUse,
        coreOpacityMultiplier: coreOpacityMultiplier,
        blushProfile: blushProfile,
      );
      return;
    }

    // Conditional smoothing
    final baseKey = _faceKey();
    final smoothedOval = isLiveMode 
        ? _smoothPoints(faceOvalPts, baseKey, alpha: 0.18)
        : faceOvalPts;

    // No-paint zone masking
    final faceClip = _buildSmoothClosedPath(smoothedOval, targetPoints: 42);

    final eyeL = _contourOffsets(face.contours[FaceContourType.leftEye]?.points);
    final eyeR = _contourOffsets(face.contours[FaceContourType.rightEye]?.points);
    final upperLip = _contourOffsets(face.contours[FaceContourType.upperLipTop]?.points);
    final lowerLip = _contourOffsets(face.contours[FaceContourType.lowerLipBottom]?.points);
    final leftEyebrow = _contourOffsets(face.contours[FaceContourType.leftEyebrowTop]?.points);
    final rightEyebrow = _contourOffsets(face.contours[FaceContourType.rightEyebrowTop]?.points);

    final exclude = Path();

    // Eye exclusion zones - MORE GENEROUS
    if (eyeL.length >= 5) {
      final eyeBounds = _boundsOf(eyeL).inflate(faceW * 0.12);
      exclude.addOval(eyeBounds);
    }
    if (eyeR.length >= 5) {
      final eyeBounds = _boundsOf(eyeR).inflate(faceW * 0.12);
      exclude.addOval(eyeBounds);
    }
    
    // Eyebrow exclusion zones
    if (leftEyebrow.isNotEmpty) {
      final browBounds = _boundsOf(leftEyebrow).inflate(faceW * 0.04);
      exclude.addOval(browBounds);
    }
    if (rightEyebrow.isNotEmpty) {
      final browBounds = _boundsOf(rightEyebrow).inflate(faceW * 0.04);
      exclude.addOval(browBounds);
    }
    
    // Lip exclusion zones
    if (upperLip.length >= 5 && lowerLip.length >= 5) {
      exclude.addPath(_buildSmoothClosedPath(upperLip, targetPoints: 22), ui.Offset.zero);
      exclude.addPath(_buildSmoothClosedPath(lowerLip, targetPoints: 22), ui.Offset.zero);
    }

    // Nose bridge small exclusion zone
    final noseBridge = _contourOffsets(face.contours[FaceContourType.noseBridge]?.points);
    if (noseBridge.length >= 2) {
      final nb = _boundsOf(noseBridge).inflate(faceW * 0.03);
      exclude.addRRect(RRect.fromRectXY(nb, 18, 18));
    }

    // Nose area protection - but SOFTER
    _addNoseProtectionZone(exclude, box, faceW, faceH);

    // Cheek-only mask for extra safety
    Path clip = Path.combine(PathOperation.difference, faceClip, exclude);
    
    // Get eye and mouth boundaries for cheek band
    final eyeBoundsL = eyeL.isNotEmpty ? _boundsOf(eyeL) : null;
    final eyeBoundsR = eyeR.isNotEmpty ? _boundsOf(eyeR) : null;
    final mouthBounds = upperLip.isNotEmpty ? _boundsOf(upperLip) : null;
    
    // Add cheek zone clipping band with SOFT clamping
    final cheekBandClip = _buildCheekBandClipSoft(
      box, 
      eyeBoundsL, 
      eyeBoundsR, 
      mouthBounds, 
      faceH
    );
    if (cheekBandClip != null) {
      clip = Path.combine(PathOperation.intersect, clip, cheekBandClip);
    }

    canvas.save();
    canvas.clipPath(clip);

    // Nose center bias to keep blush stable on yaw
    final noseCenterX = _estimateNoseCenterX(face, box);

    // Yaw detection for asymmetry compensation
    final faceCenterX = box.center.dx;
    final yawOffset = (noseCenterX - faceCenterX) / faceW;
    final yawFactor = yawOffset.clamp(-0.4, 0.4);

    // Calculate cheek anchors for both sides
    final leftAnchor = _computeCheekAnchorStable(
      isLeft: true,
      box: box,
      faceW: faceW,
      faceH: faceH,
      eyeContour: eyeL,
      upperLip: upperLip,
      faceOval: smoothedOval,
      noseCenterX: noseCenterX,
      verticalPlacement: blushProfile.verticalPlacement,
      horizontalSpread: blushProfile.horizontalSpread,
      faceKey: baseKey,
    );

    final rightAnchor = _computeCheekAnchorStable(
      isLeft: false,
      box: box,
      faceW: faceW,
      faceH: faceH,
      eyeContour: eyeR,
      upperLip: upperLip,
      faceOval: smoothedOval,
      noseCenterX: noseCenterX,
      verticalPlacement: blushProfile.verticalPlacement,
      horizontalSpread: blushProfile.horizontalSpread,
      faceKey: baseKey,
    );

    // Debug mode overlay
    if (debugMode) {
      _drawDebugOverlay(canvas, box, eyeBoundsL, eyeBoundsR, mouthBounds, 
                       leftAnchor, rightAnchor, faceH);
    }

    if (leftCheekPts.length >= 5 && rightCheekPts.length >= 5) {
      _drawCheekFromContour(
        canvas: canvas,
        box: box,
        faceW: faceW,
        faceH: faceH,
        cheekContour: leftCheekPts,
        left: true,
        cheekYFactor: cheekYFactor,
        lift: lift,
        widthFactor: widthFactor,
        inwardFactor: inwardFactor,
        kCore: k,
        sigmaSoft: sigmaSoft,
        sigmaFeather: sigmaFeather,
        sigmaDiffuse: sigmaDiffuse,
        noseCenterX: noseCenterX,
        cheekAnchor: leftAnchor,
        faceKey: baseKey,
        yawFactor: yawFactor,
        coreOpacityMultiplier: coreOpacityMultiplier,
        darkT: darkT,
        blushColor: blushColorToUse,
        blushProfile: blushProfile,
      );

      _drawCheekFromContour(
        canvas: canvas,
        box: box,
        faceW: faceW,
        faceH: faceH,
        cheekContour: rightCheekPts,
        left: false,
        cheekYFactor: cheekYFactor,
        lift: lift,
        widthFactor: widthFactor,
        inwardFactor: inwardFactor,
        kCore: k,
        sigmaSoft: sigmaSoft,
        sigmaFeather: sigmaFeather,
        sigmaDiffuse: sigmaDiffuse,
        noseCenterX: noseCenterX,
        cheekAnchor: rightAnchor,
        faceKey: baseKey,
        yawFactor: yawFactor,
        coreOpacityMultiplier: coreOpacityMultiplier,
        darkT: darkT,
        blushColor: blushColorToUse,
        blushProfile: blushProfile,
      );
    } else {
      _drawCheekFromFaceOvalBand(
        canvas: canvas,
        faceOval: smoothedOval,
        box: box,
        cheekYFactor: cheekYFactor,
        lift: lift,
        widthFactor: widthFactor,
        inwardFactor: inwardFactor,
        kCore: k,
        sigmaSoft: sigmaSoft,
        sigmaFeather: sigmaFeather,
        sigmaDiffuse: sigmaDiffuse,
        left: true,
        noseCenterX: noseCenterX,
        cheekAnchor: leftAnchor,
        yawFactor: yawFactor,
        coreOpacityMultiplier: coreOpacityMultiplier,
        darkT: darkT,
        blushColor: blushColorToUse,
        blushProfile: blushProfile,
      );

      _drawCheekFromFaceOvalBand(
        canvas: canvas,
        faceOval: smoothedOval,
        box: box,
        cheekYFactor: cheekYFactor,
        lift: lift,
        widthFactor: widthFactor,
        inwardFactor: inwardFactor,
        kCore: k,
        sigmaSoft: sigmaSoft,
        sigmaFeather: sigmaFeather,
        sigmaDiffuse: sigmaDiffuse,
        left: false,
        noseCenterX: noseCenterX,
        cheekAnchor: rightAnchor,
        yawFactor: yawFactor,
        coreOpacityMultiplier: coreOpacityMultiplier,
        darkT: darkT,
        blushColor: blushColorToUse,
        blushProfile: blushProfile,
      );
    }

    canvas.restore();
  }

  // ----------------------------------------------------------
  // UPDATED: Layered blush rendering with dark lighting fixes
  // ----------------------------------------------------------
  void _renderLayeredBlush({
    required Canvas canvas,
    required Path region,
    required ui.Offset center,
    required double radius,
    required Rect saveBounds,
    required double kCore,
    required double sigmaSoft,
    required double sigmaFeather,
    required double sigmaDiffuse,
    required bool left,
    required double coreOpacityMultiplier,
    required double yawFactor,
    required double darkT,
    required Color blushColor,
    required BlushStyleProfile blushProfile,
  }) {
    final base = blushColor;

    // Slight HSL tuning for realism - SOFTER
    final core = _shiftHsl(base, hueDelta: 3.0, satMul: 1.05, lightMul: 0.99);
    final edge = _shiftHsl(base, hueDelta: 5.0, satMul: 0.92, lightMul: 1.04);

    // Asymmetry compensation based on yaw - SOFTER
    double yawAdjustedRadius = radius;
    double yawAdjustedCore = kCore;
    
    if (left && yawFactor > 0.15) {
      yawAdjustedRadius *= (1.0 - yawFactor * 0.3);
      yawAdjustedCore *= (1.0 - yawFactor * 0.2);
    } else if (!left && yawFactor < -0.15) {
      yawAdjustedRadius *= (1.0 + yawFactor * 0.3);
      yawAdjustedCore *= (1.0 + yawFactor * 0.2);
    }

    // Apply horizontal spread from profile
    yawAdjustedRadius *= blushProfile.horizontalSpread;

    // ✅ FIXED: Reduce harsh blend passes when dark
    final harshPass = ui.lerpDouble(1.0, 0.55, darkT)!; // dark -> reduce multiply/overlay

    // Directional lift gradient (toward temple)
    final dir = left ? ui.Offset(-1, -1) : ui.Offset(1, -1);
    final liftA = center + dir * (yawAdjustedRadius * 0.45);
    final liftB = center - dir * (yawAdjustedRadius * 0.55);

    final liftShader = ui.Gradient.linear(
      liftA,
      liftB,
      [
        Colors.white.withOpacity(0.04 * yawAdjustedCore),
        Colors.transparent,
      ],
      const [0.0, 1.0],
    );

    // Base radial gradient
    final baseShader = ui.Gradient.radial(
      center,
      yawAdjustedRadius,
      [
        core.withOpacity(0.42 * yawAdjustedCore),
        base.withOpacity(0.14 * yawAdjustedCore),
        edge.withOpacity(0.0),
      ],
      const [0.0, 0.85, 1.0],
    );

    // ✅ NEW: Enhanced vertical fade for bottom edges
    final verticalFadeShader = ui.Gradient.linear(
      ui.Offset(center.dx, center.dy - yawAdjustedRadius * 0.6),
      ui.Offset(center.dx, center.dy + yawAdjustedRadius * 0.9),
      [
        Colors.transparent,
        Colors.transparent,
        base.withOpacity(0.15 * yawAdjustedCore),
        base.withOpacity(0.25 * yawAdjustedCore),
        Colors.transparent,
      ],
      const [0.0, 0.4, 0.6, 0.85, 1.0],
    );

    canvas.saveLayer(saveBounds, Paint());

    // PASS 1: soft embedded pigment - Use core intensity
    canvas.drawPath(
      region,
      Paint()
        ..isAntiAlias = true
        ..shader = baseShader
        ..blendMode = BlendMode.softLight
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaSoft * 1.2),
    );

    // PASS 2: deepen (shadow depth) - REDUCED in dark scenes
    canvas.drawPath(
      region,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.radial(
          center,
          yawAdjustedRadius * 1.1,
          [
            base.withOpacity(0.10 * yawAdjustedCore * harshPass), // Reduced in dark
            Colors.transparent,
          ],
          const [0.0, 1.0],
        )
        ..blendMode = BlendMode.multiply
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaSoft * 1.1),
    );

    // PASS 3: pigment core pop (contrast) - REDUCED in dark scenes
    canvas.drawPath(
      region,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.radial(
          center,
          yawAdjustedRadius * 0.75,
          [
            core.withOpacity(0.26 * yawAdjustedCore * coreOpacityMultiplier * harshPass), // Reduced in dark
            Colors.transparent,
          ],
          const [0.0, 1.0],
        )
        ..blendMode = BlendMode.overlay
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaSoft),
    );

    // PASS 4: feather edges
    canvas.drawPath(
      region,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.radial(
          center,
          yawAdjustedRadius * 1.4,
          [
            base.withOpacity(0.10 * yawAdjustedCore),
            base.withOpacity(0.03 * yawAdjustedCore),
            Colors.transparent,
          ],
          const [0.0, 0.85, 1.0],
        )
        ..blendMode = BlendMode.softLight
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaFeather * 1.2),
    );

    // Very subtle skin texture illusion (optional)
    if (blushProfile.softness < 1.3) {
      _drawTextureNoise(
        canvas: canvas,
        region: region,
        bounds: saveBounds,
        opacity: 0.015 * yawAdjustedCore,
        scale: 0.05,
      );
    }

    // PASS 5: diffuse haze
    canvas.drawPath(
      region,
      Paint()
        ..isAntiAlias = true
        ..color = base.withOpacity(0.018 * yawAdjustedCore)
        ..blendMode = BlendMode.softLight
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaDiffuse * 1.3),
    );

    // PASS 6: subtle highlight lift (toward temple)
    canvas.drawPath(
      region,
      Paint()
        ..isAntiAlias = true
        ..shader = liftShader
        ..blendMode = BlendMode.screen
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaSoft * 1.3),
    );

    // ✅ FIXED: Extra feather-only pass in dark scenes (kills the edge)
    if (darkT > 0.01) {
      final extra = ui.lerpDouble(0.0, 1.0, darkT)!;
      canvas.drawPath(
        region,
        Paint()
          ..isAntiAlias = true
          ..shader = ui.Gradient.radial(
            center,
            radius * 1.35,
            [
              base.withOpacity(0.06 * yawAdjustedCore * extra),
              Colors.transparent,
            ],
            const [0.55, 1.0],
          )
          ..blendMode = BlendMode.softLight
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaDiffuse * 1.15),
      );
    }

    // Bottom fade to prevent jaw bleed
    canvas.drawPath(
      region,
      Paint()
        ..isAntiAlias = true
        ..shader = verticalFadeShader
        ..blendMode = BlendMode.dstOut
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigmaSoft * 1.8),
    );

    canvas.restore();
  }

  // Color adaptation for dark lighting
  Color _adaptColorForDarkLighting(Color color, double darkFactor) {
    if (darkFactor > 0.1) {
      // In dark lighting, make color slightly more muted
      final hsl = HSLColor.fromColor(color);
      final saturation = hsl.saturation * (1.0 - (darkFactor * 0.2));
      final lightness = hsl.lightness * (1.0 - (darkFactor * 0.1));
      return hsl.withSaturation(saturation.clamp(0.0, 1.0))
               .withLightness(lightness.clamp(0.0, 1.0))
               .toColor();
    }
    return color;
  }

  // Very subtle skin texture illusion
  void _drawTextureNoise({
    required Canvas canvas,
    required Path region,
    required Rect bounds,
    required double opacity,
    required double scale,
  }) {
    if (opacity < 0.001) return;
    
    final paint = Paint()
      ..color = Colors.black.withOpacity(opacity * 0.3)
      ..blendMode = BlendMode.overlay
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 1.0);

    final rng = Random(42);
    final cellSize = 6.0;
    
    canvas.saveLayer(bounds, Paint());
    canvas.clipPath(region);
    
    for (double x = bounds.left; x < bounds.right; x += cellSize) {
      for (double y = bounds.top; y < bounds.bottom; y += cellSize) {
        if (rng.nextDouble() < 0.15) {
          final alpha = rng.nextDouble() * 0.05 * opacity;
          canvas.drawRect(
            Rect.fromLTWH(x, y, cellSize * scale, cellSize * scale),
            paint..color = Colors.black.withOpacity(alpha),
          );
        }
      }
    }
    
    canvas.restore();
  }

  // Nose protection zone - SOFTER
  void _addNoseProtectionZone(Path exclude, Rect box, double faceW, double faceH) {
    final noseZoneWidth = faceW * 0.12;
    final noseZoneHeight = faceH * 0.15;
    final noseZoneCenter = ui.Offset(box.center.dx, box.top + faceH * 0.45);
    
    final noseZone = Path()
      ..addOval(Rect.fromCenter(
        center: noseZoneCenter,
        width: noseZoneWidth,
        height: noseZoneHeight,
      ));
    
    exclude.addPath(noseZone, ui.Offset.zero);
  }

  // SOFT cheek band clamp
  Path? _buildCheekBandClipSoft(
    Rect box, 
    Rect? eyeBoundsL, 
    Rect? eyeBoundsR, 
    Rect? mouthBounds, 
    double faceH
  ) {
    double top = box.bottom;
    double bottom = box.top;
    
    if (eyeBoundsL != null) {
      top = min(top, eyeBoundsL.bottom);
    }
    if (eyeBoundsR != null) {
      top = min(top, eyeBoundsR.bottom);
    }
    
    if (mouthBounds != null) {
      bottom = max(bottom, mouthBounds.top);
    }
    
    final padding = faceH * 0.05;
    top += padding;
    bottom -= padding;
    
    if (bottom > top && bottom - top > faceH * 0.08) {
      return Path()..addRect(Rect.fromLTRB(
        box.left,
        top,
        box.right,
        bottom,
      ));
    }
    
    return null;
  }

  // Stable anchor computation
  ui.Offset _computeCheekAnchorStable({
    required bool isLeft,
    required Rect box,
    required double faceW,
    required double faceH,
    required List<ui.Offset> eyeContour,
    required List<ui.Offset> upperLip,
    required List<ui.Offset> faceOval,
    required double noseCenterX,
    required double verticalPlacement,
    required double horizontalSpread,
    required int faceKey,
  }) {
    double safeTop = box.bottom;
    double safeBottom = box.top;
    
    if (eyeContour.isNotEmpty) {
      safeTop = _getEyeBottomFromContour(eyeContour);
    }
    
    if (upperLip.isNotEmpty) {
      safeBottom = _getMouthTopFromContour(upperLip);
    }
    
    final padding = faceH * 0.05;
    safeTop += padding;
    safeBottom -= padding;
    
    if (safeBottom <= safeTop) {
      safeTop = box.top + faceH * 0.35;
      safeBottom = box.top + faceH * 0.65;
    }
    
    final bandHeight = safeBottom - safeTop;
    final baseY = safeTop + bandHeight * 0.4;
    final targetY = baseY + (bandHeight * verticalPlacement);
    
    final clampedY = targetY.clamp(safeTop + padding * 0.5, safeBottom - padding * 0.5);
    
    final sidePts = faceOval.where((p) => isLeft ? (p.dx <= box.center.dx) : (p.dx >= box.center.dx)).toList();
    double targetX = isLeft ? box.left + faceW * 0.25 : box.right - faceW * 0.25;
    
    if (sidePts.isNotEmpty) {
      sidePts.sort((a, b) => (a.dy - clampedY).abs().compareTo((b.dy - clampedY).abs()));
      final closestPoint = sidePts.first;
      
      final yDist = (closestPoint.dy - clampedY).abs() / faceH;
      final weight = 1.0 - yDist.clamp(0.0, 0.3);
      
      if (isLeft) {
        final leftmostPts = sidePts.where((p) => (p.dy - clampedY).abs() < faceH * 0.15).toList();
        if (leftmostPts.isNotEmpty) {
          leftmostPts.sort((a, b) => a.dx.compareTo(b.dx));
          targetX = leftmostPts.first.dx * weight + targetX * (1 - weight);
        }
      } else {
        final rightmostPts = sidePts.where((p) => (p.dy - clampedY).abs() < faceH * 0.15).toList();
        if (rightmostPts.isNotEmpty) {
          rightmostPts.sort((a, b) => b.dx.compareTo(a.dx));
          targetX = rightmostPts.first.dx * weight + targetX * (1 - weight);
        }
      }
    }
    
    final spreadAdjustment = (1.0 - horizontalSpread) * faceW * 0.08;
    if (horizontalSpread < 1.0) {
      targetX += isLeft ? spreadAdjustment : -spreadAdjustment;
    } else if (horizontalSpread > 1.0) {
      targetX += isLeft ? -spreadAdjustment : spreadAdjustment;
    }
    
    final liftY = -faceH * anchorUpFactor;
    final outX = isLeft ? -faceW * anchorOutFactor : faceW * anchorOutFactor;
    
    var anchor = ui.Offset(
      targetX + outX,
      clampedY + liftY,
    );

    final maxInward = faceW * anchorInLimitFactor * 1.2;
    if (isLeft) {
      final distanceFromNose = noseCenterX - anchor.dx;
      if (distanceFromNose < maxInward) {
        anchor = ui.Offset(noseCenterX - maxInward, anchor.dy);
      }
    } else {
      final distanceFromNose = anchor.dx - noseCenterX;
      if (distanceFromNose < maxInward) {
        anchor = ui.Offset(noseCenterX + maxInward, anchor.dy);
      }
    }

    if (isLiveMode) {
      final smootherKey = faceKey * 1000 + (isLeft ? 1 : 2);
      final smoothers = isLeft ? _leftAnchorSmoothers : _rightAnchorSmoothers;
      final prevAnchor = smoothers[smootherKey];
      
      if (prevAnchor == null) {
        smoothers[smootherKey] = anchor;
      } else {
        final smoothed = ui.Offset(
          prevAnchor.dx + (anchor.dx - prevAnchor.dx) * 0.25,
          prevAnchor.dy + (anchor.dy - prevAnchor.dy) * 0.25,
        );
        smoothers[smootherKey] = smoothed;
        anchor = smoothed;
      }
    }

    return anchor;
  }

  // Debug mode overlay
  void _drawDebugOverlay(
    Canvas canvas,
    Rect box,
    Rect? eyeBoundsL,
    Rect? eyeBoundsR,
    Rect? mouthBounds,
    ui.Offset leftAnchor,
    ui.Offset rightAnchor,
    double faceH,
  ) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    final textStyle = TextStyle(
      color: Colors.red,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    if (eyeBoundsL != null && eyeBoundsR != null && mouthBounds != null) {
      final top = max(eyeBoundsL.bottom, eyeBoundsR.bottom) + faceH * 0.05;
      final bottom = mouthBounds.top - faceH * 0.05;
      
      canvas.drawRect(
        Rect.fromLTRB(box.left, top, box.right, bottom),
        paint..color = Colors.blue.withOpacity(0.2),
      );
      
      canvas.drawLine(
        ui.Offset(box.left, top),
        ui.Offset(box.right, top),
        paint..color = Colors.blue,
      );
      
      canvas.drawLine(
        ui.Offset(box.left, bottom),
        ui.Offset(box.right, bottom),
        paint..color = Colors.blue,
      );
    }
    
    canvas.drawCircle(leftAnchor, 4, Paint()..color = Colors.green);
    canvas.drawCircle(rightAnchor, 4, Paint()..color = Colors.green);
    
    textPainter.text = TextSpan(
      text: 'L',
      style: textStyle,
    );
    textPainter.layout();
    textPainter.paint(canvas, leftAnchor + ui.Offset(6, -12));
    
    textPainter.text = TextSpan(
      text: 'R',
      style: textStyle,
    );
    textPainter.layout();
    textPainter.paint(canvas, rightAnchor + ui.Offset(6, -12));
    
    if (eyeBoundsL != null) {
      canvas.drawRect(eyeBoundsL.inflate(faceH * 0.12), paint..color = Colors.red.withOpacity(0.2));
    }
    if (eyeBoundsR != null) {
      canvas.drawRect(eyeBoundsR.inflate(faceH * 0.12), paint..color = Colors.red.withOpacity(0.2));
    }
    
    final noseZone = Rect.fromCenter(
      center: ui.Offset(box.center.dx, box.top + faceH * 0.45),
      width: box.width * 0.12,
      height: faceH * 0.15,
    );
    canvas.drawOval(noseZone, paint..color = Colors.purple.withOpacity(0.2));
  }

  // Updated cheek drawing method
  void _drawCheekFromContour({
    required Canvas canvas,
    required Rect box,
    required double faceW,
    required double faceH,
    required List<ui.Offset> cheekContour,
    required bool left,
    required double cheekYFactor,
    required double lift,
    required double widthFactor,
    required double inwardFactor,
    required double kCore,
    required double sigmaSoft,
    required double sigmaFeather,
    required double sigmaDiffuse,
    required double noseCenterX,
    required ui.Offset cheekAnchor,
    required int faceKey,
    required double yawFactor,
    required double coreOpacityMultiplier,
    required double darkT,
    required Color blushColor,
    required BlushStyleProfile blushProfile,
  }) {
    if (cheekContour.length < 5) return;

    final cheek = isLiveMode 
        ? _smoothPoints(cheekContour, faceKey * 100 + (left ? 1 : 2), alpha: 0.22)
        : cheekContour;

    final sideSign = left ? -1.0 : 1.0;
    final noseBias = ((box.center.dx - noseCenterX) / max(1.0, faceW)).clamp(-0.18, 0.18);
    final biasX = noseBias * faceW * 0.18 * sideSign;

    final inward = faceW * 0.11 * widthFactor * inwardFactor;
    final liftY = faceH * 0.035 * lift;
    final dirXToCenter = left ? 1.0 : -1.0;

    cheek.sort((a, b) => a.dy.compareTo(b.dy));
    final targetY = box.top + faceH * cheekYFactor;
    final bandTop = targetY - faceH * 0.10;
    final bandBot = targetY + faceH * 0.11;

    final band = cheek.where((p) => p.dy >= bandTop && p.dy <= bandBot).toList();
    final outer = _resample(band.isNotEmpty ? band : cheek, 12);

    final inner = List<ui.Offset>.generate(outer.length, (i) {
      final p = outer[i];
      final t = i / (outer.length - 1);
      
      final curveBias = (1.0 - t * 0.7) * 0.07;
      final curveOffset = left ? -faceW * curveBias : faceW * curveBias;
      
      final px = p.dx + biasX + curveOffset;
      return ui.Offset(px + inward * dirXToCenter, p.dy - liftY);
    });

    final region = _buildRegionFromOuterInner(outer, inner);

    final center = cheekAnchor;
    
    var radius = faceW * 0.22 * widthFactor;
    
    final eyeBottom = _getEyeBottom(left);
    if (eyeBottom != null && center.dy < eyeBottom + faceH * 0.05) {
      radius *= 0.85;
    }
    
    final saveBounds = region.getBounds().inflate(radius * 0.70);

    _renderLayeredBlush(
      canvas: canvas,
      region: region,
      center: center,
      radius: radius,
      saveBounds: saveBounds,
      kCore: kCore,
      sigmaSoft: sigmaSoft,
      sigmaFeather: sigmaFeather,
      sigmaDiffuse: sigmaDiffuse,
      left: left,
      coreOpacityMultiplier: coreOpacityMultiplier,
      yawFactor: yawFactor,
      darkT: darkT,
      blushColor: blushColor,
      blushProfile: blushProfile,
    );
  }

  void _drawCheekFromFaceOvalBand({
    required Canvas canvas,
    required List<ui.Offset> faceOval,
    required Rect box,
    required double cheekYFactor,
    required double lift,
    required double widthFactor,
    required double inwardFactor,
    required double kCore,
    required double sigmaSoft,
    required double sigmaFeather,
    required double sigmaDiffuse,
    required bool left,
    required double noseCenterX,
    required ui.Offset cheekAnchor,
    required double yawFactor,
    required double coreOpacityMultiplier,
    required double darkT,
    required Color blushColor,
    required BlushStyleProfile blushProfile,
  }) {
    final faceW = box.width;
    final faceH = box.height;

    final sidePts = faceOval.where((p) => left ? (p.dx <= box.center.dx) : (p.dx >= box.center.dx)).toList();
    if (sidePts.length < 6) return;

    sidePts.sort((a, b) => a.dy.compareTo(b.dy));

    final targetY = box.top + faceH * cheekYFactor;
    final bandTop = targetY - faceH * 0.10;
    final bandBot = targetY + faceH * 0.11;

    final band = sidePts.where((p) => p.dy >= bandTop && p.dy <= bandBot).toList();
    final outer = _resample(band.length >= 6 ? band : sidePts, 12);

    final sideSign = left ? -1.0 : 1.0;
    final noseBias = ((box.center.dx - noseCenterX) / max(1.0, faceW)).clamp(-0.18, 0.18);
    final biasX = noseBias * faceW * 0.22 * sideSign;

    final inward = faceW * 0.12 * widthFactor * inwardFactor;
    final liftY = faceH * 0.04 * lift;
    final dirXToCenter = left ? 1.0 : -1.0;

    final inner = List<ui.Offset>.generate(outer.length, (i) {
      final p = outer[i];
      final t = i / (outer.length - 1);
      
      final curveBias = (1.0 - t * 0.7) * 0.05;
      final curveOffset = left ? -faceW * curveBias : faceW * curveBias;
      
      final px = p.dx + biasX + curveOffset;
      return ui.Offset(px + inward * dirXToCenter, p.dy - liftY);
    });

    final region = _buildRegionFromOuterInner(outer, inner);

    final center = cheekAnchor;
    
    var radius = faceW * 0.24 * widthFactor;
    
    final eyeBottom = _getEyeBottom(left);
    if (eyeBottom != null && center.dy < eyeBottom + faceH * 0.05) {
      radius *= 0.85;
    }
    
    final saveBounds = region.getBounds().inflate(radius * 0.70);

    _renderLayeredBlush(
      canvas: canvas,
      region: region,
      center: center,
      radius: radius,
      saveBounds: saveBounds,
      kCore: kCore,
      sigmaSoft: sigmaSoft,
      sigmaFeather: sigmaFeather,
      sigmaDiffuse: sigmaDiffuse,
      left: left,
      coreOpacityMultiplier: coreOpacityMultiplier,
      yawFactor: yawFactor,
      darkT: darkT,
      blushColor: blushColor,
      blushProfile: blushProfile,
    );
  }

  void _fallbackBlush({
    required Canvas canvas,
    required Rect box,
    required double faceW,
    required double faceH,
    required double cheekYFactor,
    required double lift,
    required double widthFactor,
    required double kCore,
    required double kEdge,
    required double sigmaSoft,
    required double sigmaFeather,
    required double darkT,
    required Color blushColor,
    required double coreOpacityMultiplier,
    required BlushStyleProfile blushProfile,
  }) {
    void draw(bool left) {
      final cx = left ? (box.left + faceW * 0.30) : (box.left + faceW * 0.70);
      final cy = box.top + faceH * cheekYFactor;

      final patchW = faceW * 0.28 * widthFactor;
      final patchH = faceH * 0.15;

      final tilt = left ? -1.0 : 1.0;
      final dxTemple = faceW * 0.12 * tilt * lift;
      final dyTemple = -faceH * 0.065 * lift;

      final p1 = ui.Offset(cx - patchW * 0.50, cy + patchH * 0.20);
      final p2 = ui.Offset(cx + patchW * 0.22, cy - patchH * 0.24);
      final p3 = ui.Offset(cx + dxTemple, cy + dyTemple);

      final region = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(p2.dx, p2.dy, p3.dx, p3.dy)
        ..quadraticBezierTo(cx, cy + patchH * 0.40, p1.dx, p1.dy)
        ..close();

      final r = max(patchW, patchH) * 1.10;
      final saveBounds = region.getBounds().inflate(r * 0.55);

      _renderLayeredBlush(
        canvas: canvas,
        region: region,
        center: ui.Offset(cx, cy),
        radius: r,
        saveBounds: saveBounds,
        kCore: kCore,
        sigmaSoft: sigmaSoft,
        sigmaFeather: sigmaFeather,
        sigmaDiffuse: sigmaFeather * 1.3,
        left: left,
        coreOpacityMultiplier: coreOpacityMultiplier,
        yawFactor: 0.0,
        darkT: darkT,
        blushColor: blushColor,
        blushProfile: blushProfile,
      );
    }

    draw(true);
    draw(false);
  }

  // -----------------------------
  // Helper methods
  // -----------------------------
  List<ui.Offset> _contourOffsets(List<Point<int>>? pts) {
    if (pts == null || pts.isEmpty) return const [];
    return pts.map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())).toList();
  }

  double _computeAutoBoost({required Color blush, required Color? skin}) {
    final blushL = _luminance01(blush);
    final blushSat = _saturation01(blush);

    double skinL = 0.55;
    if (skin != null) skinL = _luminance01(skin);

    final skinBrightBoost =
        ui.lerpDouble(1.0, 1.22, ((skinL - 0.52) / 0.30).clamp(0.0, 1.0))!;
    final blushLightBoost =
        ui.lerpDouble(1.0, 1.28, ((blushL - 0.55) / 0.35).clamp(0.0, 1.0))!;
    final lowSatBoost =
        ui.lerpDouble(1.0, 1.18, ((0.38 - blushSat) / 0.38).clamp(0.0, 1.0))!;

    return (skinBrightBoost * blushLightBoost * lowSatBoost).clamp(1.0, 1.45);
  }

  double _luminance01(Color c) {
    final r = c.red / 255.0;
    final g = c.green / 255.0;
    final b = c.blue / 255.0;
    return (0.2126 * r + 0.7152 * g + 0.0722 * b).clamp(0.0, 1.0);
  }

  double _saturation01(Color c) {
    final r = c.red / 255.0;
    final g = c.green / 255.0;
    final b = c.blue / 255.0;
    final maxV = max(r, max(g, b));
    final minV = min(r, min(g, b));
    final delta = maxV - minV;
    if (maxV <= 0.0001) return 0.0;
    return (delta / maxV).clamp(0.0, 1.0);
  }

  Color _shiftHsl(Color c, {double hueDelta = 0, double satMul = 1.0, double lightMul = 1.0}) {
    final hsl = HSLColor.fromColor(c);
    final h = (hsl.hue + hueDelta) % 360.0;
    final s = (hsl.saturation * satMul).clamp(0.0, 1.0);
    final l = (hsl.lightness * lightMul).clamp(0.0, 1.0);
    return hsl.withHue(h).withSaturation(s).withLightness(l).toColor();
  }

  double _estimateNoseCenterX(Face face, Rect box) {
    final noseBottom = face.contours[FaceContourType.noseBottom]?.points;
    if (noseBottom != null && noseBottom.isNotEmpty) {
      double sx = 0;
      for (final p in noseBottom) {
        sx += p.x.toDouble();
      }
      return sx / noseBottom.length;
    }
    return box.center.dx;
  }

  Path _buildSmoothClosedPath(List<ui.Offset> pts, {required int targetPoints}) {
    final s = _resample(pts, targetPoints);
    final path = Path()..moveTo(s.first.dx, s.first.dy);
    _addSmoothCurve(path, s, closed: true);
    path.close();
    return path;
  }

  Path _buildRegionFromOuterInner(List<ui.Offset> outer, List<ui.Offset> inner) {
    final region = Path();
    region.moveTo(outer.first.dx, outer.first.dy);
    _addSmoothCurve(region, outer, closed: false);
    for (int i = inner.length - 1; i >= 0; i--) {
      region.lineTo(inner[i].dx, inner[i].dy);
    }
    region.close();
    return region;
  }

  void _addSmoothCurve(Path path, List<ui.Offset> pts, {bool closed = false}) {
    if (pts.length < 3) {
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      return;
    }

    final n = pts.length;
    for (int i = 0; i < n - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final mid = ui.Offset((p0.dx + p1.dx) * 0.5, (p0.dy + p1.dy) * 0.5);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }

    if (closed) {
      final pLast = pts[n - 1];
      final pFirst = pts[0];
      final mid = ui.Offset((pLast.dx + pFirst.dx) * 0.5, (pLast.dy + pFirst.dy) * 0.5);
      path.quadraticBezierTo(pLast.dx, pLast.dy, mid.dx, mid.dy);
    } else {
      path.lineTo(pts.last.dx, pts.last.dy);
    }
  }

  List<ui.Offset> _resample(List<ui.Offset> pts, int n) {
    if (pts.isEmpty) return pts;
    if (pts.length <= n) return pts;

    final out = <ui.Offset>[];
    final step = (pts.length - 1) / (n - 1);

    for (int i = 0; i < n; i++) {
      final idx = i * step;
      final a = idx.floor();
      final b = min(pts.length - 1, a + 1);
      final t = idx - a;

      final pa = pts[a];
      final pb = pts[b];

      out.add(ui.Offset(
        ui.lerpDouble(pa.dx, pb.dx, t)!,
        ui.lerpDouble(pa.dy, pb.dy, t)!,
      ));
    }
    return out;
  }

  ui.Offset _average(List<ui.Offset> pts) {
    double sx = 0, sy = 0;
    for (final p in pts) {
      sx += p.dx;
      sy += p.dy;
    }
    return ui.Offset(sx / pts.length, sy / pts.length);
  }

  Rect _boundsOf(List<ui.Offset> pts) {
    if (pts.isEmpty) return Rect.zero;
    double minX = pts.first.dx, maxX = pts.first.dx;
    double minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts.skip(1)) {
      minX = min(minX, p.dx);
      maxX = max(maxX, p.dx);
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  double _getEyeBottomFromContour(List<ui.Offset> eyeContour) {
    if (eyeContour.isEmpty) return double.infinity;
    double maxY = eyeContour.first.dy;
    for (final p in eyeContour) {
      if (p.dy > maxY) maxY = p.dy;
    }
    return maxY;
  }

  double _getMouthTopFromContour(List<ui.Offset> mouthContour) {
    if (mouthContour.isEmpty) return 0;
    double minY = mouthContour.first.dy;
    for (final p in mouthContour) {
      if (p.dy < minY) minY = p.dy;
    }
    return minY;
  }

  double? _getEyeBottom(bool left) {
    final eyeContourType = left ? FaceContourType.leftEye : FaceContourType.rightEye;
    final eyeContour = _contourOffsets(face.contours[eyeContourType]?.points);
    if (eyeContour.isNotEmpty) {
      return _getEyeBottomFromContour(eyeContour);
    }
    return null;
  }

  // EMA smoothing for point list (now conditional)
  List<ui.Offset> _smoothPoints(List<ui.Offset> pts, int key, {double alpha = 0.18}) {
    if (!isLiveMode) return pts;
    
    final prev = _ovalSmoothers[key];
    if (prev == null || prev.length != pts.length) {
      _ovalSmoothers[key] = List<ui.Offset>.from(pts);
      return pts;
    }
    final out = <ui.Offset>[];
    for (int i = 0; i < pts.length; i++) {
      final p = pts[i];
      final q = prev[i];
      out.add(ui.Offset(
        q.dx + (p.dx - q.dx) * alpha,
        q.dy + (p.dy - q.dy) * alpha,
      ));
    }
    _ovalSmoothers[key] = out;
    return out;
  }
}