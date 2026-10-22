import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class FaceAnalysisResult {
  final bool hasFace;
  final String? errorMessage;
  final Face? face;
  final Uint8List? croppedFaceBytes;
  final String? croppedFaceBase64;
  final int originalWidth;
  final int originalHeight;
  final Rect? faceBoundingBox;
  final List<double> biometricRatios;
  final Map<FaceContourType, List<Offset>> contours;
  final Map<FaceLandmarkType, Offset> landmarks;

  FaceAnalysisResult({
    required this.hasFace,
    this.errorMessage,
    this.face,
    this.croppedFaceBytes,
    this.croppedFaceBase64,
    this.originalWidth = 0,
    this.originalHeight = 0,
    this.faceBoundingBox,
    this.biometricRatios = const [],
    this.contours = const {},
    this.landmarks = const {},
  });
}

class FaceDetectorService {
  static final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
    ),
  );

  /// Phân tích ảnh, phát hiện khuôn mặt, cắt khuôn mặt (loại bỏ bối cảnh)
  /// và trích xuất khung xương (landmarks & contours)
  static Future<FaceAnalysisResult> analyzeAndCropFace(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return FaceAnalysisResult(hasFace: false, errorMessage: 'Tập tin ảnh không tồn tại.');
      }

      final rawBytes = await file.readAsBytes();
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        return FaceAnalysisResult(hasFace: false, errorMessage: 'Không thể giải mã định dạng ảnh.');
      }

      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _detector.processImage(inputImage);

      if (faces.isEmpty) {
        return FaceAnalysisResult(
          hasFace: false,
          errorMessage: 'Không phát hiện thấy khuôn mặt người trong ảnh! Vui lòng chụp rõ khuôn mặt chính diện, không chụp vật thể hay bối cảnh.',
        );
      }

      if (faces.length > 1) {
        // Cảnh báo nếu có nhiều khuôn mặt
        return FaceAnalysisResult(
          hasFace: false,
          errorMessage: 'Phát hiện ${faces.length} khuôn mặt trong khung hình! Vui lòng chỉ đứng một mình trước camera để bảo đảm an toàn sinh trắc học.',
        );
      }

      final face = faces.first;
      final bbox = face.boundingBox;

      // Trích xuất contours và landmarks
      final Map<FaceContourType, List<Offset>> contours = {};
      for (final type in FaceContourType.values) {
        final contour = face.contours[type];
        if (contour != null && contour.points.isNotEmpty) {
          contours[type] = contour.points.map((p) => Offset(p.x.toDouble(), p.y.toDouble())).toList();
        }
      }

      final Map<FaceLandmarkType, Offset> landmarks = {};
      for (final type in FaceLandmarkType.values) {
        final lm = face.landmarks[type];
        if (lm != null) {
          landmarks[type] = Offset(lm.position.x.toDouble(), lm.position.y.toDouble());
        }
      }

      // 1. CẮT DUY NHẤT VÙNG KHUÔN MẶT (Loại bỏ 100% bối cảnh xung quanh)
      final padX = (bbox.width * 0.12).round();
      final padY = (bbox.height * 0.15).round();

      final cropX = (bbox.left.toInt() - padX).clamp(0, decoded.width - 1);
      final cropY = (bbox.top.toInt() - padY).clamp(0, decoded.height - 1);
      final cropW = (bbox.width.toInt() + padX * 2).clamp(1, decoded.width - cropX);
      final cropH = (bbox.height.toInt() + padY * 2).clamp(1, decoded.height - cropY);

      final cropped = img.copyCrop(decoded, x: cropX, y: cropY, width: cropW, height: cropH);
      final resized = img.copyResize(cropped, width: 256, height: 256);
      final croppedJpgBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 88));
      final croppedBase64 = base64Encode(croppedJpgBytes);

      // 2. TÍNH TOÁN VÉC-TƠ TỶ LỆ HÌNH HỌC SINH TRẮC HỌC (Biometric Landmark Vector)
      final ratios = _calculateBiometricRatios(landmarks, bbox);

      return FaceAnalysisResult(
        hasFace: true,
        face: face,
        croppedFaceBytes: croppedJpgBytes,
        croppedFaceBase64: croppedBase64,
        originalWidth: decoded.width,
        originalHeight: decoded.height,
        faceBoundingBox: bbox,
        biometricRatios: ratios,
        contours: contours,
        landmarks: landmarks,
      );
    } catch (e) {
      return FaceAnalysisResult(
        hasFace: false,
        errorMessage: 'Lỗi phân tích nhận diện khuôn mặt: $e',
      );
    }
  }

  static List<double> _calculateBiometricRatios(Map<FaceLandmarkType, Offset> landmarks, Rect bbox) {
    try {
      final leftEye = landmarks[FaceLandmarkType.leftEye];
      final rightEye = landmarks[FaceLandmarkType.rightEye];
      final noseBase = landmarks[FaceLandmarkType.noseBase];
      final leftMouth = landmarks[FaceLandmarkType.leftMouth];
      final rightMouth = landmarks[FaceLandmarkType.rightMouth];
      final bottomMouth = landmarks[FaceLandmarkType.bottomMouth];

      if (leftEye != null && rightEye != null) {
        final eyeDist = (rightEye - leftEye).distance;
        if (eyeDist > 5) {
          final midEye = Offset((leftEye.dx + rightEye.dx) / 2, (leftEye.dy + rightEye.dy) / 2);
          final eyeNoseDist = noseBase != null ? (noseBase - midEye).distance : 0.0;
          final mouthWidth = (leftMouth != null && rightMouth != null) ? (rightMouth - leftMouth).distance : 0.0;
          final noseMouthDist = (noseBase != null && bottomMouth != null) ? (bottomMouth - noseBase).distance : 0.0;
          final faceAspect = bbox.height / (bbox.width > 0 ? bbox.width : 1.0);

          return [
            eyeNoseDist / eyeDist,
            mouthWidth / eyeDist,
            noseMouthDist / eyeDist,
            faceAspect,
          ];
        }
      }
    } catch (_) {}
    return [1.0, 0.8, 0.6, 1.3];
  }
}
