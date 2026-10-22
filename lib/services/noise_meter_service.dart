import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NoiseReading {
  final double decibels;
  final String safetyLevel;
  final String safetyAdvice;
  final Color statusColor;
  final DateTime timestamp;

  NoiseReading({
    required this.decibels,
    required this.safetyLevel,
    required this.safetyAdvice,
    required this.statusColor,
    required this.timestamp,
  });
}

class NoiseMeterService {
  static final NoiseMeterService _instance = NoiseMeterService._internal();
  factory NoiseMeterService() => _instance;
  NoiseMeterService._internal();

  static const MethodChannel _channel = MethodChannel('com.example.fb_interface/noise_meter');

  final StreamController<NoiseReading> _controller = StreamController<NoiseReading>.broadcast();
  Stream<NoiseReading> get noiseStream => _controller.stream;

  Timer? _timer;
  bool _isMeasuring = false;
  bool get isMeasuring => _isMeasuring;

  double _currentDb = 26.0;
  double get currentDb => _currentDb;

  double _maxDb = 0.0;
  double get maxDb => _maxDb;

  double _minDb = 999.0;
  double get minDb => _minDb == 999.0 ? 0.0 : _minDb;

  double _sumDb = 0.0;
  int _sampleCount = 0;
  double get avgDb => _sampleCount == 0 ? 0.0 : (_sumDb / _sampleCount);

  void togglePause() {
    if (_isMeasuring) {
      _timer?.cancel();
      _isMeasuring = false;
      _controller.add(evaluateNoise(_currentDb));
    } else {
      start();
    }
  }

  void _updateStats(double db) {
    if (db > _maxDb) _maxDb = db;
    if (_minDb == 999.0 || (db < _minDb && db > 0)) _minDb = db;
    _sumDb += db;
    _sampleCount++;
  }

  void resetStats() {
    _maxDb = _currentDb;
    _minDb = _currentDb > 0 ? _currentDb : 999.0;
    _sumDb = _currentDb;
    _sampleCount = _currentDb > 0 ? 1 : 0;
    _controller.add(evaluateNoise(_currentDb));
  }

  Future<bool> start() async {
    if (_isMeasuring) return true;

    try {
      final hasPerm = await _channel.invokeMethod<bool>('checkPermission') ?? false;
      if (!hasPerm) {
        await _channel.invokeMethod('requestPermission');
        Future.delayed(const Duration(milliseconds: 1200), () async {
          try {
            await _channel.invokeMethod('startNoiseMeter');
          } catch (_) {}
        });
      } else {
        await _channel.invokeMethod('startNoiseMeter');
      }
    } catch (e) {
      debugPrint("NoiseMeter Native start error: $e");
    }

    _isMeasuring = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 80), _onTick);
    return true;
  }

  Future<void> stop() async {
    _isMeasuring = false;
    _timer?.cancel();
    _timer = null;
    try {
      await _channel.invokeMethod('stopNoiseMeter');
    } catch (_) {}
  }

  Future<void> _onTick(Timer timer) async {
    double db = 26.0;

    try {
      final val = await _channel.invokeMethod<double>('getNoiseLevel');
      if (val != null && val > 0) {
        db = val;
      }
    } catch (e) {
      debugPrint("Noise meter read error: $e");
    }

    db = double.parse(db.toStringAsFixed(1));
    _currentDb = db;

    _updateStats(db);

    final reading = evaluateNoise(db);
    _controller.add(reading);
  }

  /// Đánh giá độ an toàn theo Quy chuẩn Kỹ thuật Quốc gia QCVN 24:2016/BYT (Tiếp xúc tiếng ồn tại nơi làm việc)
  static NoiseReading evaluateNoise(double db) {
    String level;
    String advice;
    Color color;

    if (db < 55.0) {
      level = 'An toàn (Yên tĩnh)';
      advice = 'Môi trường lý tưởng cho công việc văn phòng, tư duy và tập trung cao độ.';
      color = Colors.green;
    } else if (db <= 70.0) {
      level = 'Bình thường (Đạt chuẩn)';
      advice = 'Đạt chuẩn môi trường làm việc thông thường theo QCVN 24:2016/BYT (dưới 85 dBA).';
      color = Colors.blue;
    } else if (db <= 85.0) {
      level = 'Chú ý (Tiếng ồn cao)';
      advice = 'Tiếng ồn tương đương xưởng may, khu vực đông người. Cần hạn chế tiếp xúc quá 8 giờ liên tục.';
      color = Colors.orange;
    } else {
      level = 'CẢNH BÁO NGUY HẠI!';
      advice = 'VƯỢT NGƯỠNG AN TOÀN LAO ĐỘNG (>85 dBA)! Bắt buộc trang bị nút tai / chụp tai bảo hộ thính lực!';
      color = Colors.red;
    }

    return NoiseReading(
      decibels: db,
      safetyLevel: level,
      safetyAdvice: advice,
      statusColor: color,
      timestamp: DateTime.now(),
    );
  }
}
