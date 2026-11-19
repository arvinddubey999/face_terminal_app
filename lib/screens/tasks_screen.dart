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

  // Filter state
  String _selectedStatus = 'pending'; // Default to Pending matching web (Point 3)
  String _selectedPriority = 'all'; // all, high, medium, low
  String _selectedScope = 'all'; // all, mine, created
  int? _selectedCategoryId;
  int? _selectedDeptId;
  int? _selectedUserId; // User wise filter (Point 1)
  final TextEditingController _searchController = TextEditingController();

  Map<String, int> _counts = {
    'all': 0,
    'pending': 0,
    'in_progress': 0,
    'completed': 0,
    'overdue': 0,
  };

  List<dynamic> _categories = [];
  List<dynamic> _departments = [];
  List<dynamic> _employees = [];
  DateTime _selectedCalendarDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadFiltersData();
    _loadTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadFiltersData() async {
    try {
      final cats = await ApiService.getTaskCategories();
      final masters = await ApiService.getMasters();
      final emps = await ApiService.getDepartmentEmployees();
      if (mounted) {
        setState(() {
          _categories = cats;
          _departments = masters['departments'] ?? [];
          _employees = emps;
        });
      }
    } catch (e) {
      debugPrint("Error loading filter options: $e");
    }
  }

  void _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getTasks(
        status: _selectedStatus != 'all' ? _selectedStatus : null,
        search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
        categoryId: _selectedCategoryId,
        departmentId: _selectedDeptId,
        userId: _selectedUserId,
        priority: _selectedPriority != 'all' ? _selectedPriority : null,
        scope: _selectedScope != 'all' ? _selectedScope : null,
      );

      if (res['data'] != null) {
        final list = (res['data'] as List).map((x) => TaskModel.fromJson(x)).toList();
        Map<String, int> newCounts = {};
        if (res['counts'] is Map) {
          res['counts'].forEach((k, v) {
            newCounts[k.toString()] = int.tryParse(v.toString()) ?? 0;
          });
        }

        if (mounted) {
          setState(() {
            _allTasks = list;
            if (newCounts.isNotEmpty) {
              _counts = newCounts;
            } else {
              _computeLocalCounts(list);
            }
            _isLoading = false;
          });
          _applyFilters();
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading tasks: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _computeLocalCounts(List<TaskModel> list) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    int p = 0, ip = 0, c = 0, ov = 0;
    for (var t in list) {
      if (t.status == 'pending') p++;
      if (t.status == 'in_progress') ip++;
      if (t.status == 'completed') c++;
      final d = t.dueDate != null ? DateTime.tryParse(t.dueDate!) : null;
      if (t.status != 'completed' && d != null && d.isBefore(todayStart)) ov++;
    }
    _counts = {
      'all': list.length,
      'pending': p,
      'in_progress': ip,
      'completed': c,
      'overdue': ov,
    };
  }

  void _applyFilters() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final search = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredTasks = _allTasks.where((t) {
        // Status filter
        if (_selectedStatus == 'pending' && t.status != 'pending') return false;
        if (_selectedStatus == 'in_progress' && t.status != 'in_progress') return false;
        if (_selectedStatus == 'completed' && t.status != 'completed') return false;

        final d = t.dueDate != null ? DateTime.tryParse(t.dueDate!) : null;
        if (_selectedStatus == 'overdue') {
          if (t.status == 'completed' || d == null) return false;
          if (!d.isBefore(todayStart)) return false;
        }

        // Priority filter
        if (_selectedPriority != 'all' && t.priority.toLowerCase() != _selectedPriority) return false;

        // Category filter
        if (_selectedCategoryId != null && t.categoryId != _selectedCategoryId) return false;

        // Department filter
        if (_selectedDeptId != null && t.departmentId != _selectedDeptId) return false;

        // User / Assignee filter (Point 1)
        if (_selectedUserId != null) {
          final isUserAssigned = t.assignedToId == _selectedUserId ||
              t.assignees.any((a) => (a is Map ? a['id'] : a) == _selectedUserId) ||
              t.others.any((o) => (o is Map ? o['id'] : o) == _selectedUserId);
          if (!isUserAssigned) return false;
        }

        // Scope filter
        if (_selectedScope == 'mine') {
          final isAssigned = t.assignedToId == widget.user.id ||
              t.assignees.any((a) => (a is Map ? a['id'] : a) == widget.user.id) ||
              t.others.any((o) => (o is Map ? o['id'] : o) == widget.user.id);
          if (!isAssigned) return false;
        } else if (_selectedScope == 'created') {
          if (t.createdBy != widget.user.id) return false;
        }

        // Search text
        if (search.isNotEmpty) {
          final titleMatch = t.title.toLowerCase().contains(search);
          final descMatch = (t.description ?? '').toLowerCase().contains(search);
          final clientMatch = (t.client ?? '').toLowerCase().contains(search);
          if (!titleMatch && !descMatch && !clientMatch) return false;
        }

        // Calendar filter
        if (_isCalendarView) {
          if (d == null) return false;
          final isSameDate = d.year == _selectedCalendarDate.year &&
              d.month == _selectedCalendarDate.month &&
              d.day == _selectedCalendarDate.day;
          if (!isSameDate) return false;
        }

        return true;
      }).toList();

      // Sort: Pinned first, then nearest deadline upcoming (matching web - Point 4)
      _filteredTasks.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        if (a.dueDate == null && b.dueDate == null) return (b.id ?? 0).compareTo(a.id ?? 0);
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        final cmpDate = a.dueDate!.compareTo(b.dueDate!);
        if (cmpDate != 0) return cmpDate;
        final at = a.dueTime ?? '23:59:59';
        final bt = b.dueTime ?? '23:59:59';
        return at.compareTo(bt);
      });
    });
  }

  void _togglePin(TaskModel task) async {
    final oldState = task.isPinned;
    setState(() {
      final idx = _allTasks.indexWhere((x) => x.id == task.id);
      if (idx != -1) {
        _allTasks[idx] = TaskModel(
          id: task.id,
          title: task.title,
          description: task.description,
          status: task.status,
          priority: task.priority,
          isPinned: !oldState,
          categoryId: task.categoryId,
          categoryName: task.categoryName,
          categoryColor: task.categoryColor,
          repeatType: task.repeatType,
          dueDate: task.dueDate,
          dueTime: task.dueTime,
          client: task.client,
          departmentId: task.departmentId,
          department: task.department,
          assignedToId: task.assignedToId,
          assignedToName: task.assignedToName,
          createdBy: task.createdBy,
          createdByName: task.createdByName,
          attachmentUrl: task.attachmentUrl,
          attachments: task.attachments,
          repliesCount: task.repliesCount,
          replies: task.replies,
          histories: task.histories,
          assignees: task.assignees,
          others: task.others,
          createdAt: task.createdAt,
        );
        _applyFilters();
      }
    });

    try {
      final res = await ApiService.togglePinTask(task.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? (oldState ? 'Task unpinned' : 'Task pinned to top')),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {}
  }

  String _getMonthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[month - 1];
  }

  String _formatDueDateTime(String? dateStr, String? timeStr) {
    if (dateStr == null || dateStr.isEmpty) return 'No Deadline';
    String formattedDate = dateStr;
    try {
      final dt = DateTime.parse(dateStr);
      formattedDate = "${dt.day.toString().padLeft(2, '0')} ${_getMonthName(dt.month).substring(0, 3)} ${dt.year}";
    } catch (_) {}

    if (timeStr != null && timeStr.isNotEmpty) {
      String formattedTime = timeStr;
      try {
        if (timeStr.contains(':')) {
          final parts = timeStr.split(':');
          int hour = int.parse(parts[0]);
          final minute = parts[1].split(' ')[0].padLeft(2, '0');
          final ampm = hour >= 12 ? 'PM' : 'AM';
          hour = hour % 12;
          if (hour == 0) hour = 12;
          formattedTime = "${hour.toString().padLeft(2, '0')}:$minute $ampm";
        }
      } catch (_) {}
      return "$formattedDate, $formattedTime";
    }
    return formattedDate;
  }

  void _openFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter Tasks',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedPriority = 'all';
                              _selectedScope = 'all';
                              _selectedCategoryId = null;
                              _selectedDeptId = null;
                              _selectedUserId = null;
                            });
                            setState(() {
                              _selectedPriority = 'all';
                              _selectedScope = 'all';
                              _selectedCategoryId = null;
                              _selectedDeptId = null;
                              _selectedUserId = null;
                            });
                            _loadTasks();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Reset All', style: TextStyle(color: Color(0xFF38BDF8))),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 10),

                    // Scope Filter
                    const Text('Task Scope', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _dialogChoiceChip('All Tasks', _selectedScope == 'all', () {
                          setModalState(() => _selectedScope = 'all');
                        }),
                        _dialogChoiceChip('Assigned to Me', _selectedScope == 'mine', () {
                          setModalState(() => _selectedScope = 'mine');
                        }),
                        _dialogChoiceChip('Created by Me', _selectedScope == 'created', () {
                          setModalState(() => _selectedScope = 'created');
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Priority Filter
                    const Text('Priority Level', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _dialogChoiceChip('All Priorities', _selectedPriority == 'all', () {
                          setModalState(() => _selectedPriority = 'all');
                        }),
                        _dialogChoiceChip('High', _selectedPriority == 'high', () {
                          setModalState(() => _selectedPriority = 'high');
                        }),
                        _dialogChoiceChip('Medium', _selectedPriority == 'medium', () {
                          setModalState(() => _selectedPriority = 'medium');
                        }),
                        _dialogChoiceChip('Low', _selectedPriority == 'low', () {
                          setModalState(() => _selectedPriority = 'low');
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Category Dropdown
                    if (_categories.isNotEmpty) ...[
                      const Text('Category', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int?>(
                        dropdownColor: const Color(0xFF1E293B),
                        value: _selectedCategoryId,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('All Categories', style: TextStyle(color: Colors.white70))),
                          ..._categories.map((c) => DropdownMenuItem<int?>(
                                value: c['id'],
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: _parseHexColor(c['color'] ?? '#6366f1'),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(c['name'] ?? '', style: const TextStyle(color: Colors.white)),
                                  ],
                                ),
                              )),
                        ],
                        onChanged: (val) => setModalState(() => _selectedCategoryId = val),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Department Dropdown
                    if (_departments.isNotEmpty) ...[
                      const Text('Department', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int?>(
                        dropdownColor: const Color(0xFF1E293B),
                        value: _selectedDeptId,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('All Departments', style: TextStyle(color: Colors.white70))),
                          ..._departments.map((d) => DropdownMenuItem<int?>(
                                value: d['id'],
                                child: Text(d['name'] ?? '', style: const TextStyle(color: Colors.white)),
                              )),
                        ],
                        onChanged: (val) => setModalState(() => _selectedDeptId = val),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // User / Assignee Dropdown (Point 1: To User)
                    if (_employees.isNotEmpty) ...[
                      const Text('To User (Assignee)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int?>(
                        dropdownColor: const Color(0xFF1E293B),
                        value: _selectedUserId,
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('To User (All)', style: TextStyle(color: Colors.white70))),
                          ..._employees.map((e) => DropdownMenuItem<int?>(
                                value: e['id'],
                                child: Text('${e['name']} (${e['department'] ?? '-'})', overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                              )),
                        ],
                        onChanged: (val) => setModalState(() => _selectedUserId = val),
                      ),
                      const SizedBox(height: 16),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(ctx);
                          _loadTasks();
                        },
                        child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dialogChoiceChip(String label, bool isSelected, VoidCallback onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: const Color(0xFF0F172A),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => onSelected(),
    );
  }

  Color _parseHexColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF6366F1);
  }

  Widget _buildCalendarHeader() {
    final year = _selectedCalendarDate.year;
    final month = _selectedCalendarDate.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday;

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
    final bool hasActiveExtraFilters = _selectedPriority != 'all' ||
        _selectedScope != 'all' ||
        _selectedCategoryId != null ||
        _selectedDeptId != null ||
        _selectedUserId != null;

    final bool canCreate = widget.user.canCreateTasks ||
        widget.user.role == 'admin' ||
        widget.user.role == 'super_admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Task Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list, color: Colors.white),
                if (hasActiveExtraFilters)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Color(0xFF38BDF8), shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            tooltip: 'Filter Tasks',
            onPressed: _openFilterDialog,
          ),
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
            tooltip: 'Refresh',
            onPressed: _loadTasks,
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF2563EB),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CreateTaskScreen(user: widget.user)),
                );
                if (created == true) {
                  _loadTasks();
                }
              },
            )
          : null,
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Column(
              children: [
                // Search Input Field
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onChanged: (_) => _applyFilters(),
                    decoration: InputDecoration(
                      hintText: 'Search by title, description, client...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, color: Colors.white54, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Status Tabs with Badge Counts
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _statusChip('all', 'All', _counts['all'] ?? 0),
                      _statusChip('pending', 'Pending', _counts['pending'] ?? 0),
                      _statusChip('in_progress', 'In Progress', _counts['in_progress'] ?? 0),
                      _statusChip('completed', 'Completed', _counts['completed'] ?? 0),
                      _statusChip('overdue', 'Overdue', _counts['overdue'] ?? 0, isDanger: true),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_isCalendarView) _buildCalendarHeader(),

          // Active filter indicator pill bar
          if (hasActiveExtraFilters)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFFEFF6FF),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Filtered results active',
                      style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPriority = 'all';
                        _selectedScope = 'all';
                        _selectedCategoryId = null;
                        _selectedDeptId = null;
                        _selectedUserId = null;
                      });
                      _loadTasks();
                    },
                    child: const Text('Clear', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Main Tasks List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async => _loadTasks(),
                    child: _filteredTasks.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
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
                                  if (hasActiveExtraFilters) ...[
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedPriority = 'all';
                                          _selectedScope = 'all';
                                          _selectedCategoryId = null;
                                          _selectedDeptId = null;
                                          _selectedUserId = null;
                                          _searchController.clear();
                                        });
                                        _loadTasks();
                                      },
                                      child: const Text('Clear all filters'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(14),
                            itemCount: _filteredTasks.length,
                            itemBuilder: (ctx, i) {
                              final t = _filteredTasks[i];
                              return _buildTaskCard(t);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String key, String label, int count, {bool isDanger = false}) {
    final isSel = _selectedStatus == key;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedStatus = key);
        _applyFilters();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSel ? const Color(0xFF2563EB) : (isDanger && count > 0 ? const Color(0xFFEF4444) : Colors.white24),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isDanger && !isSel && count > 0 ? const Color(0xFFFCA5A5) : Colors.white,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSel
                    ? Colors.white
                    : (isDanger && count > 0 ? const Color(0xFFEF4444) : Colors.white24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSel ? const Color(0xFF2563EB) : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(TaskModel t) {
    final parsedDue = t.dueDate != null ? DateTime.tryParse(t.dueDate!) : null;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final isOverdue = t.status != 'completed' && parsedDue != null && parsedDue.isBefore(todayStart);

    // Additional assignees count
    final totalAssignees = (t.assignees.isNotEmpty ? t.assignees.length : (t.assignedToId != null ? 1 : 0)) + t.others.length;
    final additionalCount = totalAssignees > 1 ? totalAssignees - 1 : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: t.isPinned
              ? const Color(0xFFF59E0B)
              : (isOverdue ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
          width: t.isPinned ? 1.5 : (isOverdue ? 1.5 : 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TaskDetailScreen(task: t, user: widget.user)),
          );
          _loadTasks();
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Pinned indicator, Category badge, Priority badge, Pin button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (t.isPinned) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.push_pin, color: Color(0xFFD97706), size: 12),
                          SizedBox(width: 3),
                          Text('PINNED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  if (t.categoryName != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: _parseHexColor(t.categoryColor ?? '#6366f1').withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _parseHexColor(t.categoryColor ?? '#6366f1').withOpacity(0.3)),
                      ),
                      child: Text(
                        t.categoryName!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _parseHexColor(t.categoryColor ?? '#6366f1'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  _buildPriorityBadge(t.priority),
                  const Spacer(),

                  IconButton(
                    icon: Icon(
                      t.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: t.isPinned ? const Color(0xFFD97706) : Colors.grey.shade400,
                      size: 20,
                    ),
                    tooltip: t.isPinned ? 'Unpin' : 'Pin to top',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _togglePin(t),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                t.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),

              if (t.description != null && t.description!.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  t.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
              ],
              const SizedBox(height: 10),

              // Client and Department Badges
              if (t.client != null || t.department != null) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (t.client != null && t.client!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person, size: 12, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(t.client!, style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    if (t.department != null && t.department!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.business, size: 12, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(t.department!, style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // Deadline & Repeat
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 13, color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF64748B)),
                  const SizedBox(width: 5),
                  Text(
                    _formatDueDateTime(t.dueDate, t.dueTime),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF334155),
                    ),
                  ),
                  if (t.repeatType != 'none') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        t.repeatType.toUpperCase(),
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Bottom Row: Assignee Info, Replies count, Status
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
                          if (additionalCount > 0)
                            Text(' +$additionalCount', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
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

                  Row(
                    children: [
                      if (t.repliesCount > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text('${t.repliesCount}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _buildStatusBadge(t.status, isOverdue),
                    ],
                  ),
                ],
              ),
            ],
          ),
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
      bg = const Color(0xFFE0F2FE); fg = const Color(0xFF0369A1);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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
