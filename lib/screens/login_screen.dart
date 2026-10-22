import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/face_detector_service.dart';
import '../widgets/face_mesh_overlay.dart';
import 'admin_dashboard_screen.dart';
import 'employee_dashboard_screen.dart';
import 'manager_dashboard_screen.dart';
import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  // Tự động kiểm tra phiên đăng nhập đã lưu
  Future<void> _checkSavedSession() async {
    final session = await AuthService.getSavedAuthInfo();
    if (session != null && mounted) {
      _navigateToRole(session['role'] ?? 'Employee');
    }
  }

  void _navigateToRole(String role) {
    Widget targetScreen;
    if (role == 'Admin') {
      targetScreen = const AdminDashboardScreen();
    } else if (role == 'Manager') {
      targetScreen = const ManagerDashboardScreen();
    } else {
      targetScreen = const EmployeeDashboardScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => targetScreen),
    );
  }

  // Yêu cầu: Đăng nhập 2 lớp (Mật khẩu + OTP)
  Future<void> _handleStep1Login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnackbar('Vui lòng nhập tên đăng nhập và mật khẩu', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final result = await AuthService.login(username, password);
    setState(() => _isLoading = false);

    if (result['success'] == true && mounted) {
      final serverOtp = result['otp']?.toString() ?? '123456';
      _showOtpDialog(username, serverOtp);
    } else if (mounted) {
      _showSnackbar(result['message'] ?? 'Đăng nhập không thành công', isError: true);
    }
  }

  // Hộp thoại xác thực OTP (Bước 2)
  void _showOtpDialog(String username, String serverOtp) {
    final otpController = TextEditingController(text: serverOtp);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.verified_user, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text('Xác thực mã OTP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mã OTP 6 số đã được gửi trực tiếp tới hòm thư Gmail của bạn. Vui lòng kiểm tra hộp thư đến (hoặc Thư rác/Spam).',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_read, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mã OTP (demo/test): $serverOtp (hoặc 123456)',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6),
              maxLength: 6,
              decoration: InputDecoration(
                hintText: '000000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final otp = otpController.text.trim();
              if (otp.length != 6) {
                _showSnackbar('Mã OTP gồm 6 chữ số', isError: true);
                return;
              }
              Navigator.pop(ctx);
              _handleVerifyOtp(username, otp);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
            child: const Text('Xác nhận OTP'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVerifyOtp(String username, String otp) async {
    setState(() => _isLoading = true);
    final res = await AuthService.verifyOtp(username, otp);
    setState(() => _isLoading = false);

    if (res['success'] == true && mounted) {
      final role = res['role'] ?? 'Employee';
      _showSnackbar('Xác thực OTP thành công! Chào mừng: ${res['user']?.fullName ?? role}');
      _navigateToRole(role);
    } else if (mounted) {
      _showSnackbar(res['message'] ?? 'Xác thực OTP thất bại', isError: true);
    }
  }

  // ==========================================
  // ĐĂNG NHẬP BẰNG OTP GMAIL (KHÔNG CẦN MẬT KHẨU)
  // ==========================================
  void _openOtpWithEmail(String email) {
    _showGmailOtpLoginSheet(initialEmail: email);
  }

  void _showGmailOtpLoginSheet({String? initialEmail}) {
    final emailController = TextEditingController(
      text: initialEmail ?? (_usernameController.text.contains('@') ? _usernameController.text.trim() : 'quangbui.061073@gmail.com'),
    );
    final otpController = TextEditingController();
    bool isOtpSent = false;
    bool isSheetLoading = false;
    String statusMsg = '';
    String? serverOtp;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thanh kéo
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mark_email_read, color: Colors.red, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đăng nhập bằng OTP Gmail',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Gửi mã OTP về Gmail để đăng nhập trực tiếp',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (!isOtpSent) ...[
                // BƯỚC 1: NHẬP ĐỊA CHỈ GMAIL
                const Text(
                  'Nhập địa chỉ Gmail để nhận mã OTP xác thực (không cần nhớ mật khẩu):',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Địa chỉ Gmail (*)',
                    hintText: 'quangbui.061073@gmail.com',
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.red),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 10),

                // Gợi ý email nhanh
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.star, size: 14, color: Colors.amber),
                      label: const Text('quangbui.061073@gmail.com', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setSheetState(() => emailController.text = 'quangbui.061073@gmail.com');
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.person, size: 14, color: Colors.teal),
                      label: const Text('nhanvien1@gmail.com', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setSheetState(() => emailController.text = 'nhanvien1@gmail.com');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (statusMsg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      statusMsg,
                      style: TextStyle(
                        color: statusMsg.contains('thất bại') || statusMsg.contains('hợp lệ') ? Colors.red : Colors.green[800],
                        fontSize: 12,
                      ),
                    ),
                  ),

                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: isSheetLoading
                        ? null
                        : () async {
                            final targetEmail = emailController.text.trim();
                            if (targetEmail.isEmpty || !targetEmail.contains('@')) {
                              setSheetState(() => statusMsg = 'Vui lòng nhập địa chỉ Gmail hợp lệ');
                              return;
                            }

                            setSheetState(() {
                              isSheetLoading = true;
                              statusMsg = 'Đang kết nối Gmail SMTP và gửi mã OTP...';
                            });

                            final res = await AuthService.sendEmailOtp(targetEmail);

                            setSheetState(() => isSheetLoading = false);

                            if (res['success'] == true) {
                              setSheetState(() {
                                isOtpSent = true;
                                serverOtp = res['otp']?.toString();
                                statusMsg = res['message'] ?? 'Mã OTP đã được gửi về Gmail của bạn!';
                              });
                            } else {
                              setSheetState(() {
                                statusMsg = res['message'] ?? 'Gửi OTP thất bại';
                              });
                            }
                          },
                    icon: isSheetLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      isSheetLoading ? 'Đang gửi mã OTP...' : 'GỬI MÃ OTP VỀ GMAIL',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ] else ...[
                // BƯỚC 2: NHẬP MÃ OTP NHẬN QUA GMAIL
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.blue[700], size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Đã gửi mã xác thực tới Gmail:\n${emailController.text.trim()}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900], fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Vui lòng mở ứng dụng Gmail (kiểm tra cả Hộp thư đến và Thư rác/Spam) để lấy mã OTP.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                if (serverOtp != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.security, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mã OTP dự phòng (demo): $serverOtp (hoặc 123456)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),

                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: '000000',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),

                if (statusMsg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      statusMsg,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: statusMsg.contains('thất bại') || statusMsg.contains('không đúng') ? Colors.red : Colors.green[800],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: isSheetLoading
                        ? null
                        : () async {
                            final code = otpController.text.trim();
                            if (code.length != 6) {
                              setSheetState(() => statusMsg = 'Mã OTP gồm đúng 6 chữ số');
                              return;
                            }

                            setSheetState(() {
                              isSheetLoading = true;
                              statusMsg = 'Đang xác thực OTP Gmail...';
                            });

                            final verifyRes = await AuthService.verifyEmailOtp(
                              emailController.text.trim(),
                              code,
                            );

                            setSheetState(() => isSheetLoading = false);

                            if (verifyRes['success'] == true && mounted) {
                              Navigator.pop(sheetCtx);
                              final role = verifyRes['role'] ?? 'Employee';
                              final fullName = verifyRes['user']?.fullName ?? role;
                              _showSnackbar('Đăng nhập thành công! Chào mừng $fullName');
                              _navigateToRole(role);
                            } else {
                              setSheetState(() {
                                statusMsg = verifyRes['message'] ?? 'Mã OTP không đúng hoặc đã hết hạn';
                              });
                            }
                          },
                    icon: isSheetLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.login, size: 20),
                    label: Text(
                      isSheetLoading ? 'Đang kiểm tra...' : 'XÁC NHẬN OTP & VÀO HỆ THỐNG',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Đổi email khác', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        setSheetState(() {
                          isOtpSent = false;
                          statusMsg = '';
                          otpController.clear();
                        });
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Gửi lại mã OTP', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        setSheetState(() {
                          isSheetLoading = true;
                          statusMsg = 'Đang gửi lại mã OTP mới...';
                        });
                        final res = await AuthService.sendEmailOtp(emailController.text.trim());
                        setSheetState(() {
                          isSheetLoading = false;
                          if (res['success'] == true) {
                            serverOtp = res['otp']?.toString();
                            statusMsg = 'Mã OTP mới đã được gửi về Gmail của bạn!';
                          } else {
                            statusMsg = res['message'] ?? 'Không thể gửi lại mã OTP';
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ĐĂNG NHẬP BẰNG KHUÔN MẶT (FACE ID / AI MESH)
  // ==========================================
  void _handleFaceLoginOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.face_retouching_natural, color: Colors.blue[800], size: 26),
                  const SizedBox(width: 8),
                  const Text(
                    'Đăng nhập bằng Khuôn mặt (Face ID)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Quét khuôn mặt AI - Nhận diện nhanh không cần nhập mật khẩu',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.camera_alt, color: Colors.blue),
                ),
                title: const Text('Mở Camera quét khuôn mặt', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Tự động quét khung xương AI & nhận diện'),
                onTap: () {
                  Navigator.pop(ctx);
                  _processFaceLogin(ImageSource.camera);
                },
              ),
              const Divider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: const Icon(Icons.photo_library, color: Colors.green),
                ),
                title: const Text('Chọn ảnh khuôn mặt từ Thư viện', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Chọn ảnh chụp chân dung rõ nét có sẵn'),
                onTap: () {
                  Navigator.pop(ctx);
                  _processFaceLogin(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processFaceLogin(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 90);
      if (picked == null) return;
      await _processFaceLoginFromPath(picked.path);
    } catch (e) {
      if (mounted) {
        _showSnackbar('Không thể chụp hoặc mở ảnh: $e', isError: true);
      }
    }
  }

  Future<void> _processFaceLoginFromPath(String imagePath) async {
    try {
      setState(() => _isLoading = true);

      // Hiển thị thanh tiến trình quét khung xương AI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Đang quét khung xương AI & tách bối cảnh...')),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      // 1. Phân tích & Cắt vùng mặt bằng Google ML Kit (Loại bỏ 100% bối cảnh)
      final analysis = await FaceDetectorService.analyzeAndCropFace(imagePath);

      if (!analysis.hasFace || analysis.croppedFaceBytes == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          _showFaceErrorDialog(
            'Không nhận diện được khuôn mặt',
            analysis.errorMessage ?? 'Không phát hiện thấy khuôn mặt người trong ảnh! Vui lòng chụp rõ khuôn mặt chính diện, không chụp vật thể hay phông nền.',
          );
        }
        return;
      }

      // 2. Chuẩn bị Base64 ảnh mặt đã cắt bỏ bối cảnh
      final croppedB64 = base64Encode(analysis.croppedFaceBytes!);
      final ratios = analysis.biometricRatios;
      final username = _usernameController.text.trim();

      // 3. Gửi API xác thực Face Login
      final result = await AuthService.faceLogin(
        username: username.isNotEmpty ? username : null,
        faceBase64: croppedB64,
        biometricRatios: ratios,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        _showFaceLoginResultDialog(analysis, result);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showSnackbar('Lỗi trong quá trình quét khuôn mặt: $e', isError: true);
      }
    }
  }

  void _showFaceErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 13)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  // Hộp thoại hiển thị KHUNG XƯƠNG AI & KẾT QUẢ ĐĂNG NHẬP
  void _showFaceLoginResultDialog(
    FaceAnalysisResult analysis,
    Map<String, dynamic> result,
  ) {
    bool showMeshInDialog = true;
    final isMatch = result['isMatch'] == true;
    final similarity = (result['similarity'] as num?)?.toDouble() ?? 0.0;
    final message = result['message']?.toString() ?? '';
    final croppedBytes = analysis.croppedFaceBytes!;
    final regB64 = result['registeredFaceBase64']?.toString();
    final role = result['role']?.toString() ?? 'Employee';
    final empName = result['user']?.fullName ?? result['employeeName'] ?? 'Nhân viên';

    Uint8List? regFaceBytes;
    if (regB64 != null && regB64.isNotEmpty) {
      try {
        var clean = regB64;
        final comma = clean.indexOf(',');
        if (comma >= 0) clean = clean.substring(comma + 1);
        regFaceBytes = base64Decode(clean);
      } catch (_) {}
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tiêu đề trạng thái
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isMatch ? Icons.check_circle : Icons.cancel,
                    color: isMatch ? Colors.green : Colors.red,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isMatch ? 'Khuôn mặt HỢP LỆ' : 'CẢNH BÁO: KHÔNG KHỚP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isMatch ? Colors.green[800] : Colors.red[800],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Nút Bật / Tắt Khung xương AI Mesh
              InkWell(
                onTap: () {
                  setDialogState(() {
                    showMeshInDialog = !showMeshInDialog;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: showMeshInDialog ? const Color(0xFFE0F7FA) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: showMeshInDialog ? const Color(0xFF00BCD4) : Colors.grey.shade400,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.polyline,
                        size: 14,
                        color: showMeshInDialog ? const Color(0xFF00838F) : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        showMeshInDialog ? 'Khung xương AI: BẬT' : 'Khung xương AI: TẮT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: showMeshInDialog ? const Color(0xFF00838F) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // So sánh ảnh gốc và ảnh vừa chụp với Khung xương AI
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (regFaceBytes != null)
                    FaceMeshOverlay(
                      imageBytes: regFaceBytes,
                      width: 105,
                      height: 105,
                      showSkeleton: showMeshInDialog,
                      label: 'Ảnh hồ sơ gốc',
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      isMatch ? Icons.check_circle : Icons.cancel,
                      color: isMatch ? Colors.green : Colors.red,
                      size: 26,
                    ),
                  ),
                  FaceMeshOverlay(
                    imageBytes: croppedBytes,
                    analysis: analysis,
                    width: 105,
                    height: 105,
                    showSkeleton: showMeshInDialog,
                    label: 'Ảnh vừa quét',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Điểm số tương đồng
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMatch ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isMatch ? Colors.green.shade400 : Colors.red.shade400),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isMatch ? Icons.verified : Icons.error_outline,
                            color: isMatch ? Colors.green : Colors.red, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Độ khớp: $similarity% (Chuẩn >= 66.5%)',
                          style: TextStyle(
                            color: isMatch ? Colors.green[800] : Colors.red[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (similarity / 100.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(isMatch ? Colors.green : Colors.red),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tài khoản: $empName',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isMatch ? Colors.green[900] : Colors.red[900],
                  fontWeight: isMatch ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Đóng'),
            ),
            if (!isMatch)
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Quét lại'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _processFaceLogin(ImageSource.camera);
                },
              ),
            if (isMatch)
              ElevatedButton.icon(
                icon: const Icon(Icons.login, size: 18),
                label: const Text('VÀO HỆ THỐNG'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _showSnackbar('Đăng nhập Face ID thành công! Chào mừng: $empName');
                  _navigateToRole(role);
                },
              ),
          ],
        ),
      ),
    );
  }

  // Đăng nhập nhanh để tiện test ngay lập tức
  Future<void> _fillAndQuickLogin(String username, String password) async {
    _usernameController.text = username;
    _passwordController.text = password;

    setState(() => _isLoading = true);
    final res = await AuthService.quickLogin(username, password);
    setState(() => _isLoading = false);

    if (res['success'] == true && mounted) {
      final role = res['role'] ?? 'Employee';
      _showSnackbar('Đăng nhập thành công với vai trò: $role');
      _navigateToRole(role);
    } else if (mounted) {
      _showSnackbar(res['message'] ?? 'Đăng nhập thất bại', isError: true);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              children: [
                // Logo & Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 15, spreadRadius: 3),
                    ],
                  ),
                  child: const Icon(Icons.security, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  'HỆ THỐNG CHẤM CÔNG THÔNG MINH',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Bùi Nguyễn Công Nghiệp - Đăng nhập Face ID & OTP',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 24),

                // Form card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Đăng nhập hệ thống',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        // Username
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Tên đăng nhập / Email (Không bắt buộc nếu dùng Face ID)',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Password
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Nút Đăng nhập 2 lớp với OTP
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _handleStep1Login,
                            icon: const Icon(Icons.security, size: 20),
                            label: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('ĐĂNG NHẬP BẰNG MẬT KHẨU + OTP',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // NÚT ĐĂNG NHẬP BẰNG OTP GMAIL (TÍNH NĂNG MỚI)
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : () => _showGmailOtpLoginSheet(),
                            icon: const Icon(Icons.mark_email_read, size: 20, color: Colors.white),
                            label: const Text('ĐĂNG NHẬP BẰNG OTP GMAIL',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey[300])),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('HOẶC', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                            ),
                            Expanded(child: Divider(color: Colors.grey[300])),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // NÚT ĐĂNG NHẬP BẰNG KHUÔN MẶT (FACE ID)
                        SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _handleFaceLoginOptions,
                            icon: const Icon(Icons.face_retouching_natural, color: Colors.indigo, size: 22),
                            label: const Text(
                              'ĐĂNG NHẬP BẰNG KHUÔN MẶT (FACE ID)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.indigo, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: Colors.indigo.shade50.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Thẻ chọn tài khoản test nhanh phân quyền
                Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt, color: Colors.amber, size: 22),
                            SizedBox(width: 6),
                            Text('Chọn nhanh tài khoản test phân quyền:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.mark_email_read, color: Colors.red, size: 18),
                              label: const Text('OTP Gmail (quangbui.061073@gmail.com)', style: TextStyle(fontSize: 12)),
                              onPressed: () => _openOtpWithEmail('quangbui.061073@gmail.com'),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.admin_panel_settings, color: Colors.indigo, size: 18),
                              label: const Text('Admin (Bùi Nguyễn Công Nghiệp)', style: TextStyle(fontSize: 12)),
                              onPressed: () => _fillAndQuickLogin('admin', 'Admin@123'),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.person, color: Colors.teal, size: 18),
                              label: const Text('Nhân viên (Nguyễn Văn An)', style: TextStyle(fontSize: 12)),
                              onPressed: () => _fillAndQuickLogin('nhanvien1', 'Staff@123'),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.manage_accounts, color: Colors.purple, size: 18),
                              label: const Text('Quản lý (Trần Thị Bình)', style: TextStyle(fontSize: 12)),
                              onPressed: () => _fillAndQuickLogin('quanly1', 'Manager@123'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Đăng ký mới
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Chưa có tài khoản? '),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                        );
                      },
                      child: const Text('Đăng ký qua Email', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
