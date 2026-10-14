import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'create_task_screen.dart';
import 'task_detail_screen.dart';

class TasksScreen extends StatefulWidget {
  final UserModel user;
  const TasksScreen({super.key, required this.user});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<TaskModel> _allTasks = [];
  List<TaskModel> _filteredTasks = [];
  bool _isLoading = true;
  bool _isCalendarView = false;
  String _selectedStatus = 'all'; // all, pending, in_progress, completed, overdue
  DateTime _selectedCalendarDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getTasks();
      if (res['data'] != null) {
        final list = (res['data'] as List).map((x) => TaskModel.fromJson(x)).toList();
        setState(() {
          _allTasks = list;
          _isLoading = false;
        });
        _applyFilters();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading tasks: $e");
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    setState(() {
      _filteredTasks = _allTasks.where((t) {
        if (_selectedStatus == 'pending' && t.status != 'pending') return false;
        if (_selectedStatus == 'in_progress' && t.status != 'in_progress') return false;
        if (_selectedStatus == 'completed' && t.status != 'completed') return false;

        final d = t.dueDate != null ? DateTime.tryParse(t.dueDate!) : null;

        if (_selectedStatus == 'overdue') {
          if (t.status == 'completed' || d == null) return false;
          return d.isBefore(todayStart);
        }

        if (_isCalendarView) {
          if (d == null) return false;
          final isSameDate = d.year == _selectedCalendarDate.year &&
              d.month == _selectedCalendarDate.month &&
              d.day == _selectedCalendarDate.day;
          if (!isSameDate) return false;
        }

        return true;
      }).toList();
    });
  }

  String _getMonthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[month - 1];
  }

  Widget _buildCalendarHeader() {
    final year = _selectedCalendarDate.year;
    final month = _selectedCalendarDate.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday

    final taskDates = <int>{};
    for (var t in _allTasks) {
      if (t.dueDate != null) {
        final d = DateTime.tryParse(t.dueDate!);
        if (d != null && d.year == year && d.month == month) {
          taskDates.add(d.day);
        }
      }
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedCalendarDate = DateTime(year, month - 1, 1);
                  });
                  _applyFilters();
                },
              ),
              Text(
                "${_getMonthName(month)} $year",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedCalendarDate = DateTime(year, month + 1, 1);
                  });
                  _applyFilters();
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map((d) => SizedBox(
                      width: 36,
                      child: Text(d, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 12)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
            ),
            itemCount: (startingWeekday - 1) + daysInMonth,
            itemBuilder: (ctx, index) {
              if (index < startingWeekday - 1) {
                return const SizedBox();
              }
              final day = index - (startingWeekday - 2);
              final date = DateTime(year, month, day);
              final isSelected = day == _selectedCalendarDate.day && month == _selectedCalendarDate.month && year == _selectedCalendarDate.year;
              final hasTask = taskDates.contains(day);

              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    _selectedCalendarDate = date;
                  });
                  _applyFilters();
                },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF2563EB) : (hasTask ? const Color(0xFFEFF6FF) : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected ? null : (hasTask ? Border.all(color: const Color(0xFF93C5FD)) : null),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontWeight: isSelected || hasTask ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : (hasTask ? const Color(0xFF1E40AF) : const Color(0xFF334155)),
                          fontSize: 13,
                        ),
                      ),
                      if (hasTask)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : const Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Task Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isCalendarView ? Icons.list_alt : Icons.calendar_month, color: Colors.white),
            tooltip: _isCalendarView ? 'List View' : 'Calendar View',
            onPressed: () {
              setState(() {
                _isCalendarView = !_isCalendarView;
              });
              _applyFilters();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadTasks,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreateTaskScreen(user: widget.user)),
          );
          _loadTasks();
        },
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('all', 'All Tasks'),
                  _filterChip('pending', 'Pending'),
                  _filterChip('in_progress', 'In Progress'),
                  _filterChip('completed', 'Completed'),
                  _filterChip('overdue', 'Overdue'),
                ],
              ),
            ),
          ),

          if (_isCalendarView) _buildCalendarHeader(),

          // Main Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_turned_in, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _isCalendarView
                                  ? 'No tasks scheduled on ${_selectedCalendarDate.day} ${_getMonthName(_selectedCalendarDate.month)} ${_selectedCalendarDate.year}.'
                                  : 'No tasks found.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _filteredTasks.length,
                        itemBuilder: (ctx, i) {
                          final t = _filteredTasks[i];
                          final parsedDue = t.dueDate != null ? DateTime.tryParse(t.dueDate!) : null;
                          final isOverdue = t.status != 'completed' && parsedDue != null && parsedDue.isBefore(DateTime.now());

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isOverdue ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                                width: isOverdue ? 1.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => TaskDetailScreen(task: t, user: widget.user, initialTab: 'details')),
                                );
                                _loadTasks();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            t.title,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildPriorityBadge(t.priority),
                                      ],
                                    ),
                                    if (t.description != null && t.description!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        t.description!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(4)),
                                                  child: const Text('TO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  t.assigneeName ?? 'Unassigned',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                                                  child: const Text('FROM', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  t.createdByName ?? 'Admin',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        _buildStatusBadge(t.status, isOverdue),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSel = _selectedStatus == key;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedStatus = key);
        _applyFilters();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSel ? const Color(0xFF2563EB) : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(color: Colors.white, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bg;
    Color fg;
    if (priority == 'high') {
      bg = const Color(0xFFFEE2E2); fg = const Color(0xFF991B1B);
    } else if (priority == 'medium') {
      bg = const Color(0xFFFEF3C7); fg = const Color(0xFF92400E);
    } else {
      bg = const Color(0xFFF1F5F9); fg = const Color(0xFF475569);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(priority.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _buildStatusBadge(String status, bool isOverdue) {
    if (isOverdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(20)),
        child: const Text('OVERDUE', style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 11)),
      );
    }
    Color bg;
    Color fg;
    String label;
    if (status == 'completed') {
      bg = const Color(0xFFDCFCE7); fg = const Color(0xFF166534); label = 'Completed';
    } else if (status == 'in_progress') {
      bg = const Color(0xFFE0F2FE); fg = const Color(0xFF0369A1); label = 'In Progress';
    } else {
      bg = const Color(0xFFFFEDD5); fg = const Color(0xFF9A3412); label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}
