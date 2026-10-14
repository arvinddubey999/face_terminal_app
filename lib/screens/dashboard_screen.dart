import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'attendance_scan_screen.dart';
import 'attendance_calendar_dialog.dart';
import 'employee_detail_screen.dart';
import 'edit_profile_screen.dart';
import 'tasks_screen.dart';
import 'leave_request_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserModel user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentBottomNavIndex = 0;
  Map<String, dynamic>? _todayInfo;
  Map<String, dynamic> _statsCounts = {};
  String _statsDate = 'Today';
  List<dynamic> _employeesList = [];
  List<dynamic> _filteredEmployees = [];
  List<dynamic> _birthdaysList = [];
  List<String> _companiesList = [];
  String? _selectedCompanyFilter;
  Map<String, dynamic>? _staffHistoryData;
  bool _isLoading = true;

  bool _showAllStats = false; // Show More / Show Less toggle state
  String? _activeBadgeFilter;
  final TextEditingController _searchController = TextEditingController();

  final String supportPhone = '8169426418';
  final String supportEmail = 'arvinddubey999@gmail.com';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _checkAndRequestPermissions();
    _initFcmToken();
  }

  void _initFcmToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await ApiService.saveFcmToken(token);
        await ApiService.registerFcmToken(token);
      }
      await messaging.subscribeToTopic('attendance');
    } catch (e) {
      debugPrint("FCM registration in dashboard error: $e");
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      await [
        Permission.location,
        Permission.locationWhenInUse,
        Permission.camera,
      ].request();
    } catch (e) {
      debugPrint("Native permission error: $e");
    }
  }

  void _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final todayInfo = await ApiService.getTodayPunches();
      final statsRes = await ApiService.getAttendanceStatistics();

      List<dynamic> emps = statsRes['employees'] ?? [];
      List<dynamic> bdays = statsRes['birthdays'] ?? [];
      Map<String, dynamic> counts = statsRes['counts'] ?? {};

      // Extract unique company names
      Set<String> comps = {};
      for (var e in emps) {
        if (e['company_name'] != null && e['company_name'].toString().isNotEmpty) {
          comps.add(e['company_name'].toString());
        }
      }

      // If user is Staff, load staff attendance history
      Map<String, dynamic>? history;
      if (!widget.user.isManager) {
        history = await ApiService.getAttendanceHistory(userId: widget.user.id);
      }

      setState(() {
        _todayInfo = todayInfo;
        _statsCounts = counts;
        _statsDate = statsRes['date'] ?? 'Today';
        _employeesList = emps;
        _birthdaysList = bdays;
        _companiesList = comps.toList();
        _staffHistoryData = history;
        _isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredEmployees = _employeesList.where((emp) {
        final name = (emp['name'] ?? '').toString().toLowerCase();
        final dept = (emp['department'] ?? '').toString().toLowerCase();
        final desig = (emp['designation'] ?? '').toString().toLowerCase();
        final role = (emp['role'] ?? '').toString().toLowerCase();
        final comp = (emp['company_name'] ?? '').toString();

        final matchesQuery = query.isEmpty || name.contains(query) || dept.contains(query) || desig.contains(query);

        if (!matchesQuery) return false;

        // Company filter match
        if (_selectedCompanyFilter != null && _selectedCompanyFilter!.isNotEmpty) {
          if (comp != _selectedCompanyFilter) return false;
        }

        if (_activeBadgeFilter != null) {
          switch (_activeBadgeFilter) {
            case 'not_marked':
              return emp['is_not_marked'] == true || emp['today_status'] == 'not_marked';
            case 'present':
              return emp['is_present'] == true;
            case 'absence':
              return emp['is_absent'] == true || emp['today_status'] == 'absent';
            case 'late':
              return emp['is_late'] == true || emp['today_status'] == 'late';
            case 'leave':
              return emp['is_leave'] == true || emp['today_status'] == 'leave';
            case 'early':
              return emp['is_early'] == true;
            case 'heads':
              return emp['status'] == 'active';
            case 'archived':
              return emp['status'] != 'active';
            case 'admin':
              return role == 'admin';
            case 'manager':
              return role == 'manager';
            case 'employee':
              return role == 'employee';
            default:
              return true;
          }
        }
        return true;
      }).toList();
    });
  }

  void _handleLogout() async {
    await ApiService.clearToken();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _launchUrl(String urlStr) async {
    try {
      final Uri url = Uri.parse(urlStr);
      final bool launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint("Launch URL error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManager = widget.user.isManager;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19), // Dark background matching SS 3 & 4
      body: SafeArea(
        child: IndexedStack(
          index: _currentBottomNavIndex,
          children: isManager
              ? [
                  _buildHandPunchScreen(), // Tab 0: Punch (Manager Punch IN / OUT for any staff with Back camera default)
                  _buildManagerStaffTab(), // Tab 1: Staff (Manager view with 11 badges & staff list)
                  TasksScreen(user: widget.user), // Tab 2: Work
                  LeaveRequestScreen(user: widget.user), // Tab 3: Requests
                  _buildSettingsTab(), // Tab 4: Settings
                ]
              : [
                  _buildHandPunchScreen(), // Tab 0: Punch
                  _buildSalaryTab(), // Tab 1: Salary
                  _buildStaffAttendanceDashboardTab(), // Tab 2: You (Staff Dashboard matching staff dashboard 1 & 2)
                  TasksScreen(user: widget.user), // Tab 3: Work
                  LeaveRequestScreen(user: widget.user), // Tab 4: Requests
                  _buildSettingsTab(), // Tab 5: Settings
                ],
        ),
      ),

      // Bottom Navigation Bar with exact role-based menu config
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentBottomNavIndex,
        onTap: (index) => setState(() => _currentBottomNavIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: const Color(0xFF38BDF8),
        unselectedItemColor: Colors.white60,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: isManager
            ? const [
                BottomNavigationBarItem(icon: Icon(Icons.front_hand), label: 'Punch'),
                BottomNavigationBarItem(icon: Icon(Icons.people_alt), label: 'Staff'),
                BottomNavigationBarItem(icon: Icon(Icons.work_outline), label: 'Work'),
                BottomNavigationBarItem(icon: Icon(Icons.holiday_village_outlined), label: 'Requests'),
                BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
              ]
            : const [
                BottomNavigationBarItem(icon: Icon(Icons.front_hand), label: 'Punch'),
                BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Salary'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'You'),
                BottomNavigationBarItem(icon: Icon(Icons.work_outline), label: 'Work'),
                BottomNavigationBarItem(icon: Icon(Icons.holiday_village_outlined), label: 'Requests'),
                BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
              ],
      ),
    );
  }

  // ==========================================
  // TAB: HAND PUNCH SCREEN (STAFF ONLY)
  // ==========================================
  Widget _buildHandPunchScreen() {
    final companyName = widget.user.companyName ?? 'TULSI FABRICS INDIA PVT LTD';
    final nextAction = _todayInfo?['next_action'] ?? 'in';
    final isIn = nextAction == 'out';

    return Column(
      children: [
        // App Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFF0F172A),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                companyName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadDashboardData,
              ),
            ],
          ),
        ),

        // Ready to mark attendance banner
        Container(
          width: double.infinity,
          color: const Color(0xFF1E293B),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text(
            'Ready to mark your attendance ${nextAction.toUpperCase()}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),

        // Dynamic Shift Banner matching sleek styling
        Container(
          width: double.infinity,
          color: const Color(0xFF1E293B),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text(
            'Current Shift: ${widget.user.shiftName ?? "General Staff Shift (09:45 AM - 08:30 PM)"}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),

        // Center ADCodeNexus Brand Logo
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBrandLogoWidget(size: 110),
              const SizedBox(height: 24),
              Text(
                isIn ? "Press the 'OUT' button to punch out for today" : "Press the 'IN' button to punch in for today",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),

        // Bottom Punch Button
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isIn ? const Color(0xFFDC2626) : const Color(0xFF22C55E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (widget.user.isManager) {
                  _showManagerEmployeePickerAndPunch(nextAction);
                } else {
                  _openScanScreen(nextAction, null);
                }
              },
              child: Text(
                isIn ? 'Punch OUT' : 'Punch IN',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showManagerEmployeePickerAndPunch(String nextAction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Staff for Attendance', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF38BDF8), child: Icon(Icons.person, color: Colors.black)),
              title: Text('Self (${widget.user.name})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Mark your own attendance (Front Camera)', style: TextStyle(color: Colors.white54, fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _openScanScreen(nextAction, null);
              },
            ),
            const Divider(color: Colors.white12),
            const Text('Select Employee to Punch', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: _employeesList.isEmpty
                  ? const Center(child: Text('No staff members available', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: _employeesList.length,
                      itemBuilder: (c, idx) {
                        final emp = _employeesList[idx];
                        final String empName = emp['name'] ?? 'Staff';
                        final String empDept = emp['designation'] ?? emp['department'] ?? 'Employee';
                        final String? photo = emp['photo'];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueGrey,
                            backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                            child: photo == null || photo.isEmpty ? Text(empName[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null,
                          ),
                          title: Text(empName, style: const TextStyle(color: Colors.white, fontSize: 14)),
                          subtitle: Text(empDept, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                          onTap: () {
                            Navigator.pop(ctx);
                            _openScanScreen(nextAction, emp['id']);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openScanScreen(String type, int? targetEmployeeId) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceScanScreen(
          user: widget.user,
          initialType: type,
          targetEmployeeId: targetEmployeeId,
        ),
      ),
    );
    if (updated == true) _loadDashboardData();
  }

  // ==========================================
  // TAB: MANAGER STAFF VIEW (WITH 11 BADGES & DYNAMIC FILTERING)
  // ==========================================
  Widget _buildManagerStaffTab() {
    final int notMarkedCount = _statsCounts['not_marked'] ?? 0;
    final int presentCount = _statsCounts['present'] ?? 0;
    final int absenceCount = _statsCounts['absence'] ?? 0;
    final int lateCount = _statsCounts['late'] ?? 0;
    final int leaveCount = _statsCounts['leave'] ?? 0;
    final int earlyCount = _statsCounts['early'] ?? 0;
    final int headsCount = _statsCounts['heads'] ?? _employeesList.length;
    final int archivedCount = _statsCounts['archived'] ?? 0;
    final int adminCount = _statsCounts['admin'] ?? 0;
    final int managerCount = _statsCounts['manager'] ?? 0;
    final int employeeCount = _statsCounts['employee'] ?? 0;

    final companyName = widget.user.companyName ?? 'TULSI FABRICS INDIA PVT LTD';

    return Container(
      color: const Color(0xFF0B0F19), // Dark theme matching SS 3 & 4
      child: RefreshIndicator(
        onRefresh: () async => _loadDashboardData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header Bar
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF1E293B),
                    child: Text(companyName[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      companyName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF38BDF8),
                    child: Text(
                      widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : 'M',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text('Good day, ${widget.user.name}.', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 14),

              // Attendance Statistics Card (Matching Screenshot 3 & 4)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF181C28), // Dark card background matching SS 3 & 4
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Attendance Statistics',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF262C3A), borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            children: [
                              Icon(Icons.calendar_today, size: 12, color: Colors.white70),
                              SizedBox(width: 4),
                              Text('Today', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text('Based on $_statsDate', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                    const SizedBox(height: 16),

                    // Badge Grid Display
                    LayoutBuilder(builder: (ctx, constraints) {
                      final itemWidth = (constraints.maxWidth - 16) / 3;

                      final List<Widget> badgeWidgets = [
                        _buildStatBadge(notMarkedCount, 'Staff', 'Not marked', const Color(0xFF94A3B8), 'not_marked', itemWidth),
                        _buildStatBadge(presentCount, 'Staff', 'Present', const Color(0xFF22C55E), 'present', itemWidth),
                        _buildStatBadge(absenceCount, 'Staff', 'Absence', const Color(0xFFEF4444), 'absence', itemWidth),
                        _buildStatBadge(lateCount, 'Staff', 'Late', const Color(0xFFF59E0B), 'late', itemWidth),
                        _buildStatBadge(leaveCount, '', 'Leave', const Color(0xFFA855F7), 'leave', itemWidth),
                        _buildStatBadge(earlyCount, '', 'Early', const Color(0xFFF97316), 'early', itemWidth),
                        if (_showAllStats) ...[
                          _buildStatBadge(headsCount, 'Staff', 'Heads', const Color(0xFF3B82F6), 'heads', itemWidth),
                          _buildStatBadge(archivedCount, 'Staff', 'Archived', const Color(0xFF0EA5E9), 'archived', itemWidth),
                          _buildStatBadge(adminCount, 'Staff', 'Admin', const Color(0xFF10B981), 'admin', itemWidth),
                          _buildStatBadge(managerCount, 'Staff', 'Manager', const Color(0xFFF59E0B), 'manager', itemWidth),
                          _buildStatBadge(employeeCount, 'Staff', 'Employee', const Color(0xFF3B82F6), 'employee', itemWidth),
                        ],
                      ];

                      return Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: badgeWidgets,
                      );
                    }),
                    const SizedBox(height: 14),

                    // Show More / Show Less Toggle Button (Matching SS 3 & 4)
                    Center(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _showAllStats = !_showAllStats;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _showAllStats ? 'Show less' : 'Show more',
                                style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _showAllStats ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: const Color(0xFF38BDF8),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // TODAY'S BIRTHDAYS SECTION (Placed directly below Attendance Statistics matching screenshot media_1791013025802)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF181C28),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFF43F5E).withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.cake, color: Color(0xFFF43F5E), size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Today & Upcoming Birthdays", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text("Staff celebrations in the next 7 days", style: TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _birthdaysList.isEmpty
                        ? const Text("No birthdays in the next 7 days", style: TextStyle(color: Colors.white38, fontSize: 13))
                        : SizedBox(
                            height: 115,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _birthdaysList.length,
                              itemBuilder: (ctx, idx) {
                                final bDay = _birthdaysList[idx];
                                final String bName = bDay['name'] ?? 'Staff';
                                final String? bPhoto = bDay['photo'];
                                final int bAge = bDay['age'] ?? 0;
                                final int daysUntil = bDay['days_until'] ?? 0;
                                final bool isToday = bDay['is_today'] ?? (daysUntil == 0);

                                return Container(
                                  width: 170,
                                  margin: const EdgeInsets.only(right: 10),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF222736),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: const Color(0xFFF43F5E),
                                        backgroundImage: bPhoto != null && bPhoto.isNotEmpty ? NetworkImage(bPhoto) : null,
                                        child: bPhoto == null || bPhoto.isEmpty
                                            ? Text(bName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                            : null,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(bName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                                      Text(
                                        isToday ? "🎉 Turns $bAge today!" : "🎂 Turns $bAge in $daysUntil ${daysUntil == 1 ? 'day' : 'days'}",
                                        style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 11, fontWeight: FontWeight.w600),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Staff Search Bar & Company Filter Dropdown (Matching SS 3 & 4)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181C28),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => _applyFilters(),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          icon: Icon(Icons.search, color: Colors.white54),
                          hintText: 'Search staff...',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  if (_companiesList.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181C28),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: const Color(0xFF181C28),
                          value: _selectedCompanyFilter,
                          hint: const Text('Company', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          icon: const Icon(Icons.business, color: Color(0xFF38BDF8), size: 18),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Companies', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                            ..._companiesList.map((comp) => DropdownMenuItem<String>(
                                  value: comp,
                                  child: Text(comp, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                )),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedCompanyFilter = val;
                            });
                            _applyFilters();
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Staff List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Employees', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(
                        _activeBadgeFilter != null
                            ? 'Showing ${_filteredEmployees.length} ${_activeBadgeFilter!.replaceAll('_', ' ')} staff'
                            : 'Current Company Staff (${_filteredEmployees.length})',
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                  if (_activeBadgeFilter != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _activeBadgeFilter = null;
                        });
                        _applyFilters();
                      },
                      child: const Text('Clear filter', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Employee List Cards (Matching Screenshot 4)
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredEmployees.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: const Text('No matching employees found.', style: TextStyle(color: Colors.white54)),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredEmployees.length,
                          itemBuilder: (ctx, idx) {
                            final emp = _filteredEmployees[idx];
                            final String name = emp['name'] ?? 'Staff';
                            final String dept = emp['designation'] ?? emp['department'] ?? 'Employee';
                            final String? photoUrl = emp['photo'];
                            final String? inTime = emp['in_time'];
                            final String? outTime = emp['out_time'];

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              color: const Color(0xFF181C28),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => EmployeeDetailScreen(employee: emp)),
                                  );
                                },
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFF334155),
                                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                  child: photoUrl == null || photoUrl.isEmpty
                                      ? Text(name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
                                      : null,
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                                subtitle: Text(dept, style: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8))),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (inTime != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('IN ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                                          Text(inTime, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                                        ],
                                      ),
                                    if (outTime != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('OUT ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                                          Text(outTime, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                                        ],
                                      ),
                                    if (inTime == null && outTime == null)
                                      const Text('Not Marked', style: TextStyle(fontSize: 11, color: Colors.white38)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(int val, String sub, String label, Color barColor, String filterKey, double width) {
    final isSelected = _activeBadgeFilter == filterKey;

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeBadgeFilter = isSelected ? null : filterKey;
        });
        _applyFilters();
      },
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? barColor.withOpacity(0.2) : const Color(0xFF222736),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? barColor : Colors.transparent, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 3, height: 14, color: barColor, margin: const EdgeInsets.only(right: 6)),
                Text(
                  '$val',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
                if (sub.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      sub,
                      style: const TextStyle(fontSize: 10, color: Colors.white54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? barColor : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB: STAFF ATTENDANCE DASHBOARD VIEW (MATCHING STAFF DASHBOARD 1 & 2)
  // ==========================================
  Widget _buildStaffAttendanceDashboardTab() {
    final historyDays = _staffHistoryData?['days'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF11141E), // Dark background matching staff dashboard 1 & 2
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFF97316), // Orange floating hand button matching SS 1 & 2
        child: const Icon(Icons.front_hand, color: Colors.white),
        onPressed: () async {
          final nextAction = _todayInfo?['next_action'] ?? 'in';
          final updated = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AttendanceScanScreen(user: widget.user, initialType: nextAction)),
          );
          if (updated == true) _loadDashboardData();
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadDashboardData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with User Avatar (Matching SS 1 & 2)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Attendance Dashboard',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF38BDF8),
                    backgroundImage: widget.user.photoUrl != null && widget.user.photoUrl!.isNotEmpty
                        ? NetworkImage(widget.user.photoUrl!)
                        : null,
                    child: widget.user.photoUrl == null || widget.user.photoUrl!.isEmpty
                        ? Text(widget.user.name[0].toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Pill Button "You" (Matching SS 1 & 2)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(color: Color(0xFF1E40AF), fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),

              // Previous Reports Section (Matching SS 1 & 2)
              const Text('Previous Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const Text('View your last 2 sessions', style: TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(height: 14),

              SizedBox(
                height: 150,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildMonthReportCard('November', '2026', 11, 2026, const Color(0xFFF87171)),
                    const SizedBox(width: 12),
                    _buildMonthReportCard('October', '2026', 10, 2026, const Color(0xFF818CF8)),
                    const SizedBox(width: 12),
                    _buildMonthReportCard('September', '2026', 9, 2026, const Color(0xFF34D399)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Analytics & Online Attendance Section (Matching SS 1 & 2)
              const Text('Your current analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const Text('Based on your current monthly data', style: TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(height: 16),

              const Text('Online Attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : historyDays.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('No attendance history for current month.', style: TextStyle(color: Colors.white54)),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: historyDays.length,
                          itemBuilder: (ctx, idx) {
                            final day = historyDays[idx];
                            final String dateStr = day['date'] ?? '';
                            final String inTime = day['in'] ?? '';
                            final String outTime = day['out'] ?? '';
                            final String hours = day['hours'] ?? '';

                            DateTime? dt = DateTime.tryParse(dateStr);
                            String dayName = dt != null ? _getDayName(dt.weekday) : dateStr;
                            String formattedDate = dt != null ? '${_getMonthName(dt.month)} ${dt.day}, ${dt.year}' : dateStr;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF181C28),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(dayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                                      Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      if (inTime.isNotEmpty) ...[
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text('IN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                                            Text(inTime, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                          ],
                                        ),
                                        const SizedBox(width: 14),
                                      ],
                                      if (outTime.isNotEmpty) ...[
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text('OUT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                                            Text(outTime, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                            if (hours.isNotEmpty) Text('$hours hrs', style: const TextStyle(fontSize: 10, color: Colors.white38)),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthReportCard(String month, String year, int monthNum, int yearNum, Color accentColor) {
    return GestureDetector(
      onTap: () {
        AttendanceCalendarDialog.show(
          context,
          userId: widget.user.id,
          userName: widget.user.name,
          month: monthNum,
          year: yearNum,
        );
      },
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.85),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.auto_graph, color: Colors.white, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(month, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text('• $year', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB: SALARY TAB (FOR STAFF)
  // ==========================================
  Widget _buildSalaryTab() {
    return Container(
      color: const Color(0xFF0B0F19),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance_wallet, size: 64, color: Color(0xFF38BDF8)),
          const SizedBox(height: 16),
          const Text('Salary & Payslips', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('View monthly payslips, loan balance, and earnings details.', style: TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
            onPressed: () {},
            child: const Text('Download Latest Payslip', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB: SETTINGS TAB (WITH ADCodeNexus WEBSITE LINK & BRANDING)
  // ==========================================
  Widget _buildSettingsTab() {
    final user = widget.user;
    final companyName = user.companyName ?? 'TULSI FABRICS INDIA PVT LTD';

    return Container(
      color: const Color(0xFF090D16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Profile Photo with Edit Button
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: const Color(0xFF1E293B),
                  backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty ? NetworkImage(user.photoUrl!) : null,
                  child: user.photoUrl == null || user.photoUrl!.isEmpty
                      ? Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'G',
                          style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(
                          employee: {'id': user.id, 'name': user.name, 'phone': user.phone, 'email': user.email, 'photo': user.photoUrl},
                          onUpdated: _loadDashboardData,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Icon(Icons.edit, color: Colors.black, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              user.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 8),

            // Company Pill Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    companyName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: Colors.white70, size: 16),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Settings Menu Card
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF181C28),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  _buildSettingsMenuItem(
                    icon: Icons.person_outline,
                    label: 'Account',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(
                            employee: {'id': user.id, 'name': user.name, 'phone': user.phone, 'email': user.email, 'photo': user.photoUrl},
                            onUpdated: _loadDashboardData,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _buildSettingsMenuItem(
                    icon: Icons.lock_outline,
                    label: 'Security',
                    onTap: () {},
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _buildSettingsMenuItem(
                    icon: Icons.tune,
                    label: 'Configurations',
                    onTap: () {},
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _buildSettingsMenuItem(
                    icon: Icons.help_outline,
                    label: 'Get Help & Support',
                    onTap: _showSupportModal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Log Out Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF181C28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Colors.white10),
                  ),
                ),
                onPressed: _handleLogout,
                child: const Text(
                  'Log Out',
                  style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ADCodeNexus Branding & Website Link (Required by user request!)
            InkWell(
              onTap: () => _launchUrl('https://adcodenexus.com/'),
              child: Column(
                children: [
                  _buildBrandLogoWidget(size: 40),
                  const SizedBox(height: 6),
                  const Text(
                    'Powered by ADCodeNexus',
                    style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'https://adcodenexus.com/',
                    style: TextStyle(color: Colors.white38, fontSize: 11, decoration: TextDecoration.underline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsMenuItem({
    required IconData icon,
    required String label,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.white70, size: 20),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Text(trailingText, style: const TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(width: 4),
          ],
          const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
        ],
      ),
    );
  }

  // Brand Logo Widget (ADCodeNexus)
  Widget _buildBrandLogoWidget({double size = 80}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.code, size: size, color: const Color(0xFF38BDF8)),
        const SizedBox(height: 4),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'AD ',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8)),
              ),
              TextSpan(
                text: 'CodeNexus',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSupportModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181C28),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Contact & Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            const Text('Get help or suggest features to the admin team.', style: TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF064E3B), child: Icon(Icons.chat, color: Colors.greenAccent)),
              title: const Text('WhatsApp Support', style: TextStyle(color: Colors.white)),
              subtitle: Text(supportPhone, style: const TextStyle(color: Colors.white54)),
              onTap: () => _launchUrl('https://wa.me/91$supportPhone'),
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF0C4A6E), child: Icon(Icons.phone, color: Color(0xFF38BDF8))),
              title: const Text('Call Support', style: TextStyle(color: Colors.white)),
              subtitle: Text(supportPhone, style: const TextStyle(color: Colors.white54)),
              onTap: () => _launchUrl('tel:$supportPhone'),
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF581C87), child: Icon(Icons.email, color: Colors.purpleAccent)),
              title: const Text('Email Support', style: TextStyle(color: Colors.white)),
              subtitle: Text(supportEmail, style: const TextStyle(color: Colors.white54)),
              onTap: () => _launchUrl('mailto:$supportEmail'),
            ),
          ],
        ),
      ),
    );
  }

  String _getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1) % 12];
  }
}
