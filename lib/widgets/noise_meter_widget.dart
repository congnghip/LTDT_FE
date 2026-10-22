import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/noise_meter_service.dart';

class NoiseMeterWidget extends StatefulWidget {
  final Function(double db)? onRecordNoise;
  final bool compactMode;

  const NoiseMeterWidget({
    super.key,
    this.onRecordNoise,
    this.compactMode = false,
  });

  @override
  State<NoiseMeterWidget> createState() => _NoiseMeterWidgetState();
}

class _NoiseMeterWidgetState extends State<NoiseMeterWidget> with SingleTickerProviderStateMixin {
  final NoiseMeterService _service = NoiseMeterService();
  StreamSubscription<NoiseReading>? _sub;

  double _currentDb = 26.0;
  String _safetyLevel = 'Đang kết nối micro...';
  String _safetyAdvice = 'Hệ thống đang lắng nghe âm thanh môi trường thực tế.';
  Color _statusColor = Colors.green;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    if (_service.currentDb > 0) {
      final initial = NoiseMeterService.evaluateNoise(_service.currentDb);
      _currentDb = initial.decibels;
      _safetyLevel = initial.safetyLevel;
      _safetyAdvice = initial.safetyAdvice;
      _statusColor = initial.statusColor;
    }

    _service.start();
    _sub = _service.noiseStream.listen((reading) {
      if (mounted) {
        setState(() {
          _currentDb = reading.decibels;
          _safetyLevel = reading.safetyLevel;
          _safetyAdvice = reading.safetyAdvice;
          _statusColor = reading.statusColor;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compactMode) {
      return _buildCompactCard();
    }
    return _buildFullView();
  }

  // Chế độ thẻ nhỏ gọn đặt trên Dashboard Chấm công
  Widget _buildCompactCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [_statusColor.withValues(alpha: 0.12), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: _statusColor.withValues(alpha: 0.4), width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.graphic_eq, color: _statusColor, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      const Text(
                        'Độ ồn môi trường:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black54),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: _statusColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _safetyLevel,
                          style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _currentDb.toStringAsFixed(1),
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _statusColor),
                      ),
                      const SizedBox(width: 4),
                      const Text('dB (Decibel)', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.onRecordNoise != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Lưu dB', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _statusColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => widget.onRecordNoise!(_currentDb),
              ),
          ],
        ),
      ),
    );
  }

  // Chế độ trạm đo đầy đủ (Đo micro thực tế - Không dùng demo)
  Widget _buildFullView() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
        child: Column(
          children: [
            // 1. Banner Tiêu đề & Giới thiệu chuẩn QCVN
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade800, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.indigo.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.volume_up, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GIÁM SÁT TIẾNG ỒN MÔI TRƯỜNG',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        Text(
                          'Quy chuẩn QCVN 24:2016/BYT & QCVN 26:2010/BTNMT',
                          style: TextStyle(color: Colors.white70, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 2. Thanh trạng thái Micro Live thực tế
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _service.isMeasuring ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _service.isMeasuring ? Colors.green.shade300 : Colors.grey.shade400,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _service.isMeasuring ? Colors.green.shade600 : Colors.grey,
                      shape: BoxShape.circle,
                      boxShadow: _service.isMeasuring
                          ? [BoxShadow(color: Colors.green.withValues(alpha: 0.6), blurRadius: 4, spreadRadius: 1.5)]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _service.isMeasuring ? 'Micro đang đo âm thanh thực tế' : 'Đã tạm dừng đo',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: _service.isMeasuring ? Colors.green.shade800 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      _service.togglePause();
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _service.isMeasuring ? Icons.pause : Icons.play_arrow,
                            size: 13,
                            color: Colors.indigo,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _service.isMeasuring ? 'Tạm dừng' : 'Tiếp tục',
                            style: const TextStyle(fontSize: 10.5, color: Colors.indigo, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 3. ĐỒNG HỒ ĐO DECIBEL (GAUGE METER TRÒN)
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 185,
                    height: 185,
                    child: CustomPaint(
                      painter: _NoiseGaugePainter(
                        currentDb: _currentDb,
                        maxDb: 120.0,
                        activeColor: _statusColor,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic, color: _statusColor, size: 22),
                      const SizedBox(height: 2),
                      Text(
                        _currentDb.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: _statusColor,
                          letterSpacing: -1,
                        ),
                      ),
                      const Text(
                        'dBA (SPL)',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(color: _statusColor.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 1.5)),
                          ],
                        ),
                        child: Text(
                          _safetyLevel,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 4. LỜI KHUYÊN VÀ KHUYẾN NGHỊ AN TOÀN
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: _statusColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _safetyAdvice,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey[800], height: 1.25),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),



            // 6. THỐNG KÊ ĐO: MIN - AVG - MAX (Có nút Reset)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.analytics_outlined, size: 16, color: Colors.indigo),
                            SizedBox(width: 6),
                            Text(
                              'Thống kê đo âm thanh ca làm việc:',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            _service.resetStats();
                            setState(() {
                              _currentDb = _service.currentDb;
                            });
                          },
                          child: const Row(
                            children: [
                              Icon(Icons.refresh, size: 13, color: Colors.indigo),
                              SizedBox(width: 2),
                              Text('Reset', style: TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatTile('Thấp nhất (Min)', '${_service.minDb.toStringAsFixed(1)} dB', Colors.green),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildStatTile('Trung bình (Avg)', '${_service.avgDb.toStringAsFixed(1)} dB', Colors.blue),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildStatTile('Cao nhất (Peak)', '${_service.maxDb.toStringAsFixed(1)} dB', Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 7. NÚT GHI NHẬN MỨC ĐỘ ỒN
            if (widget.onRecordNoise != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                  label: Text(
                    'Ghi nhận độ ồn (${_currentDb.toStringAsFixed(1)} dB) vào ca làm việc',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _statusColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 3,
                  ),
                  onPressed: () => widget.onRecordNoise!(_currentDb),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter vẽ kim và vòng cung đo Decibel chuyên nghiệp
class _NoiseGaugePainter extends CustomPainter {
  final double currentDb;
  final double maxDb;
  final Color activeColor;

  _NoiseGaugePainter({
    required this.currentDb,
    required this.maxDb,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    const startAngle = 135 * (pi / 180);
    const sweepAngle = 270 * (pi / 180);

    // 1. Vẽ vòng cung nền mờ
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // 2. Vẽ vòng cung tiến độ tương ứng Decibel hiện tại
    final progress = (currentDb / maxDb).clamp(0.0, 1.0);
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      activePaint,
    );

    // 3. Vạch chia Decibel (Ticks: 0, 30, 60, 85, 120)
    final tickPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.5;

    for (int i = 0; i <= 12; i++) {
      final angle = startAngle + (sweepAngle * (i / 12));
      final innerR = radius - (i % 3 == 0 ? 11 : 7);
      final outerR = radius - 2;

      final p1 = Offset(center.dx + innerR * cos(angle), center.dy + innerR * sin(angle));
      final p2 = Offset(center.dx + outerR * cos(angle), center.dy + outerR * sin(angle));
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoiseGaugePainter oldDelegate) {
    return oldDelegate.currentDb != currentDb || oldDelegate.activeColor != activeColor;
  }
}
