import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config_url.dart';
import '../models/app_models.dart';

class AuthService {
  static String get baseUrl => Config_URL.baseUrl;

  // 1. Bước 1 đăng nhập: Gửi thông tin đăng nhập -> Nhận yêu cầu OTP
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse("${baseUrl}Auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          "success": true,
          "requireOtp": data['requireOtp'] ?? true,
          "otp": data['otp'], // OTP trả về để người dùng dễ kiểm tra
          "message": data['message'] ?? 'Vui lòng nhập OTP',
          "email": data['email']
        };
      } else {
        return {
          "success": false,
          "message": data['message'] ?? 'Tên đăng nhập hoặc mật khẩu không chính xác'
        };
      }
    } catch (e) {
      return {"success": false, "message": "Lỗi kết nối mạng: $e"};
    }
  }

  // 2. Bước 2 đăng nhập: Xác thực OTP -> Cấp JWT Token
  static Future<Map<String, dynamic>> verifyOtp(String username, String otp) async {
    try {
      final response = await http.post(
        Uri.parse("${baseUrl}Auth/verify-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "otp": otp}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        String token = data['token'];
        String role = data['role'] ?? 'Employee';

        await _saveAuthSession(token, role, data['user']);

        return {
          "success": true,
          "token": token,
          "role": role,
          "user": UserModel.fromJson(data['user'])
        };
      } else {
        return {
          "success": false,
          "message": data['message'] ?? 'Mã OTP không đúng hoặc đã hết hạn'
        };
      }
    } catch (e) {
      return {"success": false, "message": "Lỗi xác thực OTP: $e"};
    }
  }

  // 2b. Gửi mã OTP đăng nhập qua Gmail (Passwordless Login)
  static Future<Map<String, dynamic>> sendEmailOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse("${baseUrl}Auth/send-email-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": data['message'] ?? 'Mã OTP đã được gửi về Gmail của bạn!',
          "email": data['email'] ?? email,
          "otp": data['otp'],
          "emailSent": data['emailSent'] ?? true,
        };
      } else {
        return {
          "success": false,
          "message": data['message'] ?? 'Không thể gửi mã OTP tới email này'
        };
      }
    } catch (e) {
      return {"success": false, "message": "Lỗi kết nối máy chủ khi gửi OTP Gmail: $e"};
    }
  }

  // 2c. Xác thực mã OTP gửi qua Gmail để đăng nhập
  static Future<Map<String, dynamic>> verifyEmailOtp(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse("${baseUrl}Auth/verify-email-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "otp": otp}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        String token = data['token'];
        String role = data['role'] ?? 'Employee';

        await _saveAuthSession(token, role, data['user']);

        return {
          "success": true,
          "token": token,
          "role": role,
          "user": UserModel.fromJson(data['user'])
        };
      } else {
        return {
          "success": false,
          "message": data['message'] ?? 'Mã OTP không đúng hoặc đã hết hạn'
        };
      }
    } catch (e) {
      return {"success": false, "message": "Lỗi xác thực OTP Gmail: $e"};
    }
  }

  // Đăng nhập nhanh (Quick Login - Bỏ qua OTP khi cần demo nhanh)
  static Future<Map<String, dynamic>> quickLogin(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse("${baseUrl}Auth/quick-login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        String token = data['token'];
        String role = data['role'] ?? 'Employee';
        await _saveAuthSession(token, role, data['user']);

        return {
          "success": true,
          "token": token,
          "role": role,
          "user": UserModel.fromJson(data['user'])
        };
      } else {
        return {
          "success": false,
          "message": data['message'] ?? 'Tài khoản hoặc mật khẩu không đúng'
        };
      }
    } catch (e) {
      return {"success": false, "message": "Lỗi kết nối: $e"};
    }
  }



  // 4. Đăng nhập bằng Khuôn mặt (Face Login / Face ID)
  static Future<Map<String, dynamic>> faceLogin({
    String? username,
    required String faceBase64,
    List<double>? biometricRatios,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("${baseUrl}Auth/face-login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": (username != null && username.isNotEmpty) ? username : null,
          "faceBase64": faceBase64,
          "biometricRatios": biometricRatios,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (data['status'] == true && data['isMatch'] == true) {
          String token = data['token'];
          String role = data['role'] ?? 'Employee';
          await _saveAuthSession(token, role, data['user']);

          return {
            "success": true,
            "isMatch": true,
            "similarity": (data['similarity'] as num?)?.toDouble() ?? 0.0,
            "message": data['message'] ?? 'Đăng nhập khuôn mặt thành công!',
            "token": token,
            "role": role,
            "user": UserModel.fromJson(data['user']),
            "registeredFaceBase64": data['registeredFaceBase64'],
          };
        } else {
          return {
            "success": false,
            "isMatch": false,
            "similarity": (data['similarity'] as num?)?.toDouble() ?? 0.0,
            "message": data['message'] ?? 'Khuôn mặt không khớp!',
            "registeredFaceBase64": data['registeredFaceBase64'],
            "employeeName": data['employeeName'],
          };
        }
      } else {
        return {
          "success": false,
          "isMatch": false,
          "similarity": 0.0,
          "message": data['message'] ?? 'Không thể xác thực khuôn mặt'
        };
      }
    } catch (e) {
      return {"success": false, "isMatch": false, "similarity": 0.0, "message": "Lỗi kết nối máy chủ: $e"};
    }
  }

  // 3. Đăng ký tài khoản qua email
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String department = "Kỹ thuật",
    String position = "Nhân viên",
    String role = "Employee",
  }) async {
    try {
      final response = await http.post(
        Uri.parse("${baseUrl}Auth/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "email": email,
          "password": password,
          "fullName": fullName,
          "department": department,
          "position": position,
          "role": role,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          "success": true,
          "otp": data['otp'],
          "message": data['message'] ?? "Đăng ký thành công!"
        };
      } else {
        return {
          "success": false,
          "message": data['message'] ?? "Đăng ký không thành công"
        };
      }
    } catch (e) {
      return {"success": false, "message": "Lỗi kết nối: $e"};
    }
  }



  static Future<void> _saveAuthSession(String token, String role, dynamic userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('user_role', role);
    if (userData != null) {
      await prefs.setString('user_data', jsonEncode(userData));
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    await prefs.remove('user_data');
  }

  static Future<Map<String, dynamic>?> getSavedAuthInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) return null;

    if (JwtDecoder.isExpired(token)) {
      await logout();
      return null;
    }

    final role = prefs.getString('user_role') ?? 'Employee';
    final userJson = prefs.getString('user_data');
    UserModel? user;
    if (userJson != null) {
      try {
        user = UserModel.fromJson(jsonDecode(userJson));
      } catch (_) {}
    }

    return {
      'token': token,
      'role': role,
      'user': user,
    };
  }
}
