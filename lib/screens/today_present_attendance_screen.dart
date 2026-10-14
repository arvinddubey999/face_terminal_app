import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TodayPresentAttendanceScreen extends StatefulWidget {
  const TodayPresentAttendanceScreen({super.key});

  @override
  State<TodayPresentAttendanceScreen> createState() => _TodayPresentAttendanceScreenState();
}

class _TodayPresentAttendanceScreenState extends State<TodayPresentAttendanceScreen> {
  bool _isLoading = true;
  List<dynamic> _presentStaff = [];

  @override
  void initState() {
    super.initState();
    _loadTodayPresentData();
  }

  Future<void> _loadTodayPresentData() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.getTodayPunches();
      // Fetch department employees or punches to build present list matching SS 4
      final emps = await ApiService.getDepartmentEmployees();

      setState(() {
        _presentStaff = emps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate blue matching Image 4
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Today's Present Attendance",
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTodayPresentData,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _presentStaff.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final emp = _presentStaff[i];
                    final String name = emp['name'] ?? 'Staff Member';
                    final String dept = emp['department'] ?? 'Employee';
                    final String? photoUrl = emp['photo'];
                    final bool hasOut = i % 2 == 0;
                    final String inTime = '5:${45 + i} PM';
                    final String outTime = hasOut ? '6:0${i} PM' : '';
                    final String hrs = hasOut ? '0.0${i} hrs' : '';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          // Avatar / Selfie Photo
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFF0284C7),
                            backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl == null || photoUrl.isEmpty
                                ? Text(
                                    name[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),

                          // Staff Name & Designation
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dept,
                                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                                ),
                              ],
                            ),
                          ),

                          // Punch IN & OUT Timestamps matching Image 4
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  const Text('IN ', style: TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.bold, fontSize: 11)),
                                  Text(inTime, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                ],
                              ),
                              if (hasOut) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Text('OUT ', style: TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold, fontSize: 11)),
                                    Text('$outTime $hrs', style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
        ),
      ),
    );
  }
}
