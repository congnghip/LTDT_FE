import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../services/chamcong_service.dart';
import '../services/face_detector_service.dart';
import '../services/noise_meter_service.dart';
import '../widgets/face_mesh_overlay.dart';
import '../widgets/noise_meter_widget.dart';
import '../utils/sample_faces.dart';
import 'login_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> with SingleTickerProviderStateMixin {
  final ChamCongService _service = ChamCongService();
  final ImagePicker _picker = ImagePicker();
  late TabController _tabController;

  UserModel? _currentUser;
  bool _hasCheckedIn = false;
  bool _hasCheckedOut = false;
  AttendanceModel? _todayAttendance;

  List<AttendanceModel> _history = [];
  Map<String, dynamic>? _summary;
  List<LeaveRequestModel> _leaveRequests = [];
  bool _isLoading = false;

  // Cài đặt Gương mặt Đăng nhập (Face ID)
  bool _hasRegisteredFace = false;
  String? _registeredFaceBase64;
  Uint8List? _registeredFaceBytes;

  final currencyFormat = NumberFormat("#,##0", "vi_VN");
  final timeFormat = DateFormat("HH:mm:ss");
  final dateFormat = DateFormat("dd/MM/yyyy");

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final session = await AuthService.getSavedAuthInfo();
    _currentUser = session?['user'];

    await Future.wait([
      _loadTodayStatus(),
      _loadHistory(),
      _loadLeaveRequests(),
      _loadProfileFace(),
    ]);

    setState(() => _isLoading = false);
  }

  Future<void> _loadProfileFace() async {
    try {
      final res = await _service.getProfileFace();
      final String? regFace = res['registeredFaceBase64'];
      Uint8List? bytes;
      if (regFace != null && regFace.isNotEmpty) {
        var clean = regFace;
        if (clean.contains(',')) clean = clean.split(',').last;
        bytes = base64Decode(clean);
      }
      if (mounted) {
        setState(() {
          _registeredFaceBase64 = regFace;
          _registeredFaceBytes = bytes;
          _hasRegisteredFace = res['hasRegisteredFace'] == true || (bytes != null);
        });
      }
    } catch (e) {
      debugPrint("Lỗi tải thông tin gương mặt: $e");
    }
  }

  Future<void> _loadTodayStatus() async {
    final status = await _service.getTodayStatus();
    setState(() {
      _hasCheckedIn = status['hasCheckedIn'] ?? false;
      _hasCheckedOut = status['hasCheckedOut'] ?? false;
      _todayAttendance = status['data'] != null ? AttendanceModel.fromJson(status['data']) : null;
    });
  }

  Future<void> _loadHistory() async {
    final result = await _service.getPersonalHistory();
    setState(() {
      _summary = result['summary'];
      _history = (result['records'] as List<AttendanceModel>?) ?? [];
    });
  }

  Future<void> _loadLeaveRequests() async {
    final list = await _service.getMyLeaveRequests();
    setState(() {
      _leaveRequests = list;
    });
  }

  // === 3 TÍNH NĂNG THUYẾT TRÌNH ĐẶC BIỆT (CHẠY THỰC TẾ) ===

  // CÀI ĐẶT GƯƠNG MẶT ĐĂNG NHẬP (FACE ID) CHO NHÂN VIÊN
  void _openFaceSettingsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thanh kéo
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Tiêu đề
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.face_retouching_natural, color: Colors.blue[800], size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cài đặt Gương mặt Đăng nhập',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Face ID • ${_currentUser?.fullName ?? "Nhân viên"}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Thẻ trạng thái gương mặt hiện tại
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _hasRegisteredFace ? Colors.green.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hasRegisteredFace ? Colors.green.shade300 : Colors.amber.shade400,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_registeredFaceBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _registeredFaceBytes!,
                            width: 65,
                            height: 65,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 65,
                          height: 65,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Icon(
                            _hasRegisteredFace ? Icons.check_circle : Icons.no_photography_outlined,
                            size: 36,
                            color: _hasRegisteredFace ? Colors.green : Colors.orange,
                          ),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _hasRegisteredFace ? Icons.verified : Icons.warning_amber_rounded,
                                  size: 16,
                                  color: _hasRegisteredFace ? Colors.green[800] : Colors.amber[900],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _hasRegisteredFace ? 'ĐÃ KÍCH HOẠT FACE ID' : 'CHƯA CÀI ĐẶT GƯƠNG MẶT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _hasRegisteredFace ? Colors.green[900] : Colors.amber[900],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _hasRegisteredFace
                                  ? 'Khuôn mặt chuẩn đã được mã hóa bảo mật. Bạn có thể dùng Face ID để đăng nhập và chấm công AI.'
                                  : 'Vui lòng cài đặt ảnh khuôn mặt chuẩn để đăng nhập nhanh không cần mật khẩu.',
                              style: TextStyle(fontSize: 11, color: Colors.grey[800]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Chọn phương thức cài đặt:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 8),

                // 1. Chụp ảnh qua Camera
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.blue, size: 22),
                  ),
                  title: const Text('Chụp ảnh mới bằng Camera', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Mở máy ảnh quét khuôn mặt & trích xuất khung xương AI', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.pop(ctx);
                    _captureFaceForEnrollment(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 8),

                // 2. Chọn ảnh từ Thư viện
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
                    child: const Icon(Icons.photo_library, color: Colors.teal, size: 22),
                  ),
                  title: const Text('Chọn ảnh chân dung từ Thư viện', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Tải ảnh chân dung rõ nét có sẵn trong máy', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.pop(ctx);
                    _captureFaceForEnrollment(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),

                // 3. Dùng ảnh mẫu chuẩn (Demo / Máy ảo)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.purple.shade100),
                  ),
                  tileColor: Colors.purple.shade50.withValues(alpha: 0.3),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.purple.shade100, shape: BoxShape.circle),
                    child: const Icon(Icons.science, color: Colors.purple, size: 22),
                  ),
                  title: const Text('Cài nhanh ảnh mẫu chuẩn (Demo)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Khuôn mặt chuẩn Nguyễn Văn An (thử nghiệm trên máy ảo)', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.pop(ctx);
                    _enrollFaceFromBytes(base64Decode(SampleFaces.faceAnBase64));
                  },
                ),

                if (_hasRegisteredFace) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 4),

                  Row(
                    children: [
                      // Nút thử nghiệm nhận diện Face ID
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.verified_user, size: 16),
                          label: const Text('Thử nhận diện', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue[800],
                            side: BorderSide(color: Colors.blue.shade700),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handleTestFaceRecognition();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Nút gỡ bỏ / xóa khuôn mặt
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Gỡ bỏ Face ID', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red[700],
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handleDeleteRegisteredFace();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Thử nghiệm nhận diện Face ID
  void _handleTestFaceRecognition() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Thử nghiệm nhận diện Face ID',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Hệ thống sẽ đối chiếu khuôn mặt thử nghiệm với ảnh đăng nhập của bạn.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: Colors.blue),
                ),
                title: const Text('Mở Camera thử nhận diện'),
                subtitle: const Text('Chụp mặt bạn để đối chiếu trực tiếp'),
                onTap: () {
                  Navigator.pop(ctx);
                  _captureAndVerifyFace(ImageSource.camera, isRegistering: false, forCheckIn: false);
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library, color: Colors.green),
                ),
                title: const Text('Chọn ảnh từ Thư viện để thử'),
                subtitle: const Text('Tải ảnh mặt có sẵn để đối chiếu'),
                onTap: () {
                  Navigator.pop(ctx);
                  _captureAndVerifyFace(ImageSource.gallery, isRegistering: false, forCheckIn: false);
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.person, color: Colors.purple),
                ),
                title: const Text('Thử với ảnh chuẩn (Nguyễn Văn An)'),
                subtitle: const Text('Sẽ đối chiếu khớp nếu bạn cài mặt này'),
                onTap: () {
                  Navigator.pop(ctx);
                  _verifyFaceFromBytes(base64Decode(SampleFaces.faceAnBase64), forCheckIn: false);
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.person_off, color: Colors.red),
                ),
                title: const Text('Thử với ảnh Người lạ (Mạo danh)'),
                subtitle: const Text('Kiểm tra cảnh báo phát hiện không khớp'),
                onTap: () {
                  Navigator.pop(ctx);
                  _verifyFaceFromBytes(base64Decode(SampleFaces.faceImposterBase64), forCheckIn: false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Gỡ bỏ khuôn mặt đăng ký
  Future<void> _handleDeleteRegisteredFace() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Xác nhận gỡ bỏ'),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn gỡ bỏ dữ liệu khuôn mặt này không? Sau khi gỡ, bạn sẽ không thể đăng nhập bằng Face ID cho tới khi cài đặt lại.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gỡ bỏ'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final res = await _service.deleteFace();
    setState(() => _isLoading = false);

    if (mounted) {
      if (res['success'] == true) {
        setState(() {
          _hasRegisteredFace = false;
          _registeredFaceBase64 = null;
          _registeredFaceBytes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Đã gỡ bỏ gương mặt đăng nhập thành công!'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Lỗi khi gỡ bỏ khuôn mặt'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Chụp ảnh để cài đặt gương mặt
  Future<void> _captureFaceForEnrollment(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 700,
        maxHeight: 700,
        imageQuality: 85,
      );
      if (photo == null) return;
      await _processFaceFromPath(photo.path, isRegistering: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chụp/chọn ảnh: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Đăng ký gương mặt từ mảng bytes (ảnh mẫu)
  Future<void> _enrollFaceFromBytes(Uint8List bytes) async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/face_enroll_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);
      await _processFaceFromPath(tempFile.path, isRegistering: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải ảnh mẫu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Thử nghiệm đối chiếu từ bytes (ảnh mẫu)
  Future<void> _verifyFaceFromBytes(Uint8List bytes, {bool forCheckIn = true}) async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/face_test_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);
      await _processFaceFromPath(tempFile.path, isRegistering: false, forCheckIn: forCheckIn);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi ảnh thử nghiệm: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }



  Future<void> _captureAndVerifyFace(
    ImageSource source, {
    bool isRegistering = false,
    bool forCheckIn = true,
  }) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 700,
        maxHeight: 700,
        imageQuality: 85,
      );

      if (photo == null) return;
      await _processFaceFromPath(photo.path, isRegistering: isRegistering, forCheckIn: forCheckIn);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi máy ảnh / nhận diện: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // HÀM XỬ LÝ QUÉT AI & ĐĂNG KÝ / ĐỐI CHIẾU KHUÔN MẶT
  Future<void> _processFaceFromPath(
    String imagePath, {
    bool isRegistering = false,
    bool forCheckIn = true,
  }) async {
    try {
      // 1. Hiển thị loading quét khung xương & cắt khuôn mặt (loại bỏ bối cảnh)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (loadCtx) => const Center(
          child: Card(
            elevation: 8,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00E5FF)),
                  SizedBox(width: 16),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quét khung xương AI...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 3),
                      Text('Tách mặt & loại bỏ 100% bối cảnh', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final analysis = await FaceDetectorService.analyzeAndCropFace(imagePath);

      if (mounted) {
        Navigator.pop(context); // Đóng loading quét mặt
      }

      // Nếu không phát hiện khuôn mặt hoặc có nhiều hơn 1 mặt
      if (!analysis.hasFace || analysis.croppedFaceBytes == null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Flexible(child: Text('Không nhận diện được mặt')),
                ],
              ),
              content: Text(
                analysis.errorMessage ?? 'Không tìm thấy khuôn mặt trong ảnh! Vui lòng chụp rõ mặt chính diện.',
                style: const TextStyle(fontSize: 13),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đã hiểu'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final croppedBytes = analysis.croppedFaceBytes!;
      final croppedBase64 = analysis.croppedFaceBase64!;
      final biometricRatios = analysis.biometricRatios;

      // NẾU LÀ ĐĂNG KÝ ẢNH MẪU (FACE ENROLLMENT)
      if (isRegistering) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.face_retouching_natural, color: Colors.blue),
                SizedBox(width: 8),
                Flexible(child: Text('Cài đặt Gương mặt Đăng nhập')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaceMeshOverlay(
                    imageBytes: croppedBytes,
                    analysis: analysis,
                    width: 160,
                    height: 160,
                    showSkeleton: true,
                    label: 'Khuôn mặt đã tách bối cảnh',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Nhân viên: ${_currentUser?.fullName ?? "Tài khoản hiện tại"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'AI đã nhận diện khung xương và trích xuất điểm mốc sinh trắc học. Bức ảnh này sẽ dùng làm GƯƠNG MẶT ĐĂNG NHẬP (Face ID) và CHẤM CÔNG CHUẨN!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Hủy bỏ')),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Lưu làm Gương mặt Đăng nhập'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  setState(() => _isLoading = true);
                  final res = await _service.registerFace(croppedBase64);
                  setState(() => _isLoading = false);
                  if (mounted) {
                    if (res['success'] == true) {
                      await _loadProfileFace();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  res['message'] ?? 'Đã cài đặt thành công gương mặt đăng nhập Face ID!',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green[700],
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res['message'] ?? 'Lỗi đăng ký khuôn mặt!'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
        return;
      }

      if (!mounted) return;

      // NẾU LÀ ĐỐI CHIẾU / CHẤM CÔNG: GỬI LÊN SERVER ĐỐI CHIẾU SINH TRẮC HỌC THẬT (REAL VERIFICATION)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (loadCtx) => const Center(
          child: Card(
            elevation: 8,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.blue),
                  SizedBox(width: 16),
                  Text('Đang đối chiếu nét mặt AI...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      );

      final verifyRes = await _service.verifyFace(croppedBase64, biometricRatios: biometricRatios);

      if (mounted) {
        Navigator.pop(context); // Đóng loading đối chiếu
      }

      final bool isMatch = verifyRes['isMatch'] == true;
      final double similarity = verifyRes['similarity'] ?? 0.0;
      final String message = verifyRes['message'] ?? '';
      final String? regFace = verifyRes['registeredFaceBase64'] ?? _registeredFaceBase64;
      Uint8List? regFaceBytes;
      if (regFace != null && regFace.isNotEmpty) {
        try {
          var clean = regFace;
          if (clean.contains(',')) clean = clean.split(',').last;
          regFaceBytes = base64Decode(clean);
        } catch (_) {}
      }

      if (!mounted) return;

      bool showMeshInDialog = true;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isMatch ? Icons.verified_user : Icons.gpp_bad,
                  color: isMatch ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isMatch
                        ? (forCheckIn ? 'Khuôn mặt HỢP LỆ' : 'Đối chiếu: KHỚP (${similarity.toStringAsFixed(1)}%)')
                        : 'CẢNH BÁO: KHÔNG KHỚP',
                    style: TextStyle(
                      color: isMatch ? Colors.green[800] : Colors.red[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nút bật/tắt khung xương AI
                  InkWell(
                    onTap: () => setDialogState(() => showMeshInDialog = !showMeshInDialog),
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

                  // So sánh ảnh gốc và ảnh vừa chụp với Khung xương AI (Đều loại bỏ bối cảnh)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (regFaceBytes != null)
                        FaceMeshOverlay(
                          imageBytes: regFaceBytes,
                          width: 105,
                          height: 105,
                          showSkeleton: showMeshInDialog,
                          label: 'Ảnh đã đăng ký',
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          isMatch ? Icons.check_circle : Icons.cancel,
                          color: isMatch ? Colors.green : Colors.red,
                          size: 28,
                        ),
                      ),
                      FaceMeshOverlay(
                        imageBytes: croppedBytes,
                        analysis: analysis,
                        width: 105,
                        height: 105,
                        showSkeleton: showMeshInDialog,
                        label: 'Ảnh vừa chụp',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Huy hiệu điểm số tương đồng
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
                                color: isMatch ? Colors.green : Colors.red, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              'Độ khớp: $similarity% (Chuẩn >= 70%)',
                              style: TextStyle(
                                color: isMatch ? Colors.green[800] : Colors.red[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
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
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Nhân viên: ${_currentUser?.fullName ?? "Nguyễn Văn An"}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(forCheckIn ? 'Chụp lại' : 'Đóng'),
              ),
              if (!isMatch)
                ElevatedButton.icon(
                  icon: const Icon(Icons.app_registration, size: 16),
                  label: const Text('Cài đặt lại mặt mẫu'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _openFaceSettingsDialog();
                  },
                ),
              if (isMatch && forCheckIn)
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Xác nhận chấm công'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _executeCheckIn("Face", faceBase64: croppedBase64, note: "Xác thực khuôn mặt đạt $similarity%");
                  },
                ),
              if (isMatch && !forCheckIn)
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Hoàn tất kiểm tra'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(dialogCtx),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi máy ảnh / nhận diện: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 2. Chấm công bằng Định vị GPS Thật (Geolocator GPS Geofencing)
  Future<void> _handleGpsCheckIn() async {
    setState(() => _isLoading = true);

    double userLat = 10.8018;
    double userLng = 106.7145;
    double distanceMeters = 0.0;
    bool isRealGps = false;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        userLat = pos.latitude;
        userLng = pos.longitude;
        distanceMeters = Geolocator.distanceBetween(
          userLat, userLng,
          10.8018, 106.7145, // Tọa độ trụ sở công ty
        );
        isRealGps = true;
      }
    } catch (e) {
      debugPrint("Geolocator error or timeout: $e");
      // Dùng tọa độ công ty có độ lệch thực tế 15m
      userLat = 10.8019;
      userLng = 106.7146;
      distanceMeters = 15.0;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;

    final bool isInsideGeofence = distanceMeters <= 500.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.red),
            SizedBox(width: 8),
            Flexible(child: Text('Xác thực vị trí GPS thật')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isInsideGeofence ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isInsideGeofence ? Colors.green.shade300 : Colors.red.shade300),
              ),
              child: Row(
                children: [
                  Icon(isInsideGeofence ? Icons.check_circle : Icons.cancel,
                      color: isInsideGeofence ? Colors.green : Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isInsideGeofence
                          ? 'Vị trí hợp lệ! Cách trụ sở công ty: ${distanceMeters.toStringAsFixed(0)} mét (Tối đa 500m).'
                          : 'Ngoài vùng cho phép! Cách công ty ${distanceMeters.toStringAsFixed(0)} mét (>500m).',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isInsideGeofence ? Colors.green[800] : Colors.red[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('• Tọa độ hiện tại: ${userLat.toStringAsFixed(6)}, ${userLng.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12)),
            const Text('• Tọa độ công ty: 10.801800, 106.714500 (Bán kính 500m)',
                style: TextStyle(fontSize: 12)),
            Text(isRealGps ? '• Nguồn: GPS phần cứng thiết bị thật' : '• Nguồn: Vị trí mô phỏng tại trụ sở',
                style: TextStyle(fontSize: 11, color: isRealGps ? Colors.blue[700] : Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          if (!isInsideGeofence)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeCheckIn("GPS", lat: 10.8018, lng: 106.7145, note: "Giả lập vị trí tại trụ sở công ty");
              },
              child: const Text('Giả lập tại công ty'),
            ),
          ElevatedButton(
            onPressed: isInsideGeofence
                ? () {
                    Navigator.pop(ctx);
                    _executeCheckIn("GPS", lat: userLat, lng: userLng, note: "GPS hợp lệ (${distanceMeters.toStringAsFixed(0)}m)");
                  }
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            child: const Text('Xác nhận chấm công GPS'),
          ),
        ],
      ),
    );
  }



  Future<void> _executeCheckIn(String method, {double? lat, double? lng, String? faceBase64, String? qrToken, String? note}) async {
    setState(() => _isLoading = true);
    final currentDb = NoiseMeterService().currentDb;
    final res = await _service.checkIn(
      method: method,
      latitude: lat,
      longitude: lng,
      faceBase64: faceBase64,
      qrToken: qrToken,
      noiseLevelDb: currentDb > 0 ? currentDb : null,
    );
    setState(() => _isLoading = false);

    if (res['success'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']), backgroundColor: Colors.green),
      );
      _loadAllData();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Lỗi chấm công'), backgroundColor: Colors.red),
      );
    }
  }

  // Chấm công ra (Check-out) & Live Salary Meter
  Future<void> _handleCheckOut() async {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận Check-out (Ra về)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hệ thống sẽ tính toán tổng số giờ làm và cộng trực tiếp vào Bộ tính lương thời gian thực (Live Salary Meter).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Ghi chú công việc hôm nay (Tùy chọn)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final res = await _service.checkOut(note: noteCtrl.text.trim());
              setState(() => _isLoading = false);

              if (res['success'] == true && mounted) {
                showDialog(
                  context: context,
                  builder: (alertCtx) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.monetization_on, color: Colors.amber),
                        SizedBox(width: 8),
                        Text('Đã tính lương ca làm!'),
                      ],
                    ),
                    content: Text(res['message']),
                    actions: [
                      ElevatedButton(onPressed: () => Navigator.pop(alertCtx), child: const Text('Đồng ý')),
                    ],
                  ),
                );
                _loadAllData();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res['message'] ?? 'Lỗi check-out'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
            child: const Text('Xác nhận Check-out'),
          ),
        ],
      ),
    );
  }

  // Đặt lại hôm nay để tiện test/demo nhiều lần
  Future<void> _handleResetToday() async {
    setState(() => _isLoading = true);
    final ok = await _service.resetToday();
    setState(() => _isLoading = false);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đặt lại trạng thái hôm nay để bạn test tự do!'), backgroundColor: Colors.teal),
      );
      _loadAllData();
    }
  }

  // Tạo đơn xin nghỉ phép mới (CRUD)
  Future<void> _showCreateLeaveDialog() async {
    final reasonCtrl = TextEditingController();
    String leaveType = 'Nghỉ phép năm';
    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    DateTime endDate = DateTime.now().add(const Duration(days: 1));
    String? reasonError;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final int dayCount = endDate.difference(startDate).inDays + 1;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.beach_access, color: Colors.blue),
                SizedBox(width: 8),
                Text('Tạo đơn xin nghỉ phép', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: leaveType,
                    decoration: const InputDecoration(
                      labelText: 'Loại nghỉ phép',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Nghỉ phép năm', child: Text('Nghỉ phép năm')),
                      DropdownMenuItem(value: 'Nghỉ ốm / Khám bệnh', child: Text('Nghỉ ốm / Khám bệnh')),
                      DropdownMenuItem(value: 'Việc gia đình riêng', child: Text('Việc gia đình riêng')),
                      DropdownMenuItem(value: 'Nghỉ không hưởng lương', child: Text('Nghỉ không hưởng lương')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => leaveType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Chọn từ ngày
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, color: Colors.blue),
                    title: const Text('Từ ngày', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(dateFormat.format(startDate), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.edit_calendar, size: 20, color: Colors.blue),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 7)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          startDate = picked;
                          if (endDate.isBefore(startDate)) {
                            endDate = startDate;
                          }
                        });
                      }
                    },
                  ),
                  const Divider(height: 1),
                  // Chọn đến ngày
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event, color: Colors.orange),
                    title: const Text('Đến ngày', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(dateFormat.format(endDate), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.edit_calendar, size: 20, color: Colors.orange),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate.isBefore(startDate) ? startDate : endDate,
                        firstDate: startDate,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => endDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Thời gian nghỉ: ${dayCount > 0 ? dayCount : 1} ngày',
                      style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Lý do xin nghỉ *',
                      hintText: 'Nhập chi tiết lý do xin nghỉ...',
                      errorText: reasonError,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      if (reasonError != null && val.trim().isNotEmpty) {
                        setDialogState(() => reasonError = null);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              ElevatedButton.icon(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final reason = reasonCtrl.text.trim();
                        if (reason.isEmpty) {
                          setDialogState(() {
                            reasonError = 'Vui lòng nhập lý do xin nghỉ phép!';
                          });
                          return;
                        }

                        setDialogState(() {
                          isSubmitting = true;
                          reasonError = null;
                        });

                        final res = await _service.createLeaveRequest({
                          'startDate': DateTime(startDate.year, startDate.month, startDate.day, 8, 0).toIso8601String(),
                          'endDate': DateTime(endDate.year, endDate.month, endDate.day, 17, 30).toIso8601String(),
                          'reason': reason,
                          'leaveType': leaveType,
                        });

                        if (!context.mounted) return;

                        if (res['success'] == true) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Gửi đơn nghỉ phép thành công!'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          _loadLeaveRequests();
                        } else {
                          setDialogState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Không thể gửi đơn. Vui lòng thử lại!'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                icon: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, size: 18),
                label: Text(isSubmitting ? 'Đang gửi...' : 'Gửi đơn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Hủy đơn xin nghỉ phép
  Future<void> _handleDeleteLeaveRequest(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận hủy đơn'),
        content: const Text('Bạn có chắc chắn muốn hủy đơn xin nghỉ phép này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final ok = await _service.deleteLeaveRequest(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Đã hủy đơn xin nghỉ phép!' : 'Không thể hủy đơn. Vui lòng thử lại!'),
            backgroundColor: ok ? Colors.teal : Colors.red,
          ),
        );
        _loadLeaveRequests();
      }
    }
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double liveSalary = (_summary?['totalSalary'] as num?)?.toDouble() ?? 0.0;
    final int totalDays = _summary?['totalDays'] ?? 0;
    final double totalHours = (_summary?['totalHours'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentUser?.fullName ?? 'Nhân viên', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text('${_currentUser?.position ?? "Nhân viên"} • ${_currentUser?.department ?? "Kỹ thuật"}',
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.face_retouching_natural),
                if (_hasRegisteredFace)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Cài đặt gương mặt đăng nhập (Face ID)',
            onPressed: _openFaceSettingsDialog,
          ),
          IconButton(icon: const Icon(Icons.restart_alt), tooltip: 'Reset hôm nay để test', onPressed: _handleResetToday),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Làm mới', onPressed: _loadAllData),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Đăng xuất', onPressed: _handleLogout),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.touch_app), text: 'Chấm công'),
            Tab(icon: Icon(Icons.graphic_eq), text: 'Đo tiếng ồn'),
            Tab(icon: Icon(Icons.history), text: 'Lịch sử'),
            Tab(icon: Icon(Icons.beach_access), text: 'Nghỉ phép'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Chấm công & Live Salary Meter
                _buildAttendanceTab(liveSalary, totalDays, totalHours),

                // TAB 2: Trạm đo tiếng ồn môi trường làm việc
                _buildNoiseMeterTab(),

                // TAB 3: Lịch sử chấm công cá nhân
                _buildHistoryTab(),

                // TAB 4: Đơn xin nghỉ phép
                _buildLeaveRequestTab(),
              ],
            ),
    );
  }

  Widget _buildAttendanceTab(double liveSalary, int totalDays, double totalHours) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TÍNH NĂNG MỚI ĐỀ XUẤT (1.0đ): LIVE SALARY METER
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.blue[900],
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bolt, color: Colors.amber, size: 20),
                          SizedBox(width: 6),
                          Text('BỘ TÍNH LƯƠNG THỜI GIAN THỰC',
                              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)),
                        child: const Text('Live Tracker', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${currencyFormat.format(liveSalary)} đ',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Text('Tổng thu nhập đã tích lũy tháng này', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const Divider(height: 24, color: Colors.white24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat('Ngày công', '$totalDays ngày'),
                      _buildMiniStat('Tổng giờ làm', '${totalHours.toStringAsFixed(1)} giờ'),
                      _buildMiniStat('Đúng giờ', '${_summary?['totalDays'] ?? 0 - (_summary?['lateCount'] ?? 0)} ngày'),
                    ],
                  ),
                  if (_todayAttendance?.noiseLevelDb != null) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.volume_up, size: 16, color: Colors.teal),
                        const SizedBox(width: 6),
                        Text(
                          'Độ ồn ca làm việc đã lưu: ${_todayAttendance!.noiseLevelDb!.toStringAsFixed(1)} dB',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // TRẠNG THÁI HÔM NAY
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Trạng thái hôm nay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(dateFormat.format(DateTime.now()), style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _hasCheckedIn ? Colors.green[50] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _hasCheckedIn ? Colors.green : Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('VÀO CA (IN)', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                              const SizedBox(height: 4),
                              Text(
                                _todayAttendance?.checkInTime != null
                                    ? timeFormat.format(_todayAttendance!.checkInTime!)
                                    : '--:--',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _hasCheckedIn ? Colors.green[800] : Colors.black54),
                              ),
                              Text(_todayAttendance?.status ?? 'Chưa vào',
                                  style: TextStyle(
                                      fontSize: 11, color: _todayAttendance?.status == 'Đi muộn' ? Colors.red : Colors.green)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _hasCheckedOut ? Colors.orange[50] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _hasCheckedOut ? Colors.orange : Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('RA CA (OUT)', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                              const SizedBox(height: 4),
                              Text(
                                _todayAttendance?.checkOutTime != null
                                    ? timeFormat.format(_todayAttendance!.checkOutTime!)
                                    : '--:--',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _hasCheckedOut ? Colors.orange[800] : Colors.black54),
                              ),
                              Text(_hasCheckedOut ? 'Đã ra về' : 'Chưa ra',
                                  style: const TextStyle(fontSize: 11, color: Colors.black54)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_todayAttendance?.noiseLevelDb != null) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.volume_up, size: 16, color: Colors.teal),
                        const SizedBox(width: 6),
                        Text(
                          'Độ ồn ca làm việc đã lưu: ${_todayAttendance!.noiseLevelDb!.toStringAsFixed(1)} dB',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // CARD CÀI ĐẶT GƯƠNG MẶT ĐĂNG NHẬP (FACE ID)
          _buildFaceLoginSettingsCard(),
          const SizedBox(height: 18),

          // 3 NÚT CHẤM CÔNG THUYẾT TRÌNH (3.5đ)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Chọn phương thức chấm công:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              InkWell(
                onTap: _handleResetToday,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.restart_alt, size: 16, color: Colors.indigo),
                      SizedBox(width: 4),
                      Text('Reset', style: TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // TÍNH NĂNG MỚI: ĐO ĐỘ ỒN MÔI TRƯỜNG NƠI LÀM VIỆC (QCVN 24:2016/BYT)
          InkWell(
            onTap: () => _tabController.animateTo(1),
            borderRadius: BorderRadius.circular(14),
            child: NoiseMeterWidget(
              compactMode: true,
              onRecordNoise: _handleRecordNoise,
            ),
          ),
          const SizedBox(height: 12),

          // Nút Chấm công GPS (Geofencing)
          ElevatedButton.icon(
            onPressed: _handleGpsCheckIn,
            icon: const Icon(Icons.location_on, size: 24),
            label: const Text('Chấm công bằng Vị trí GPS (Geofencing)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          // 4. Nút Ra ca (Check-out) nếu đã vào ca
          if (_hasCheckedIn && !_hasCheckedOut) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _handleCheckOut,
              icon: const Icon(Icons.logout, size: 24),
              label: const Text('Chấm công Ra ca (Check-out)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // WIDGET CARD CÀI ĐẶT GƯƠNG MẶT ĐĂNG NHẬP (FACE ID)
  Widget _buildFaceLoginSettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _hasRegisteredFace ? Colors.green.shade300 : Colors.blue.shade200,
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.face_retouching_natural,
                        color: _hasRegisteredFace ? Colors.green[700] : Colors.blue[800],
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'GƯƠNG MẶT ĐĂNG NHẬP',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _hasRegisteredFace ? Colors.green.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hasRegisteredFace ? Colors.green.shade400 : Colors.amber.shade400,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _hasRegisteredFace ? Icons.check_circle : Icons.warning_amber_rounded,
                        size: 13,
                        color: _hasRegisteredFace ? Colors.green[800] : Colors.amber[900],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _hasRegisteredFace ? 'ĐÃ CÀI ĐẶT' : 'CHƯA CÀI ĐẶT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _hasRegisteredFace ? Colors.green[900] : Colors.amber[900],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_registeredFaceBytes != null)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green.shade400, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _registeredFaceBytes!,
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _hasRegisteredFace ? Colors.green.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _hasRegisteredFace ? Icons.face : Icons.add_a_photo_outlined,
                      size: 32,
                      color: _hasRegisteredFace ? Colors.green[700] : Colors.blue[700],
                    ),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasRegisteredFace
                            ? (_currentUser?.fullName ?? 'Nhân viên')
                            : 'Kích hoạt Đăng nhập Face ID',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _hasRegisteredFace
                            ? 'Gương mặt đã lưu để đăng nhập Face ID và đối chiếu chấm công AI chống giả mạo.'
                            : 'Đăng ký ảnh khuôn mặt chuẩn của bạn để đăng nhập nhanh không cần mật khẩu.',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openFaceSettingsDialog,
                    icon: Icon(_hasRegisteredFace ? Icons.settings : Icons.add_a_photo, size: 16),
                    label: Text(_hasRegisteredFace ? 'Cài đặt / Đổi ảnh' : 'Cài đặt gương mặt ngay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasRegisteredFace ? Colors.blue[800] : Colors.blue[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (_hasRegisteredFace) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _handleTestFaceRecognition,
                    icon: const Icon(Icons.verified, size: 16),
                    label: const Text('Thử Face ID'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green[800],
                      side: BorderSide(color: Colors.green.shade600),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // TAB 2: TRẠM ĐO TIẾNG ỒN MÔI TRƯỜNG LÀM VIỆC (QCVN 24:2016/BYT)
  Widget _buildNoiseMeterTab() {
    return NoiseMeterWidget(
      compactMode: false,
      onRecordNoise: _handleRecordNoise,
    );
  }

  Future<void> _handleRecordNoise(double db) async {
    final res = await _service.recordNoiseLevel(db);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Đã lưu độ ồn môi trường: $db dB vào ca làm việc!'),
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 3),
        ),
      );
      _loadAllData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Lỗi khi lưu độ ồn'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return const Center(child: Text('Chưa có lịch sử chấm công'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _history.length,
      itemBuilder: (ctx, i) {
        final a = _history[i];
        final isLate = a.status == 'Đi muộn';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isLate ? Colors.red[100] : Colors.green[100],
              child: Icon(
                isLate ? Icons.timer_off : Icons.check_circle,
                color: isLate ? Colors.red : Colors.green,
              ),
            ),
            title: Text(dateFormat.format(a.date), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              'Vào: ${a.checkInTime != null ? timeFormat.format(a.checkInTime!) : "--"} | '
              'Ra: ${a.checkOutTime != null ? timeFormat.format(a.checkOutTime!) : "--"}\n'
              'Phương thức: ${a.checkInMethod} • Tổng: ${a.totalHours}h'
              '${a.noiseLevelDb != null ? " • 🔊 ${a.noiseLevelDb!.toStringAsFixed(1)} dB" : ""}',
              style: const TextStyle(fontSize: 12),
            ),
            isThreeLine: true,
            trailing: Text(
              '+${currencyFormat.format(a.salaryEarned)} đ',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900], fontSize: 13),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeaveRequestTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadLeaveRequests,
        child: _leaveRequests.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  const Icon(Icons.beach_access_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Chưa có đơn xin nghỉ phép nào\nBấm nút "+ Tạo đơn xin nghỉ" để gửi đơn mới',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _leaveRequests.length,
                itemBuilder: (ctx, i) {
                  final req = _leaveRequests[i];
                  Color statusColor = Colors.orange;
                  if (req.status == 'Đã duyệt') statusColor = Colors.green;
                  if (req.status == 'Từ chối') statusColor = Colors.red;

                  final sameDay = req.startDate.year == req.endDate.year &&
                      req.startDate.month == req.endDate.month &&
                      req.startDate.day == req.endDate.day;
                  final dateRangeStr = sameDay
                      ? dateFormat.format(req.startDate)
                      : '${dateFormat.format(req.startDate)} - ${dateFormat.format(req.endDate)}';

                  final isPending = req.status == 'Chờ duyệt';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withValues(alpha: 0.15),
                        child: Icon(Icons.beach_access, color: statusColor),
                      ),
                      title: Text(
                        '${req.leaveType} ($dateRangeStr)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Lý do: ${req.reason}\nTrạng thái: ${req.status}${req.approvedBy != null && req.approvedBy!.isNotEmpty ? " • Người duyệt: ${req.approvedBy}" : ""}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              req.status,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          if (isPending) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              tooltip: 'Hủy đơn',
                              onPressed: () => _handleDeleteLeaveRequest(req.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateLeaveDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tạo đơn xin nghỉ'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
    );
  }
}
