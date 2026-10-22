import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/face_detector_service.dart';

class FaceMeshOverlay extends StatelessWidget {
  final Uint8List imageBytes;
  final FaceAnalysisResult? analysis;
  final double width;
  final double height;
  final bool showSkeleton;
  final String label;

  const FaceMeshOverlay({
    super.key,
    required this.imageBytes,
    this.analysis,
    this.width = 140,
    this.height = 140,
    this.showSkeleton = true,
    this.label = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (analysis != null && analysis!.hasFace)
                  ? const Color(0xFF00E5FF)
                  : Colors.grey.shade400,
              width: 2.0,
            ),
            boxShadow: [
              if (showSkeleton && analysis != null && analysis!.hasFace)
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Ảnh khuôn mặt đã cắt (Không còn bối cảnh)
                Image.memory(
                  imageBytes,
                  fit: BoxFit.cover,
                ),

                // 2. Lớp phủ Khung xương sinh trắc học (Biometric Skeleton / Face Mesh)
                if (showSkeleton && analysis != null && analysis!.hasFace)
                  CustomPaint(
                    size: Size(width, height),
                    painter: _SkeletonMeshPainter(
                      analysis: analysis!,
                      containerSize: Size(width, height),
                    ),
                  ),

                // 3. Radar HUD scanline effect
                if (showSkeleton && analysis != null && analysis!.hasFace)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF00E5FF), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hub, size: 10, color: Color(0xFF00E5FF)),
                          SizedBox(width: 3),
                          Text(
                            'MESH ON',
                            style: TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ],
      ],
    );
  }
}

class _SkeletonMeshPainter extends CustomPainter {
  final FaceAnalysisResult analysis;
  final Size containerSize;

  _SkeletonMeshPainter({
    required this.analysis,
    required this.containerSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bbox = analysis.faceBoundingBox;
    if (bbox == null || analysis.originalWidth <= 0 || analysis.originalHeight <= 0) {
      _drawDefaultSyntheticMesh(canvas, size);
      return;
    }

    // Tọa độ đã cắt có padding 12% X và 15% Y quanh bounding box
    final padX = bbox.width * 0.12;
    final padY = bbox.height * 0.15;
    final cropLeft = (bbox.left - padX).clamp(0.0, analysis.originalWidth.toDouble());
    final cropTop = (bbox.top - padY).clamp(0.0, analysis.originalHeight.toDouble());
    final cropW = (bbox.width + padX * 2).clamp(1.0, analysis.originalWidth - cropLeft);
    final cropH = (bbox.height + padY * 2).clamp(1.0, analysis.originalHeight - cropTop);

    Offset mapPoint(Offset orig) {
      final normX = (orig.dx - cropLeft) / cropW;
      final normY = (orig.dy - cropTop) / cropH;
      return Offset(
        (normX * size.width).clamp(0.0, size.width),
        (normY * size.height).clamp(0.0, size.height),
      );
    }

    final meshPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.85)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    final landmarkDotPaint = Paint()
      ..color = const Color(0xFF00FF88)
      ..style = PaintingStyle.fill;

    final landmarkGlowPaint = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final triangulationPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.35)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // 1. Vẽ các đường Contours (Đường nét khung xương giải phẫu)
    void drawContourPoly(List<Offset>? points, {bool isClosed = false}) {
      if (points == null || points.length < 2) return;
      final path = Path();
      final first = mapPoint(points.first);
      path.moveTo(first.dx, first.dy);
      for (int i = 1; i < points.length; i++) {
        final p = mapPoint(points[i]);
        path.lineTo(p.dx, p.dy);
      }
      if (isClosed) path.close();
      canvas.drawPath(path, meshPaint);
    }

    // Vẽ xương hàm (Face Oval)
    drawContourPoly(analysis.contours[FaceContourType.face]);

    // Vẽ cung lông mày
    drawContourPoly(analysis.contours[FaceContourType.leftEyebrowTop]);
    drawContourPoly(analysis.contours[FaceContourType.leftEyebrowBottom]);
    drawContourPoly(analysis.contours[FaceContourType.rightEyebrowTop]);
    drawContourPoly(analysis.contours[FaceContourType.rightEyebrowBottom]);

    // Vẽ mắt trái và mắt phải
    drawContourPoly(analysis.contours[FaceContourType.leftEye], isClosed: true);
    drawContourPoly(analysis.contours[FaceContourType.rightEye], isClosed: true);

    // Vẽ sống mũi & đáy mũi
    drawContourPoly(analysis.contours[FaceContourType.noseBridge]);
    drawContourPoly(analysis.contours[FaceContourType.noseBottom]);

    // Vẽ môi trên & môi dưới
    drawContourPoly(analysis.contours[FaceContourType.upperLipTop]);
    drawContourPoly(analysis.contours[FaceContourType.upperLipBottom]);
    drawContourPoly(analysis.contours[FaceContourType.lowerLipTop]);
    drawContourPoly(analysis.contours[FaceContourType.lowerLipBottom]);

    // 2. Vẽ Lưới tam giác liên kết sinh trắc học (Triangulation Mesh - Khung xương đa giác 3D)
    final leftEye = analysis.landmarks[FaceLandmarkType.leftEye];
    final rightEye = analysis.landmarks[FaceLandmarkType.rightEye];
    final noseBase = analysis.landmarks[FaceLandmarkType.noseBase];
    final leftMouth = analysis.landmarks[FaceLandmarkType.leftMouth];
    final rightMouth = analysis.landmarks[FaceLandmarkType.rightMouth];
    final bottomMouth = analysis.landmarks[FaceLandmarkType.bottomMouth];
    final leftCheek = analysis.landmarks[FaceLandmarkType.leftCheek];
    final rightCheek = analysis.landmarks[FaceLandmarkType.rightCheek];

