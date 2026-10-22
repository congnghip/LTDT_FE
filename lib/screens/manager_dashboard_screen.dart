import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../services/chamcong_service.dart';
import 'login_screen.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> with SingleTickerProviderStateMixin {
  final ChamCongService _service = ChamCongService();
  late TabController _tabController;

  List<AttendanceModel> _attendances = [];
  List<ShiftModel> _shifts = [];
  List<LeaveRequestModel> _pendingLeaves = [];
  bool _isLoading = false;

  final dateFormat = DateFormat("dd/MM/yyyy");
  final timeFormat = DateFormat("HH:mm");
  final currencyFormat = NumberFormat("#,##0", "vi_VN");

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadAttendances(),
      _loadShifts(),
      _loadPendingLeaves(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadAttendances() async {
    final list = await _service.getAllAttendances(date: DateTime.now());
    setState(() => _attendances = list);
  }

  Future<void> _loadShifts() async {
    final list = await _service.getShifts();
    setState(() => _shifts = list);
  }

  Future<void> _loadPendingLeaves() async {
    final list = await _service.getAllLeaveRequests(status: 'Chờ duyệt');
    setState(() => _pendingLeaves = list);
  }

  // === QUẢN LÝ CA LÀM VIỆC (CRUD) ===
  Future<void> _showAddShiftDialog() async {
    final nameCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: '08:00');
    final endCtrl = TextEditingController(text: '17:00');
    final rateCtrl = TextEditingController(text: '50000');
    final graceCtrl = TextEditingController(text: '15');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.add_alarm, color: Colors.purple[800]),
            const SizedBox(width: 8),
            const Text('Thêm ca làm việc mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên ca làm việc *',
                  hintText: 'Ví dụ: Ca Sáng, Ca Tối',
                ),
              ),
              TextField(
                controller: startCtrl,
                decoration: const InputDecoration(
                  labelText: 'Giờ bắt đầu (HH:mm)',
                  hintText: '08:00',
                ),
              ),
              TextField(
                controller: endCtrl,
                decoration: const InputDecoration(
                  labelText: 'Giờ kết thúc (HH:mm)',
                  hintText: '17:00',
                ),
              ),
              TextField(
                controller: rateCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Đơn giá lương (đ/giờ)',
                  hintText: '50000',
                ),
              ),
              TextField(
                controller: graceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cho phép trễ tối đa (phút)',
                  hintText: '15',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[800], foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final ok = await _service.createShift({
                'name': nameCtrl.text.trim(),
                'startTime': startCtrl.text.trim(),
                'endTime': endCtrl.text.trim(),
                'hourlyRate': double.tryParse(rateCtrl.text.trim()) ?? 50000,
                'lateGraceMinutes': int.tryParse(graceCtrl.text.trim()) ?? 15,
              });
              if (ok && mounted) {
                _loadShifts();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thêm ca làm việc thành công!'), backgroundColor: Colors.green),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thêm ca làm việc thất bại!'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditShiftDialog(ShiftModel shift) async {
    final nameCtrl = TextEditingController(text: shift.name);
    final startCtrl = TextEditingController(text: shift.startTime);
    final endCtrl = TextEditingController(text: shift.endTime);
    final rateCtrl = TextEditingController(text: shift.hourlyRate.toInt().toString());
    final graceCtrl = TextEditingController(text: shift.lateGraceMinutes.toString());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit_note, color: Colors.purple[800]),
            const SizedBox(width: 8),
            const Text('Chỉnh sửa ca làm việc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Tên ca làm việc *'),
              ),
              TextField(
                controller: startCtrl,
                decoration: const InputDecoration(labelText: 'Giờ bắt đầu (HH:mm)'),
              ),
              TextField(
                controller: endCtrl,
                decoration: const InputDecoration(labelText: 'Giờ kết thúc (HH:mm)'),
              ),
              TextField(
                controller: rateCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Đơn giá lương (đ/giờ)'),
              ),
              TextField(
                controller: graceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cho phép trễ tối đa (phút)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[800], foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final ok = await _service.updateShift(shift.id, {
                'name': nameCtrl.text.trim(),
                'startTime': startCtrl.text.trim(),
                'endTime': endCtrl.text.trim(),
                'hourlyRate': double.tryParse(rateCtrl.text.trim()) ?? shift.hourlyRate,
                'lateGraceMinutes': int.tryParse(graceCtrl.text.trim()) ?? shift.lateGraceMinutes,
              });
              if (ok && mounted) {
                _loadShifts();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cập nhật ca làm việc thành công!'), backgroundColor: Colors.green),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cập nhật thất bại!'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteShift(ShiftModel shift) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa ca làm'),
        content: Text('Bạn có chắc muốn xóa "${shift.name}" không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final ok = await _service.deleteShift(shift.id);
      if (ok && mounted) {
        _loadShifts();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa ca "${shift.name}"'), backgroundColor: Colors.green),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa ca thất bại!'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // === PHÊ DUYỆT ĐƠN NGHỈ PHÉP ===
  Future<void> _handleApproveLeave(int id, String status) async {
    final ok = await _service.updateLeaveStatus(id, status);
    if (ok && mounted) {
      _loadPendingLeaves();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã cập nhật đơn: $status'), backgroundColor: Colors.green),
      );
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
    final checkedInCount = _attendances.length;
    final lateCount = _attendances.where((a) => a.status == 'Đi muộn').length;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DASHBOARD QUẢN LÝ CA TRỰC', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Quản lý: Trần Thị Bình (Trưởng phòng)', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Làm mới', onPressed: _loadData),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Đăng xuất', onPressed: _handleLogout),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: const Icon(Icons.bar_chart), text: 'Giám sát ca (${_attendances.length})'),
            Tab(icon: const Icon(Icons.schedule), text: 'Ca làm việc (${_shifts.length})'),
            Tab(icon: const Icon(Icons.approval), text: 'Duyệt đơn (${_pendingLeaves.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Giám sát ca trực
                _buildLiveMonitorTab(checkedInCount, lateCount),

                // TAB 2: Quản lý ca làm việc (CRUD)
                _buildShiftTab(),

                // TAB 3: Duyệt đơn xin nghỉ
                _buildLeaveApprovalTab(),
              ],
            ),
    );
  }

  Widget _buildLiveMonitorTab(int checkedIn, int late) {
    return Column(
      children: [
        // Thẻ tóm tắt tình hình ca trực
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.purple[50],
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryBox('Đã Check-in hôm nay', '$checkedIn người', Colors.purple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryBox('Đi muộn', '$late người', Colors.red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryBox('Đúng giờ', '${checkedIn - late} người', Colors.green),
              ),
            ],
          ),
        ),

        // Danh sách nhân viên trong ca
        Expanded(
          child: _attendances.isEmpty
              ? const Center(child: Text('Chưa có nhân viên nào check-in hôm nay'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _attendances.length,
                  itemBuilder: (ctx, i) {
                    final a = _attendances[i];
                    final isLate = a.status == 'Đi muộn';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isLate ? Colors.red[100] : Colors.green[100],
                          child: Icon(isLate ? Icons.warning : Icons.check, color: isLate ? Colors.red : Colors.green),
                        ),
                        title: Text(a.fullName ?? a.userName ?? 'Nhân viên',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Vào: ${a.checkInTime != null ? timeFormat.format(a.checkInTime!) : "--"} | Phương thức: ${a.checkInMethod}\nPhòng: ${a.department}${a.noiseLevelDb != null ? " • 🔊 ${a.noiseLevelDb!.toStringAsFixed(1)} dB" : ""}'),
                        isThreeLine: true,
                        trailing: Text(a.status,
                            style: TextStyle(color: isLate ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // TAB 2: Quản lý ca làm việc (CRUD)
  Widget _buildShiftTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.purple[50],
            child: Row(
              children: [
                Icon(Icons.schedule, color: Colors.purple[800], size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('QUẢN LÝ THIẾT LẬP CA LÀM VIỆC',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple[900])),
                      Text('Cấu hình khung giờ bắt đầu, kết thúc & đơn giá lương giờ cho nhân viên',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _shifts.isEmpty
                ? const Center(child: Text('Chưa có ca làm việc nào. Bấm nút bên dưới để thêm.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _shifts.length,
                    itemBuilder: (ctx, i) {
                      final s = _shifts[i];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.alarm, color: Colors.purple.shade700, size: 26),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text('${s.startTime} - ${s.endTime}',
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.payments_outlined, size: 14, color: Colors.green[700]),
                                            const SizedBox(width: 4),
                                            Text('${currencyFormat.format(s.hourlyRate)} đ/h',
                                                style: TextStyle(fontSize: 13, color: Colors.green[800], fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('⏱️ Cho phép trễ: ${s.lateGraceMinutes} phút',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                    tooltip: 'Chỉnh sửa ca',
                                    onPressed: () => _showEditShiftDialog(s),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'Xóa ca',
                                    onPressed: () => _confirmDeleteShift(s),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddShiftDialog,
        icon: const Icon(Icons.add_alarm),
        label: const Text('Thêm Ca Làm'),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSummaryBox(String title, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color[800])),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[700]), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildLeaveApprovalTab() {
    if (_pendingLeaves.isEmpty) {
      return const Center(child: Text('Không có đơn xin nghỉ phép nào cần duyệt'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pendingLeaves.length,
      itemBuilder: (ctx, i) {
        final req = _pendingLeaves[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(req.fullName ?? 'Nhân viên', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(dateFormat.format(req.startDate), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                Text('Loại nghỉ: ${req.leaveType} | Phòng: ${req.department ?? "Kỹ thuật"}'),
                Text('Lý do: ${req.reason}', style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => _handleApproveLeave(req.id, 'Đã duyệt'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: const Text('Duyệt đơn'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _handleApproveLeave(req.id, 'Từ chối'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Từ chối'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
