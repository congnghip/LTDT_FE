class UserModel {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String department;
  final String position;
  final String role;
  final double baseSalary;
  final bool faceRegistered;

  UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.department,
    required this.position,
    required this.role,
    this.baseSalary = 12000000,
    this.faceRegistered = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? json['userName'] ?? '',
      fullName: json['fullName'] ?? json['username'] ?? '',
      email: json['email'] ?? '',
      department: json['department'] ?? 'Kỹ thuật',
      position: json['position'] ?? 'Nhân viên',
      role: json['role'] ?? 'Employee',
      baseSalary: (json['baseSalary'] is num) ? (json['baseSalary'] as num).toDouble() : 12000000,
      faceRegistered: json['faceRegistered'] ?? true,
    );
  }
}

class AttendanceModel {
  final int id;
  final String userId;
  final String? userName;
  final String? fullName;
  final String? department;
  final String? shiftName;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double totalHours;
  final String status;
  final String checkInMethod;
  final double salaryEarned;
  final String? note;
  final String? faceImageUrl;
  final double? noiseLevelDb;

  AttendanceModel({
    required this.id,
    required this.userId,
    this.userName,
    this.fullName,
    this.department,
    this.shiftName,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.totalHours = 0,
    required this.status,
    required this.checkInMethod,
    this.salaryEarned = 0,
    this.note,
    this.faceImageUrl,
    this.noiseLevelDb,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? '',
      userName: json['userName'],
      fullName: json['fullName'],
      department: json['department'],
      shiftName: json['shiftName'],
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      checkInTime: json['checkInTime'] != null ? DateTime.parse(json['checkInTime']) : null,
      checkOutTime: json['checkOutTime'] != null ? DateTime.parse(json['checkOutTime']) : null,
      totalHours: (json['totalHours'] is num) ? (json['totalHours'] as num).toDouble() : 0.0,
      status: json['status'] ?? 'Đúng giờ',
      checkInMethod: json['checkInMethod'] ?? 'GPS',
      salaryEarned: (json['salaryEarned'] is num) ? (json['salaryEarned'] as num).toDouble() : 0.0,
      note: json['note'],
      faceImageUrl: json['faceImageUrl'],
      noiseLevelDb: (json['noiseLevelDb'] is num) ? (json['noiseLevelDb'] as num).toDouble() : null,
    );
  }
}

class ShiftModel {
  final int id;
  final String name;
  final String startTime;
  final String endTime;
  final int lateGraceMinutes;
  final double hourlyRate;

  ShiftModel({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.lateGraceMinutes = 15,
    this.hourlyRate = 50000,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      startTime: json['startTime']?.toString() ?? '08:00',
      endTime: json['endTime']?.toString() ?? '17:00',
      lateGraceMinutes: json['lateGraceMinutes'] ?? 15,
      hourlyRate: (json['hourlyRate'] is num) ? (json['hourlyRate'] as num).toDouble() : 50000,
    );
  }
}

class LeaveRequestModel {
  final int id;
  final String userId;
  final String? userName;
  final String? fullName;
  final String? department;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String leaveType;
  final String status;
  final DateTime createdAt;
  final String? approvedBy;

  LeaveRequestModel({
    required this.id,
    required this.userId,
    this.userName,
    this.fullName,
    this.department,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.leaveType,
    required this.status,
    required this.createdAt,
    this.approvedBy,
  });

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? '',
      userName: json['userName'],
      fullName: json['fullName'],
      department: json['department'],
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : DateTime.now(),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : DateTime.now(),
      reason: json['reason'] ?? '',
      leaveType: json['leaveType'] ?? 'Nghỉ phép năm',
      status: json['status'] ?? 'Chờ duyệt',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      approvedBy: json['approvedBy'],
    );
  }
}
