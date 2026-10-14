import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'day_attendance_history_dialog.dart';

class AttendanceCalendarDialog extends StatefulWidget {
  final int userId;
  final String userName;
  final int initialMonth;
  final int initialYear;

  const AttendanceCalendarDialog({
    super.key,
    required this.userId,
    required this.userName,
    required this.initialMonth,
    required this.initialYear,
  });

  static Future<void> show(
    BuildContext context, {
    required int userId,
    required String userName,
    required int month,
    required int year,
  }) async {
    showDialog(
      context: context,
      builder: (_) => AttendanceCalendarDialog(
        userId: userId,
        userName: userName,
        initialMonth: month,
        initialYear: year,
      ),
    );
  }

  @override
  State<AttendanceCalendarDialog> createState() => _AttendanceCalendarDialogState();
}

class _AttendanceCalendarDialogState extends State<AttendanceCalendarDialog> {
  late int _selectedMonth;
  late int _selectedYear;
  bool _isLoading = true;
  bool _showMonthYearPicker = false;

  Map<String, dynamic>? _attendanceData;
  List<dynamic> _monthDays = [];

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  final List<int> _years = [2024, 2025, 2026, 2027, 2028, 2029, 2030];

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonth;
    _selectedYear = widget.initialYear;
    _loadCalendarData();
  }

  Future<void> _loadCalendarData() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getAttendanceHistory(
        userId: widget.userId,
        month: _selectedMonth,
        year: _selectedYear,
      );
      setState(() {
        _attendanceData = res;
        _monthDays = res['days'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Calendar data load error: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String monthNameShort = _months[_selectedMonth - 1].substring(0, 3);
    final String monthYearChipStr = '$monthNameShort $_selectedYear';

    final int presentCount = _attendanceData?['present'] ?? 0;
    final int absentCount = _attendanceData?['absent'] ?? 0;
    final int halfCount = _attendanceData?['half'] ?? 0;
    final int leaveCount = _attendanceData?['leave'] ?? 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row matching Screenshot 1
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Attendance For ${widget.userName}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showMonthYearPicker = !_showMonthYearPicker;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Colors.black87),
                            const SizedBox(width: 4),
                            Text(
                              monthYearChipStr,
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Stat Badges Row matching Screenshot 1
                    Row(
                      children: [
                        _buildStatBadge('Present', '$presentCount days', const Color(0xFF22C55E)),
                        const SizedBox(width: 6),
                        _buildStatBadge('Absent', '$absentCount times', const Color(0xFFEF4444)),
                        const SizedBox(width: 6),
                        _buildStatBadge('Half Day', '$halfCount times', const Color(0xFF3B82F6)),
                        const SizedBox(width: 6),
                        _buildStatBadge('Casual Leave', '$leaveCount left', const Color(0xFFF97316)),
                      ],
                    ),
                    const SizedBox(height: 16),

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

                    // Calendar Grid
                    _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(30),
                            child: CircularProgressIndicator(),
                          )
                        : _buildCalendarGrid(),
                  ],
                ),
              ),

              // Month & Year Picker Bottom Section matching Screenshot 1
              if (_showMonthYearPicker)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Select Month & Year', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => setState(() => _showMonthYearPicker = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Month', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white24),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<int>(
                                    value: _selectedMonth,
                                    dropdownColor: const Color(0xFF1E293B),
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    style: const TextStyle(color: Colors.white),
                                    items: List.generate(
                                      12,
                                      (idx) => DropdownMenuItem(
                                        value: idx + 1,
                                        child: Text(_months[idx]),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedMonth = val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Year', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white24),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<int>(
                                    value: _selectedYear,
                                    dropdownColor: const Color(0xFF1E293B),
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    style: const TextStyle(color: Colors.white),
                                    items: _years
                                        .map((y) => DropdownMenuItem(
                                              value: y,
                                              child: Text('$y'),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedYear = val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            setState(() => _showMonthYearPicker = false);
                            _loadCalendarData();
                          },
                          child: const Text('Apply Filter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String title, String count, Color barColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 3, height: 10, color: barColor, margin: const EdgeInsets.only(right: 4)),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              count,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_selectedYear, _selectedMonth, 1);
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
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

        final dateStr = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';

        final dayData = _monthDays.firstWhere(
          (d) => d['date'] == dateStr,
          orElse: () => {'date': dateStr, 'status': 'not_marked', 'has_in_no_out': false, 'ins_list': [], 'outs_list': []},
        );

        final String status = dayData['status'] ?? 'not_marked';
        final bool hasInNoOut = dayData['has_in_no_out'] == true;

        final List<dynamic> allPunches = [];
        if (dayData['ins_list'] != null) allPunches.addAll(dayData['ins_list']);
        if (dayData['outs_list'] != null) allPunches.addAll(dayData['outs_list']);

        BoxDecoration boxDeco;
        Color textCol = Colors.white;

        if (hasInNoOut) {
          // 50% Green (IN) & 50% Red (No OUT) split matching Screenshot 1 & 4!
          boxDeco = BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF166534), Color(0xFF991B1B)],
              stops: [0.5, 0.5],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white, width: 1.5),
          );
          textCol = Colors.white;
        } else if (['present', 'late', 'wop'].contains(status)) {
          boxDeco = BoxDecoration(
            color: const Color(0xFF166534),
            borderRadius: BorderRadius.circular(6),
          );
          textCol = Colors.white;
        } else if (status == 'absent') {
          boxDeco = BoxDecoration(
            color: const Color(0xFF991B1B),
            borderRadius: BorderRadius.circular(6),
          );
          textCol = Colors.white;
        } else if (['holiday', 'week_off', 'leave'].contains(status)) {
          boxDeco = BoxDecoration(
            color: const Color(0xFF0369A1),
            borderRadius: BorderRadius.circular(6),
          );
          textCol = Colors.white;
        } else {
          boxDeco = BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(6),
          );
          textCol = Colors.white54;
        }

        final monthName = _months[_selectedMonth - 1];
        final formattedDateStr = '$dayNum $monthName $_selectedYear';

        return GestureDetector(
          onTap: () {
            DayAttendanceHistoryDialog.show(
              context,
              employeeName: widget.userName,
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
}
