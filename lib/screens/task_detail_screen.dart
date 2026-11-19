import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskModel task;
  final UserModel user;
  final String initialTab; // 'details', 'replies', 'history'

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.user,
    this.initialTab = 'details',
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TaskModel _currentTask;
  bool _isLoading = false;

  final TextEditingController _replyController = TextEditingController();
  final List<XFile> _replyAttachments = [];
  final ImagePicker _picker = ImagePicker();

  List<dynamic> _allEmployees = [];
  List<dynamic> _categories = [];

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
    int initialIndex = widget.initialTab == 'replies' ? 1 : (widget.initialTab == 'history' ? 2 : 0);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    _loadLatestTask();
    _loadEmployees();
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _loadLatestTask() async {
    try {
      final res = await ApiService.getTaskDetails(_currentTask.id);
      if (res['data'] != null && mounted) {
        setState(() {
          _currentTask = TaskModel.fromJson(res['data']);
        });
      }
    } catch (e) {
      debugPrint("Error fetching task details: $e");
    }
  }

  void _loadEmployees() async {
    try {
      final emps = await ApiService.getDepartmentEmployees();
      if (mounted) setState(() => _allEmployees = emps);
    } catch (e) {
      debugPrint("Error loading employees: $e");
    }
  }

  void _loadCategories() async {
    try {
      final cats = await ApiService.getTaskCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (e) {
      debugPrint("Error loading categories: $e");
    }
  }

  bool get _isSuperAdmin => widget.user.role == 'super_admin';
  bool get _isAdmin => widget.user.role == 'admin' || _isSuperAdmin;
  bool get _isCreator => _currentTask.createdBy == widget.user.id;
  bool get _isPrimaryAssignee => _currentTask.assignedToId == widget.user.id;
  bool get _canManage => _isAdmin || widget.user.canManageTasks;

  void _togglePin() async {
    final oldState = _currentTask.isPinned;
    setState(() {
      _currentTask = TaskModel(
        id: _currentTask.id,
        title: _currentTask.title,
        description: _currentTask.description,
        status: _currentTask.status,
        priority: _currentTask.priority,
        isPinned: !oldState,
        categoryId: _currentTask.categoryId,
        categoryName: _currentTask.categoryName,
        categoryColor: _currentTask.categoryColor,
        repeatType: _currentTask.repeatType,
        dueDate: _currentTask.dueDate,
        dueTime: _currentTask.dueTime,
        client: _currentTask.client,
        departmentId: _currentTask.departmentId,
        department: _currentTask.department,
        assignedToId: _currentTask.assignedToId,
        assignedToName: _currentTask.assignedToName,
        createdBy: _currentTask.createdBy,
        createdByName: _currentTask.createdByName,
        attachmentUrl: _currentTask.attachmentUrl,
        attachments: _currentTask.attachments,
        repliesCount: _currentTask.repliesCount,
        replies: _currentTask.replies,
        histories: _currentTask.histories,
        assignees: _currentTask.assignees,
        others: _currentTask.others,
        createdAt: _currentTask.createdAt,
      );
    });

    try {
      final res = await ApiService.togglePinTask(_currentTask.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? (oldState ? 'Unpinned' : 'Pinned to top'))),
        );
      }
      _loadLatestTask();
    } catch (_) {}
  }

  void _quickStatusChange(String newStatus) async {
    if (newStatus == _currentTask.status) return;
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.updateTaskStatus(_currentTask.id, newStatus);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Status updated successfully')),
        );
      }
      _loadLatestTask();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _confirmDeleteTask() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Task?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently delete "${_currentTask.title}"? This cannot be undone.',
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                final res = await ApiService.deleteTask(_currentTask.id);
                setState(() => _isLoading = false);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res['message'] ?? 'Task deleted successfully.')),
                );
                Navigator.pop(context, true);
              } catch (e) {
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openEditDescriptionDialog() {
    final titleCtrl = TextEditingController(text: _currentTask.title);
    final descCtrl = TextEditingController(text: _currentTask.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Edit Task Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Task Title',
                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Task Description',
                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                final res = await ApiService.updateTaskDescription(
                  _currentTask.id,
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                );
                setState(() => _isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res['message'] ?? 'Task details updated.')),
                  );
                }
                _loadLatestTask();
              } catch (e) {
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Save Changes', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openUpdateDeadlineDialog() {
    DateTime? pickedDate = _currentTask.dueDate != null ? DateTime.tryParse(_currentTask.dueDate!) : null;
    TimeOfDay pickedTime = const TimeOfDay(hour: 18, minute: 0);
    if (_currentTask.dueTime != null && _currentTask.dueTime!.contains(':')) {
      final parts = _currentTask.dueTime!.split(':');
      pickedTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 18, minute: int.tryParse(parts[1].split(' ')[0]) ?? 0);
    }
    String selStatus = _currentTask.status;
    final remarksCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Update Deadline & Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Due Date', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: pickedDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime(2035),
                    );
                    if (d != null) setDialogState(() => pickedDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF38BDF8), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          pickedDate != null ? "${pickedDate!.day}-${pickedDate!.month}-${pickedDate!.year}" : 'Select Date',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                const Text('Due Time', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: pickedTime);
                    if (t != null) setDialogState(() => pickedTime = t);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: Color(0xFF38BDF8), size: 16),
                        const SizedBox(width: 8),
                        Text(pickedTime.format(context), style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                const Text('Task Status', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  dropdownColor: const Color(0xFF1E293B),
                  value: selStatus,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending / Not Started', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'in_progress', child: Text('In Progress', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'completed', child: Text('Completed / Closed', style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (val) => setDialogState(() => selStatus = val ?? 'pending'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: remarksCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Remarks / Reason (Optional)',
                    labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                String? dStr = pickedDate != null ? "${pickedDate!.year}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}" : null;
                String tStr = "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";

                try {
                  final res = await ApiService.updateTaskDeadline(
                    _currentTask.id,
                    dueDate: dStr,
                    dueTime: tStr,
                    status: selStatus,
                    remarks: remarksCtrl.text.trim().isNotEmpty ? remarksCtrl.text.trim() : null,
                  );
                  setState(() => _isLoading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res['message'] ?? 'Deadline updated successfully!')),
                    );
                  }
                  _loadLatestTask();
                } catch (e) {
                  setState(() => _isLoading = false);
                }
              },
              child: const Text('Save & Notify', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openReassignDialog() {
    int? selectedEmpId;
    final remarksCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Re-Assign Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int?>(
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Select New Assignee *',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                  ),
                  items: _allEmployees.map((e) {
                    return DropdownMenuItem<int?>(
                      value: e['id'],
                      child: Text('${e['name']} (${e['department'] ?? '-'})', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedEmpId = val),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: remarksCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Reason / Remarks (Optional)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
              onPressed: selectedEmpId == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);
                      final res = await ApiService.reassignTask(_currentTask.id, selectedEmpId!, remarks: remarksCtrl.text.trim());
                      setState(() => _isLoading = false);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res['message'] ?? 'Task re-assigned!')),
                      );
                      _loadLatestTask();
                    },
              child: const Text('Re-Assign & Notify', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _reopenTask() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.reopenTask(_currentTask.id);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Task re-opened!')),
        );
      }
      _loadLatestTask();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _sendReminder() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.remindTask(_currentTask.id);
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Reminder sent to assigned members!')),
      );
      _loadLatestTask();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _uploadAdditionalAttachments() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.uploadTaskAttachment(_currentTask.id, picked.map((f) => f.path).toList());
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Attachments uploaded!')),
        );
      }
      _loadLatestTask();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _deleteAttachment(TaskAttachmentModel att) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Remove Attachment?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Delete "${att.fileName}" from this task?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final res = await ApiService.deleteTaskAttachment(att.id);
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Attachment removed.')),
          );
        }
        _loadLatestTask();
      } catch (e) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _deleteReplyAttachment(int replyId, String filePath) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Reply Attachment?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to remove this attached file?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final res = await ApiService.deleteReplyAttachment(replyId, filePath);
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Attachment deleted.')),
          );
        }
        _loadLatestTask();
      } catch (e) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _postReply() async {
    final msg = _replyController.text.trim();
    if (msg.isEmpty && _replyAttachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a remark or attach file(s).')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiService.postTaskReply(
        _currentTask.id,
        msg.isEmpty ? 'File attached' : msg,
        attachmentPaths: _replyAttachments.map((f) => f.path).toList(),
      );

      _replyController.clear();
      setState(() {
        _replyAttachments.clear();
        _isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Reply posted successfully!')),
      );

      _loadLatestTask();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _openUrl(String rawUrl) async {
    try {
      String url = rawUrl.trim();
      if (url.isEmpty) return;

      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        if (url.startsWith('/')) {
          url = 'https://hrms.tulsifabindia.com$url';
        } else if (url.startsWith('storage/')) {
          url = 'https://hrms.tulsifabindia.com/$url';
        } else {
          url = 'https://hrms.tulsifabindia.com/storage/$url';
        }
      }

      final uri = Uri.parse(url);
      bool launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}

      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (_) {}
      }

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $url')),
        );
      }
    } catch (e) {
      debugPrint("Error opening URL: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  void _exportRepliesPdf() async {
    final token = await ApiService.getToken();
    final url = '${ApiService.baseUrl}/tasks/${_currentTask.id}/replies-pdf?token=${token ?? ''}';
    _openUrl(url);
  }

  Color _parseHexColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF6366F1);
  }

  String _formatDueDateTime(String? dateStr, String? timeStr) {
    if (dateStr == null || dateStr.isEmpty) return 'No Deadline';
    String formattedDate = dateStr;
    try {
      final dt = DateTime.parse(dateStr);
      const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      formattedDate = "${dt.day.toString().padLeft(2, '0')} ${names[dt.month - 1]} ${dt.year}";
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

  @override
  Widget build(BuildContext context) {
    final canDeleteTask = _isSuperAdmin || _isAdmin || _isCreator;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          _currentTask.title,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _currentTask.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: _currentTask.isPinned ? const Color(0xFFF59E0B) : Colors.white70,
            ),
            tooltip: _currentTask.isPinned ? 'Unpin' : 'Pin to top',
            onPressed: _togglePin,
          ),
          if (canDeleteTask)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
              tooltip: 'Delete Task',
              onPressed: _confirmDeleteTask,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          labelColor: const Color(0xFF38BDF8),
          unselectedLabelColor: Colors.white60,
          tabs: [
            const Tab(icon: Icon(Icons.info_outline), text: 'Details'),
            Tab(
              icon: const Icon(Icons.chat_bubble_outline),
              text: 'Replies (${_currentTask.repliesCount})',
            ),
            Tab(
              icon: const Icon(Icons.history),
              text: 'History (${_currentTask.histories.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsTab(),
                _buildRepliesTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildDetailsTab() {
    final isOverdue = _currentTask.status != 'completed' &&
        _currentTask.dueDate != null &&
        DateTime.tryParse(_currentTask.dueDate!) != null &&
        DateTime.tryParse(_currentTask.dueDate!)!.isBefore(DateTime.now());

    final canEditDeadline = _canManage || _isCreator || _isPrimaryAssignee;
    final canEditDesc = _canManage || _isCreator;
    final canReassign = _canManage || _isCreator;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card: Title, Status Dropdown, Category Badge, Priority Badge
          Card(
            color: const Color(0xFF181C28),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _currentTask.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Quick Status Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: _currentTask.status == 'completed'
                              ? const Color(0xFF14532D)
                              : (_currentTask.status == 'in_progress' ? const Color(0xFF0369A1) : const Color(0xFF7C2D12)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _currentTask.status,
                          dropdownColor: const Color(0xFF1E293B),
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          items: const [
                            DropdownMenuItem(value: 'pending', child: Text('PENDING')),
                            DropdownMenuItem(value: 'in_progress', child: Text('IN PROGRESS')),
                            DropdownMenuItem(value: 'completed', child: Text('COMPLETED')),
                          ],
                          onChanged: canEditDeadline ? (val) {
                            if (val != null) _quickStatusChange(val);
                          } : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Category & Priority row
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_currentTask.categoryName != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: _parseHexColor(_currentTask.categoryColor ?? '#6366f1').withOpacity(0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _parseHexColor(_currentTask.categoryColor ?? '#6366f1')),
                          ),
                          child: Text(
                            _currentTask.categoryName!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _parseHexColor(_currentTask.categoryColor ?? '#6366f1'),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(6)),
                          child: const Text('General', style: TextStyle(fontSize: 11, color: Colors.white70)),
                        ),
                      ],

                      _buildPriorityBadge(_currentTask.priority),

                      if (_currentTask.repeatType != 'none')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFF4C1D95), borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            _formatRepeatType(_currentTask.repeatType),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDDD6FE)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Description row with Edit button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Description', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                      if (canEditDesc)
                        GestureDetector(
                          onTap: _openEditDescriptionDialog,
                          child: Row(
                            children: const [
                              Icon(Icons.edit_note, size: 16, color: Color(0xFF38BDF8)),
                              SizedBox(width: 4),
                              Text('Edit Description', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentTask.description != null && _currentTask.description!.isNotEmpty
                        ? _currentTask.description!
                        : 'No description provided.',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),

                  const Divider(color: Colors.white12, height: 24),

                  // Metadata Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetaItem(
                          Icons.calendar_month,
                          'Due Date & Time',
                          _formatDueDateTime(_currentTask.dueDate, _currentTask.dueTime),
                          isDanger: isOverdue,
                        ),
                      ),
                      if (_currentTask.createdAt != null)
                        Expanded(
                          child: _buildMetaItem(
                            Icons.schedule,
                            'Created On',
                            _currentTask.createdAt!,
                          ),
                        ),
                    ],
                  ),
                  if (_currentTask.department != null || _currentTask.client != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_currentTask.department != null)
                          Expanded(child: _buildMetaItem(Icons.business, 'Department', _currentTask.department!)),
                        if (_currentTask.client != null)
                          Expanded(child: _buildMetaItem(Icons.person, 'Client', _currentTask.client!)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Assigned Employees Card
          Card(
            color: const Color(0xFF181C28),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Team & Assignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFF38BDF8), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Assigned To (Primary): ${_currentTask.assignedToName ?? "Unassigned"}',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_pin, color: Color(0xFFFBBF24), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Assigned By (Creator): ${_currentTask.createdByName ?? "Admin"}',
                        style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  if (_currentTask.assignees.isNotEmpty || _currentTask.others.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Additional Team Members:', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ..._currentTask.assignees.map((a) {
                          final name = a is Map ? (a['name'] ?? 'Staff') : a.toString();
                          return Chip(
                            backgroundColor: const Color(0xFF0369A1),
                            label: Text(name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          );
                        }),
                        ..._currentTask.others.map((o) {
                          final name = o is Map ? (o['name'] ?? 'Staff') : o.toString();
                          return Chip(
                            backgroundColor: const Color(0xFF334155),
                            label: Text(name, style: const TextStyle(color: Colors.white, fontSize: 11)),
                          );
                        }),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Attachments Section
          Card(
            color: const Color(0xFF181C28),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.attach_file, color: Color(0xFF38BDF8), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Task Attachments (${_currentTask.attachments.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16, color: Color(0xFF38BDF8)),
                        label: const Text('Add Files', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _uploadAdditionalAttachments,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_currentTask.attachments.isEmpty && (_currentTask.attachmentUrl == null || _currentTask.attachmentUrl!.isEmpty))
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No attachments uploaded for this task.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    )
                  else ...[
                    ..._currentTask.attachments.map((att) {
                      final bool canDeleteAtt = _isAdmin || _isCreator || att.userId == widget.user.id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.description, color: Color(0xFF38BDF8), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => _openUrl(att.fileUrl),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      att.fileName,
                                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (att.userName != null)
                                      Text('Uploaded by ${att.userName}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.open_in_new, color: Colors.white70, size: 16),
                              tooltip: 'Open / Download',
                              onPressed: () => _openUrl(att.fileUrl),
                            ),
                            if (canDeleteAtt)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16),
                                tooltip: 'Delete Attachment',
                                onPressed: () => _deleteAttachment(att),
                              ),
                          ],
                        ),
                      );
                    }),
                    if (_currentTask.attachmentUrl != null && _currentTask.attachmentUrl!.isNotEmpty && _currentTask.attachments.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.attachment, color: Color(0xFF38BDF8), size: 18),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Primary Attachment File', style: TextStyle(color: Colors.white, fontSize: 12))),
                            IconButton(
                              icon: const Icon(Icons.open_in_new, color: Colors.white70, size: 16),
                              onPressed: () => _openUrl(_currentTask.attachmentUrl!),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons: Update Deadline & Status, Re-Assign, Send Reminder, Re-Open
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (canEditDeadline)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.edit_calendar, color: Colors.white, size: 18),
                  label: const Text('Update Deadline & Status', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _openUpdateDeadlineDialog,
                ),

              if (canReassign)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                  label: const Text('Re-assign Task', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _openReassignDialog,
                ),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.notifications_active, color: Colors.white, size: 18),
                label: const Text('Send Reminder', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: _sendReminder,
              ),

              if (_currentTask.status == 'completed' && (_canManage || _isCreator))
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.restart_alt, color: Colors.white, size: 18),
                  label: const Text('Re-open Task', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _reopenTask,
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String label, String value, {bool isDanger = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: isDanger ? Colors.redAccent : const Color(0xFF38BDF8)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDanger ? Colors.redAccent : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(priority.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  String _formatRepeatType(String type) {
    switch (type) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'quarterly':
        return 'Quarterly';
      case 'half_yearly':
        return 'Half-Yearly';
      case 'yearly':
        return 'Yearly';
      default:
        return 'One-time';
    }
  }

  Widget _buildRepliesTab() {
    return Column(
      children: [
        // Export Replies PDF banner bar matching Web (Point 9)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF181C28),
            border: Border(bottom: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Replies & Reports (${_currentTask.replies.length})',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444), size: 16),
                label: const Text('Export Replies PDF', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFF87171)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _exportRepliesPdf,
              ),
            ],
          ),
        ),
        Expanded(
          child: _currentTask.replies.isEmpty
              ? const Center(
                  child: Text(
                    'No remarks or replies submitted yet.\nUse the input below to reply with optional attachment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _currentTask.replies.length,
                  itemBuilder: (ctx, i) {
                    final r = _currentTask.replies[i];
                    final canDeleteReplyAtt = _isAdmin || _isCreator || r.userId == widget.user.id;

                    return Card(
                      color: const Color(0xFF181C28),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: const Color(0xFF38BDF8),
                                      backgroundImage: r.userPhoto != null ? NetworkImage(r.userPhoto!) : null,
                                      child: r.userPhoto == null
                                          ? Text(
                                              r.userName.isNotEmpty ? r.userName[0].toUpperCase() : 'U',
                                              style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      r.userName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                                if (r.createdAt != null)
                                  Text(r.createdAt!, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(r.message, style: const TextStyle(color: Colors.white70, fontSize: 13)),

                            // Attached Files in Reply
                            if (r.attachments.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: r.attachments.map((url) {
                                  final name = url.split('/').last;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF334155),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () => _openUrl(url),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.attach_file, color: Color(0xFF38BDF8), size: 14),
                                              const SizedBox(width: 4),
                                              ConstrainedBox(
                                                constraints: const BoxConstraints(maxWidth: 140),
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (canDeleteReplyAtt) ...[
                                          const SizedBox(width: 4),
                                          GestureDetector(
                                            onTap: () => _deleteReplyAttachment(r.id, url),
                                            child: const Icon(Icons.close, color: Color(0xFFEF4444), size: 14),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ] else if (r.attachmentUrl != null) ...[
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => _openUrl(r.attachmentUrl!),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.attach_file, color: Color(0xFF38BDF8), size: 14),
                                      SizedBox(width: 4),
                                      Text('View Attachment', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Post Reply Form
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF1E293B),
          child: Column(
            children: [
              if (_replyAttachments.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _replyAttachments.map((file) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.file_present, color: Colors.greenAccent, size: 14),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Text(file.name, style: const TextStyle(color: Colors.white, fontSize: 11), overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              child: const Icon(Icons.close, color: Colors.redAccent, size: 14),
                              onTap: () => setState(() => _replyAttachments.remove(file)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Color(0xFF38BDF8)),
                    tooltip: 'Attach Image / Files',
                    onPressed: () async {
                      final files = await _picker.pickMultiImage(imageQuality: 85);
                      if (files.isNotEmpty) {
                        setState(() => _replyAttachments.addAll(files));
                      }
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Type remark or progress update...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        fillColor: const Color(0xFF0F172A),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF38BDF8)),
                    onPressed: _postReply,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return _currentTask.histories.isEmpty
        ? const Center(
            child: Text('No audit history recorded yet.', style: TextStyle(color: Colors.white54)),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: _currentTask.histories.length,
            itemBuilder: (ctx, i) {
              final h = _currentTask.histories[i];
              return Card(
                color: const Color(0xFF181C28),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const Icon(Icons.history_toggle_off, color: Color(0xFF38BDF8)),
                  title: Text(h.details ?? h.action, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  subtitle: Text('By ${h.userName}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  trailing: Text(h.createdAt ?? '', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ),
              );
            },
          );
  }
}
