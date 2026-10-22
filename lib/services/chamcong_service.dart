import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/app_models.dart';
import 'api_client.dart';

class ChamCongService {
  final ApiClient _client = ApiClient();

  // === 1. NGHIỆP VỤ CHẤM CÔNG ===

  // Chấm công vào (Face / GPS / QR) & Ghi nhận độ ồn môi trường làm việc
  Future<Map<String, dynamic>> checkIn({
    required String method,
    double? latitude,
    double? longitude,
    String? faceBase64,
    List<double>? biometricRatios,
    String? qrToken,
    int? shiftId,
    double? noiseLevelDb,
  }) async {
    try {
      final res = await _client.post('Attendance/check-in', body: {
        'method': method,
        'latitude': latitude,
        'longitude': longitude,
        'faceBase64': faceBase64,
        'biometricRatios': biometricRatios ?? [],
        'qrToken': qrToken,
        'shiftId': shiftId,
        'noiseLevelDb': noiseLevelDb,
      });

      final data = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200,
        'message': data['message'] ?? 'Chấm công hoàn tất',
        'data': data['data']
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  // Chấm công ra (Check-out) & Nhận lương thời gian thực
  Future<Map<String, dynamic>> checkOut({String? note}) async {
    try {
      final res = await _client.post('Attendance/check-out', body: {
        'note': note,
      });

      final data = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200,
        'message': data['message'] ?? 'Check-out hoàn tất',
        'data': data['data']
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  // Trạng thái chấm công hôm nay
  Future<Map<String, dynamic>> getTodayStatus() async {
    try {
      final res = await _client.get('Attendance/today');
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint("Error getTodayStatus: $e");
    }
    return {'hasCheckedIn': false, 'hasCheckedOut': false};
  }

  // Đặt lại chấm công hôm nay để test/demo
  Future<bool> resetToday() async {
    try {
      final res = await _client.post('Attendance/reset-today', body: {});
      return res.statusCode == 200;
    } catch (e) {
      debugPrint("Error resetToday: $e");
      return false;
    }
  }

  // Ghi nhận độ ồn môi trường vào ca làm việc (QCVN 24:2016/BYT)
  Future<Map<String, dynamic>> recordNoiseLevel(double db) async {
    try {
      final res = await _client.post('Attendance/record-noise', body: {
        'noiseLevelDb': db,
      });
      final data = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200,
        'message': data['message'] ?? 'Đã lưu độ ồn môi trường thành công',
        'data': data['data'],
      };
    } catch (e) {
      debugPrint("Error recordNoiseLevel: $e");
      return {'success': false, 'message': 'Lỗi lưu độ ồn: $e'};
    }
  }

  // Lịch sử chấm công cá nhân
  Future<Map<String, dynamic>> getPersonalHistory() async {
    try {
      final res = await _client.get('Attendance/history');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List<dynamic> list = data['records'] ?? [];
        return {
          'summary': data['summary'],
          'records': list.map((e) => AttendanceModel.fromJson(e)).toList(),
        };
      }
    } catch (e) {
      debugPrint("Error getPersonalHistory: $e");
    }
    return {'summary': null, 'records': <AttendanceModel>[]};
  }

  // Toàn bộ bảng chấm công (Admin/Manager)
  Future<List<AttendanceModel>> getAllAttendances({DateTime? date, String? department}) async {
    try {
      String endpoint = 'Attendance/all';
      List<String> params = [];
      if (date != null) params.add('date=${date.toIso8601String()}');
      if (department != null && department.isNotEmpty) params.add('department=$department');
      if (params.isNotEmpty) endpoint += '?${params.join('&')}';

      final res = await _client.get(endpoint);
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => AttendanceModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Error getAllAttendances: $e");
    }
    return [];
  }

  // Lấy mã Dynamic QR động đổi mỗi 15 giây
  Future<Map<String, dynamic>?> getDynamicQr() async {
    try {
      final res = await _client.get('Attendance/dynamic-qr');
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint("Error getDynamicQr: $e");
    }
    return null;
  }

  // === XÁC THỰC SINH TRẮC HỌC KHUÔN MẶT THẬT (REAL BIOMETRIC FACE MATCHING) ===

  // Đối chiếu so khớp khuôn mặt với ảnh hồ sơ gốc
  Future<Map<String, dynamic>> verifyFace(String faceBase64, {List<double>? biometricRatios}) async {
    try {
      final res = await _client.post('Attendance/verify-face', body: {
        'faceBase64': faceBase64,
        'biometricRatios': biometricRatios ?? [],
      });
      final data = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200 && (data['isMatch'] == true),
        'isMatch': data['isMatch'] ?? false,
        'similarity': (data['similarity'] as num?)?.toDouble() ?? 0.0,
        'message': data['message'] ?? 'Kết quả nhận diện khuôn mặt',
        'hasRegisteredFace': data['hasRegisteredFace'] ?? false,
        'registeredFaceBase64': data['registeredFaceBase64'],
        'employeeName': data['employeeName'] ?? '',
      };
    } catch (e) {
      return {'success': false, 'isMatch': false, 'similarity': 0.0, 'message': 'Lỗi xác thực khuôn mặt: $e'};
    }
  }

  // Đăng ký khuôn mặt chuẩn cho nhân viên (Face Enrollment)
  Future<Map<String, dynamic>> registerFace(String faceBase64) async {
    try {
      final res = await _client.post('Attendance/register-face', body: {
        'faceBase64': faceBase64,
      });
      final data = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200,
        'message': data['message'] ?? 'Đăng ký khuôn mặt thành công',
        'registeredFaceBase64': data['registeredFaceBase64'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi đăng ký khuôn mặt: $e'};
    }
  }

  // Lấy ảnh khuôn mặt gốc đã đăng ký
  Future<Map<String, dynamic>> getProfileFace() async {
    try {
      final res = await _client.get('Attendance/profile-face');
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint("Error getProfileFace: $e");
    }
    return {'hasRegisteredFace': false, 'registeredFaceBase64': null};
  }

  // Hủy / Gỡ bỏ khuôn mặt đăng ký
  Future<Map<String, dynamic>> deleteFace() async {
    try {
      final res = await _client.post('Attendance/delete-face');
      final data = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200,
        'message': data['message'] ?? 'Đã gỡ bỏ gương mặt đăng nhập!',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi gỡ bỏ khuôn mặt: $e'};
    }
  }

  // === 2. CRUD NHÂN VIÊN ===

  Future<List<UserModel>> getEmployees() async {
    try {
      final res = await _client.get('Employee');
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => UserModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Error getEmployees: $e");
    }
    return [];
  }

  Future<bool> createEmployee(Map<String, dynamic> body) async {
    final res = await _client.post('Employee', body: body);
    return res.statusCode == 200;
  }

  Future<bool> updateEmployee(String id, Map<String, dynamic> body) async {
    final res = await _client.put('Employee/$id', body: body);
    return res.statusCode == 200;
  }

  Future<bool> deleteEmployee(String id) async {
    final res = await _client.delete('Employee/$id');
    return res.statusCode == 200;
  }

  // === 3. CRUD CA LÀM VIỆC ===

  Future<List<ShiftModel>> getShifts() async {
    try {
      final res = await _client.get('Shift');
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => ShiftModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Error getShifts: $e");
    }
    return [];
  }

  Future<bool> createShift(Map<String, dynamic> body) async {
    final res = await _client.post('Shift', body: body);
    return res.statusCode == 200 || res.statusCode == 201;
  }

  Future<bool> updateShift(int id, Map<String, dynamic> body) async {
    final res = await _client.put('Shift/$id', body: body);
    return res.statusCode == 200;
  }

  Future<bool> deleteShift(int id) async {
    final res = await _client.delete('Shift/$id');
    return res.statusCode == 200;
  }

  // === 4. CRUD ĐƠN XIN NGHỈ PHÉP ===

  Future<List<LeaveRequestModel>> getMyLeaveRequests() async {
    try {
      final res = await _client.get('LeaveRequest/my-requests');
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => LeaveRequestModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Error getMyLeaveRequests: $e");
    }
    return [];
  }

  Future<List<LeaveRequestModel>> getAllLeaveRequests({String? status}) async {
    try {
      String endpoint = 'LeaveRequest/all';
      if (status != null) endpoint += '?status=$status';
      final res = await _client.get(endpoint);
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => LeaveRequestModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Error getAllLeaveRequests: $e");
    }
    return [];
  }

  Future<Map<String, dynamic>> createLeaveRequest(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('LeaveRequest', body: body);
      final data = jsonDecode(res.body);
      return {
        'success': res.statusCode == 200 || res.statusCode == 201,
        'message': data['message'] ?? (res.statusCode == 200 ? 'Gửi đơn xin nghỉ phép thành công!' : 'Lỗi gửi đơn (${res.statusCode})'),
        'data': data['data'],
      };
    } catch (e) {
      debugPrint("Error createLeaveRequest: $e");
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  Future<bool> updateLeaveStatus(int id, String status) async {
    try {
      final res = await _client.put('LeaveRequest/$id/status', body: {'status': status});
      return res.statusCode == 200;
    } catch (e) {
      debugPrint("Error updateLeaveStatus: $e");
      return false;
    }
  }

  Future<bool> deleteLeaveRequest(int id) async {
    try {
      final res = await _client.delete('LeaveRequest/$id');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint("Error deleteLeaveRequest: $e");
      return false;
    }
  }
}
