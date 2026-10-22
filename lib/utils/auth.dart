import '../services/auth_service.dart';

class Auth {
  static Future<Map<String, dynamic>> login(String username, String password) async {
    return await AuthService.login(username, password);
  }

  static Future<Map<String, dynamic>> quickLogin(String username, String password) async {
    return await AuthService.quickLogin(username, password);
  }

  static Future<Map<String, dynamic>> verifyOtp(String username, String otp) async {
    return await AuthService.verifyOtp(username, otp);
  }

  static Future<void> logout() async {
    await AuthService.logout();
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String department = "Kỹ thuật",
    String position = "Nhân viên",
    String role = "Employee",
  }) async {
    return await AuthService.register(
      username: username,
      email: email,
      password: password,
      fullName: fullName,
      department: department,
      position: position,
      role: role,
    );
  }
}