    if (leftEye != null && rightEye != null && noseBase != null) {
      final pLE = mapPoint(leftEye);
      final pRE = mapPoint(rightEye);
      final pN = mapPoint(noseBase);

      // Tam giác giữa hai mắt và mũi
      canvas.drawLine(pLE, pRE, triangulationPaint);
      canvas.drawLine(pLE, pN, triangulationPaint);
      canvas.drawLine(pRE, pN, triangulationPaint);

      // Liên kết mũi với khóe miệng
      if (leftMouth != null && rightMouth != null) {
        final pLM = mapPoint(leftMouth);
        final pRM = mapPoint(rightMouth);
        canvas.drawLine(pN, pLM, triangulationPaint);
        canvas.drawLine(pN, pRM, triangulationPaint);
        canvas.drawLine(pLM, pRM, triangulationPaint);

        if (bottomMouth != null) {
          final pBM = mapPoint(bottomMouth);
          canvas.drawLine(pLM, pBM, triangulationPaint);
          canvas.drawLine(pRM, pBM, triangulationPaint);
        }
      }

      // Liên kết gò má với mắt và mũi
      if (leftCheek != null) {
        final pLC = mapPoint(leftCheek);
        canvas.drawLine(pLE, pLC, triangulationPaint);
        canvas.drawLine(pN, pLC, triangulationPaint);
      }
      if (rightCheek != null) {
        final pRC = mapPoint(rightCheek);
        canvas.drawLine(pRE, pRC, triangulationPaint);
        canvas.drawLine(pN, pRC, triangulationPaint);
      }
    }

    // 3. Vẽ các điểm nút sinh trắc học (Glowing Landmark Nodes)
    for (final entry in analysis.landmarks.entries) {
      final p = mapPoint(entry.value);
      canvas.drawCircle(p, 4.5, landmarkGlowPaint);
      canvas.drawCircle(p, 2.2, landmarkDotPaint);
    }

    // 4. Vẽ khung ngắm HUD 4 góc (Biometric Target Box)
    _drawTargetCorners(canvas, size);
  }

  void _drawDefaultSyntheticMesh(Canvas canvas, Size size) {
    // Vẽ khung xương mẫu chuẩn 3D nếu chưa trích xuất được landmarks chi tiết
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.7)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFF00FF88)
      ..style = PaintingStyle.fill;

    // Oval mặt
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.52), width: w * 0.65, height: h * 0.82),
      paint,
    );

    // Mắt
    final pLeftEye = Offset(w * 0.36, h * 0.42);
    final pRightEye = Offset(w * 0.64, h * 0.42);
    canvas.drawOval(Rect.fromCenter(center: pLeftEye, width: w * 0.16, height: h * 0.08), paint);
    canvas.drawOval(Rect.fromCenter(center: pRightEye, width: w * 0.16, height: h * 0.08), paint);

    // Mũi
    final pNose = Offset(w * 0.5, h * 0.56);
    final nosePath = Path()
      ..moveTo(w * 0.5, h * 0.42)
      ..lineTo(w * 0.5, h * 0.56)
      ..lineTo(w * 0.44, h * 0.59)
      ..lineTo(w * 0.56, h * 0.59)
      ..close();
    canvas.drawPath(nosePath, paint);

    // Miệng
    final pMouth = Offset(w * 0.5, h * 0.72);
    canvas.drawOval(Rect.fromCenter(center: pMouth, width: w * 0.28, height: h * 0.09), paint);

    // Liên kết lưới tam giác
    final triPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.3)
      ..strokeWidth = 0.8;

    canvas.drawLine(pLeftEye, pRightEye, triPaint);
    canvas.drawLine(pLeftEye, pNose, triPaint);
    canvas.drawLine(pRightEye, pNose, triPaint);
    canvas.drawLine(pNose, Offset(w * 0.38, h * 0.72), triPaint);
    canvas.drawLine(pNose, Offset(w * 0.62, h * 0.72), triPaint);
    canvas.drawLine(Offset(w * 0.5, h * 0.76), Offset(w * 0.5, h * 0.88), triPaint);

    // Nút điểm
    canvas.drawCircle(pLeftEye, 2.5, dotPaint);
    canvas.drawCircle(pRightEye, 2.5, dotPaint);
    canvas.drawCircle(pNose, 2.5, dotPaint);
    canvas.drawCircle(pMouth, 2.5, dotPaint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.88), 2.5, dotPaint);

    _drawTargetCorners(canvas, size);
  }

  void _drawTargetCorners(Canvas canvas, Size size) {
    final cornerPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    const len = 12.0;
    const margin = 4.0;
    final w = size.width;
    final h = size.height;

    // Top-Left
    canvas.drawLine(const Offset(margin, margin), const Offset(margin + len, margin), cornerPaint);
    canvas.drawLine(const Offset(margin, margin), const Offset(margin, margin + len), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(w - margin, margin), Offset(w - margin - len, margin), cornerPaint);
    canvas.drawLine(Offset(w - margin, margin), Offset(w - margin, margin + len), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(margin, h - margin), Offset(margin + len, h - margin), cornerPaint);
    canvas.drawLine(Offset(margin, h - margin), Offset(margin, h - margin - len), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(w - margin, h - margin), Offset(w - margin - len, h - margin), cornerPaint);
    canvas.drawLine(Offset(w - margin, h - margin), Offset(w - margin, h - margin - len), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _SkeletonMeshPainter oldDelegate) => true;
}
