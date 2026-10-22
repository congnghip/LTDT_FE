import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _fullNameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _positionCtrl = TextEditingController(text: 'Nhân viên');

  String _selectedRole = 'Employee';
  String _selectedDepartment = 'Kỹ thuật';
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleRegister() async {
    final username = _usernameCtrl.text.trim();
    final fullName = _fullNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (username.isEmpty || fullName.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackbar('Vui lòng điền đầy đủ các thông tin bắt buộc (*)', isError: true);
      return;
    }

    if (!email.contains('@')) {
      _showSnackbar('Email không đúng định dạng', isError: true);
      return;
    }

    if (password.length < 6) {
      _showSnackbar('Mật khẩu tối thiểu 6 ký tự', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.register(
      username: username,
      email: email,
      password: password,
      fullName: fullName,
      department: _selectedDepartment,
      position: _positionCtrl.text.trim(),
      role: _selectedRole,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true && mounted) {
      final otp = result['otp'] ?? '123456';
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Đăng ký thành công!'),
            ],
          ),
          content: Text(
            'Tài khoản của bạn đã được khởi tạo thành công.\n\n'
            'Mã OTP xác thực đã được gửi về Gmail: $email\n'
            '(Mã OTP: $otp)\n\n'
            'Bây giờ bạn có thể đăng nhập bằng tài khoản này hoặc đăng nhập trực tiếp bằng OTP Gmail.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // Quay về LoginScreen
              },
              child: const Text('Đến trang Đăng nhập'),
            ),
          ],
        ),
      );
    } else if (mounted) {
      _showSnackbar(result['message'] ?? 'Đăng ký thất bại', isError: true);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng ký tài khoản qua Email'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tạo tài khoản chấm công mới',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[900]),
              ),
              const SizedBox(height: 4),
              const Text('Hỗ trợ phân quyền Nhân viên, Quản trị viên và Quản lý', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),

              // Full Name
              TextField(
                controller: _fullNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Họ và tên *',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // Email
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email công ty *',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // Username
              TextField(
                controller: _usernameCtrl,
                decoration: InputDecoration(
                  labelText: 'Tên đăng nhập *',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // Password
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu * (Tối thiểu 6 ký tự)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // Phòng ban
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Phòng ban',
                  prefixIcon: const Icon(Icons.business_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDepartment,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'Kỹ thuật', child: Text('Phòng Kỹ thuật & IT')),
                      DropdownMenuItem(value: 'Nhân sự', child: Text('Phòng Nhân sự & Hành chính')),
                      DropdownMenuItem(value: 'Kinh doanh', child: Text('Phòng Kinh doanh & Marketing')),
                      DropdownMenuItem(value: 'Ban Giám Đốc', child: Text('Ban Giám Đốc')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDepartment = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Phân quyền (Role)
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Vai trò (Role phân quyền)',
                  prefixIcon: const Icon(Icons.security_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'Employee', child: Text('Nhân viên (Employee) - Vào Dashboard Chấm công')),
                      DropdownMenuItem(value: 'Admin', child: Text('Quản trị viên (Admin) - Vào Trang Quản trị')),
                      DropdownMenuItem(value: 'Manager', child: Text('Quản lý / Khách (Manager) - Giám sát ca trực')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRole = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Nút Đăng ký
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('XÁC NHẬN ĐĂNG KÝ QUA EMAIL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
