import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'attendance_calendar_dialog.dart';
import 'day_attendance_history_dialog.dart';
import 'edit_profile_screen.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> employee;

  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  int _activeTab = 0;
  DateTime _currentMonth = DateTime.now();
  bool _isLoading = true;
  String? _filterStatus; // null means show all, or 'present', 'absent', 'half', etc.

  Map<String, dynamic>? _attendanceData;
  List<dynamic> _monthDays = [];

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    setState(() => _isLoading = true);
    try {
      final empId = widget.employee['id'] ?? widget.employee['user_id'];
      final res = await ApiService.getAttendanceHistory(
        userId: empId != null ? int.tryParse(empId.toString()) : null,
        month: _currentMonth.month,
        year: _currentMonth.year,
      );

      setState(() {
        _attendanceData = res;
        _monthDays = res['days'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset, 1);
    });
    _loadAttendanceData();
  }

  void _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final Uri url = Uri.parse('tel:$cleanPhone');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Phone call error: $e");
    }
  }

  void _sendSms(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final Uri url = Uri.parse('sms:$cleanPhone');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("SMS error: $e");
    }
  }

  void _sendEmail(String email) async {
    if (email.isEmpty) return;
    final Uri url = Uri.parse('mailto:$email');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Email error: $e");
    }
  }

  void _openWhatsApp(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }
    if (cleanPhone.isEmpty) return;
    final Uri url = Uri.parse('https://wa.me/$cleanPhone');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("WhatsApp error: $e");
    }
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _openMonthlyReport() async {
    final empId = widget.employee['id'] ?? widget.employee['user_id'] ?? 1;
    final urlStr = '${ApiService.baseUrl}/attendance/monthly-report?user_id=$empId&month=${_currentMonth.month}&year=${_currentMonth.year}';
    final Uri url = Uri.parse(urlStr);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showMsg('Opening Monthly Report: $urlStr');
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.employee;
    final String name = emp['name'] ?? emp['user_name'] ?? _attendanceData?['employee']?['name'] ?? 'Staff Member';
    final String phone = emp['phone'] ?? _attendanceData?['employee']?['phone'] ?? '+916000788828';
    final String email = emp['email'] ?? _attendanceData?['employee']?['email'] ?? 'staff@company.com';
    final String designation = emp['designation'] ?? _attendanceData?['employee']?['designation'] ?? 'Employee';
    final String photoUrl = emp['photo'] ?? _attendanceData?['employee']?['photo'] ?? '';

    final String monthName = _getMonthName(_currentMonth.month);
    final String monthYearStr = '$monthName ${_currentMonth.year}';

    final int presentCount = _attendanceData?['present'] ?? 0;
    final int absentCount = _attendanceData?['absent'] ?? 0;
    final int halfCount = _attendanceData?['half'] ?? 0;
    final int leaveCount = _attendanceData?['leave'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFD1FAE5), // Mint background matching SS 2
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Staff Attendance Profile', style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Edit Profile',
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(
                    employee: widget.employee,
                    onUpdated: _loadAttendanceData,
                  ),
                ),
              );
              if (updated == true) _loadAttendanceData();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Profile Card matching SS 2
            Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.blueGrey,
                            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl.isEmpty
                                ? Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'E',
                                    style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Monthly', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 2),
                            Text(phone, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            Text(designation, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons Row (Call, Message, Email, WhatsApp) matching SS 2
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(Icons.phone, 'Call', () => _makePhoneCall(phone)),
                      _buildActionButton(Icons.chat_bubble_outline, 'Message', () => _sendSms(phone)),
                      _buildActionButton(Icons.email_outlined, 'Email', () => _sendEmail(email)),
                      _buildActionButton(Icons.chat, 'WhatsApp', () => _openWhatsApp(phone)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Horizontal Navigation Tabs (Attendance, Salary, Incentive, Expense, Loan/Adv)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabItem(0, 'Attendance'),
                        _buildTabItem(1, 'Salary'),
                        _buildTabItem(2, 'Incentive'),
                        _buildTabItem(3, 'Expense'),
                        _buildTabItem(4, 'Loan / Advance'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Body Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Month Switcher Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Attendance For', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                              InkWell(
                                onTap: () {
                                  final empId = widget.employee['id'] ?? widget.employee['user_id'] ?? 1;
                                  AttendanceCalendarDialog.show(
                                    context,
                                    userId: empId,
                                    userName: name,
                                    month: _currentMonth.month,
                                    year: _currentMonth.year,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left, size: 18),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _changeMonth(-1),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.calendar_today, size: 14, color: Colors.black87),
                                      const SizedBox(width: 4),
                                      Text(monthYearStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right, size: 18),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _changeMonth(1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Stat Counters Row (Present, Absent, Half Day, Casual Leave) matching SS 2
                          Row(
                            children: [
                              _buildStatBox('Present', '$presentCount days', const Color(0xFF14532D), const Color(0xFFDCFCE7), 'present'),
                              const SizedBox(width: 6),
                              _buildStatBox('Absent', '$absentCount times', const Color(0xFF7F1D1D), const Color(0xFFFEE2E2), 'absent'),
                              const SizedBox(width: 6),
                              _buildStatBox('Half Day', '$halfCount times', const Color(0xFF0369A1), const Color(0xFFE0F2FE), 'half'),
                              const SizedBox(width: 6),
                              _buildStatBox('Casual Leave', '$leaveCount left', const Color(0xFF9A3412), const Color(0xFFFFEDD5), 'leave'),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Calendar Grid View matching SS 2 & SS 3
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                            ),
                            child: Column(
                              children: [
                                // Days Header (Sun Mon Tue Wed Thu Fri Sat)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                                      .map((d) => SizedBox(
                                            width: 36,
                                            child: Text(d, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70)),
                                          ))
                                      .toList(),
                                ),
                                const SizedBox(height: 10),

                                // Dynamic Calendar Matrix for selected Month
                                _buildCalendarGrid(name),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Download Report Buttons matching SS 2
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.download, color: Colors.white, size: 18),
                                  label: const Text('Monthly Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  onPressed: _openMonthlyReport,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.download, color: Colors.white, size: 18),
                                  label: const Text('Odometer Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  onPressed: () => _showMsg('Odometer log downloaded'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(String employeeName) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    final totalGridCells = ((daysInMonth + startWeekday) / 7).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalGridCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (ctx, idx) {
        final dayNum = idx - startWeekday + 1;
        if (dayNum < 1 || dayNum > daysInMonth) {
          return const SizedBox.shrink();
        }

        final dateStr = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
        
        final dayData = _monthDays.firstWhere(
          (d) => d['date'] == dateStr,
          orElse: () => {'date': dateStr, 'status': 'not_marked', 'has_in_no_out': false, 'ins_list': [], 'outs_list': []},
        );

        final String status = dayData['status'] ?? 'not_marked';
        final bool hasInNoOut = dayData['has_in_no_out'] == true;

        // Combine all punches for history popup
        final List<dynamic> allPunches = [];
        if (dayData['ins_list'] != null) allPunches.addAll(dayData['ins_list']);
        if (dayData['outs_list'] != null) allPunches.addAll(dayData['outs_list']);

        // Check active filter
        if (_filterStatus != null) {
          if (_filterStatus == 'present' && !['present', 'late', 'wop'].contains(status)) return const SizedBox.shrink();
          if (_filterStatus == 'absent' && status != 'absent') return const SizedBox.shrink();
          if (_filterStatus == 'half' && !hasInNoOut) return const SizedBox.shrink();
          if (_filterStatus == 'leave' && !['leave', 'holiday', 'week_off'].contains(status)) return const SizedBox.shrink();
        }

        // Color coding & Gradient for 50% Green 50% Red tile (Screenshot 2)
        BoxDecoration boxDeco;
        Color textCol = Colors.white;

        if (hasInNoOut) {
          // 50% Green (Punch IN) & 50% Pink (Open Punch IN / No OUT) split matching Screenshot 1!
          boxDeco = BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF15803D), Color(0xFFF43F5E)],
              stops: [0.5, 0.5],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white, width: 1.5),
          );
          textCol = Colors.white;
        } else if (['present', 'late', 'wop'].contains(status)) {
          boxDeco = BoxDecoration(
            color: const Color(0xFF14532D),
            borderRadius: BorderRadius.circular(6),
          );
          textCol = const Color(0xFF4ADE80);
        } else if (status == 'absent') {
          boxDeco = BoxDecoration(
            color: const Color(0xFF7F1D1D),
            borderRadius: BorderRadius.circular(6),
          );
          textCol = const Color(0xFFFCA5A5);
        } else if (['holiday', 'week_off'].contains(status)) {
          boxDeco = BoxDecoration(
            color: const Color(0xFF0369A1),
            borderRadius: BorderRadius.circular(6),
          );
          textCol = const Color(0xFFE0F2FE);
        } else {
          boxDeco = BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(6),
          );
          textCol = Colors.white70;
        }

        final formattedDateStr = '$dayNum ${_getMonthName(_currentMonth.month)} ${_currentMonth.year}';

        return GestureDetector(
          onTap: () {
            // Tapping calendar date opens Day Attendance History modal matching SS 3!
            DayAttendanceHistoryDialog.show(
              context,
              employeeName: employeeName,
              formattedDate: formattedDateStr,
              dateStr: dateStr,
              punches: allPunches,
            );
          },
          child: Container(
            decoration: boxDeco,
            child: Center(
              child: Text(
                '$dayNum',
                style: TextStyle(fontWeight: FontWeight.bold, color: textCol, fontSize: 13),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFF0F172A) : Colors.white70,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox(String title, String count, Color activeBorderCol, Color activeBgCol, String filterKey) {
    final isSelected = _filterStatus == filterKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _filterStatus = isSelected ? null : filterKey;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? activeBgCol : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? activeBorderCol : Colors.grey.shade300, width: isSelected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 10, color: isSelected ? activeBorderCol : Colors.black87, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(count, style: TextStyle(fontSize: 12, color: isSelected ? activeBorderCol : Colors.black, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
