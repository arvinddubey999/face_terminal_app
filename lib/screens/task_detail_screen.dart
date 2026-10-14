import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  XFile? _replyAttachment;
  final ImagePicker _picker = ImagePicker();

  List<dynamic> _allEmployees = [];

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
    int initialIndex = widget.initialTab == 'replies' ? 1 : (widget.initialTab == 'history' ? 2 : 0);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    _loadLatestTask();
    _loadEmployees();
  }

  void _loadLatestTask() async {
    try {
      final res = await ApiService.getTaskDetails(_currentTask.id);
      if (res['data'] != null) {
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
      setState(() {
        _allEmployees = emps;
      });
    } catch (e) {
      debugPrint("Error loading employees: $e");
    }
  }

  void _postReply() async {
    final msg = _replyController.text.trim();
    if (msg.isEmpty && _replyAttachment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a remark or attach a file.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiService.postTaskReply(
        _currentTask.id,
        msg.isEmpty ? 'File attached' : msg,
        attachmentPath: _replyAttachment?.path,
      );

      _replyController.clear();
      setState(() {
        _replyAttachment = null;
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

  void _sendReminder() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.remindTask(_currentTask.id);
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Reminder sent!')),
      );
      _loadLatestTask();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _openReassignDialog() {
    int? selectedEmpId;
    final remarksCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
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
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
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
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(_currentTask.title, overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF1E293B),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status & Priority Card
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
                          softWrap: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _currentTask.status == 'completed'
                              ? Colors.green.withOpacity(0.2)
                              : (_currentTask.status == 'in_progress' ? Colors.blue.withOpacity(0.2) : Colors.amber.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _currentTask.status == 'completed'
                                ? Colors.green
                                : (_currentTask.status == 'in_progress' ? Colors.blue : Colors.amber),
                          ),
                        ),
                        child: Text(
                          _currentTask.status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _currentTask.status == 'completed'
                                ? Colors.greenAccent
                                : (_currentTask.status == 'in_progress' ? Colors.lightBlueAccent : Colors.amberAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_currentTask.description != null && _currentTask.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(_currentTask.description!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                  const Divider(color: Colors.white12, height: 24),

                  // Metadata Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetaItem(
                          Icons.calendar_month,
                          'Due Date',
                          _currentTask.dueDate ?? 'No Date',
                          isDanger: isOverdue,
                        ),
                      ),
                      Expanded(
                        child: _buildMetaItem(
                          Icons.access_time,
                          'Due Time',
                          _currentTask.dueTime ?? '12:00',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetaItem(
                          Icons.flag_outlined,
                          'Priority',
                          _currentTask.priority.toUpperCase(),
                        ),
                      ),
                      Expanded(
                        child: _buildMetaItem(
                          Icons.repeat,
                          'Repeat Interval',
                          _formatRepeatType(_currentTask.repeatType),
                        ),
                      ),
                    ],
                  ),
                  if (_currentTask.department != null) ...[
                    const SizedBox(height: 12),
                    _buildMetaItem(Icons.account_tree, 'Department', _currentTask.department!),
                  ],
                  if (_currentTask.client != null) ...[
                    const SizedBox(height: 12),
                    _buildMetaItem(Icons.person, 'Client', _currentTask.client!),
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
                  const Text('Assigned Team Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFF38BDF8), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Assigned To: ${_currentTask.assignedToName ?? "Unassigned"}',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, color: Color(0xFFFBBF24), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Assigned By (From): ${_currentTask.createdByName ?? "Admin"}',
                        style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  if (_currentTask.others.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _currentTask.others.map((o) {
                        final name = o['name'] ?? 'Staff';
                        return Chip(
                          backgroundColor: const Color(0xFF334155),
                          label: Text(name, style: const TextStyle(color: Colors.white, fontSize: 11)),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons: Re-Assign & Send Reminder
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                  label: const Text('Re-assign Task', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _openReassignDialog,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.notifications_active, color: Colors.white, size: 18),
                  label: const Text('Send Reminder', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _sendReminder,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String label, String value, {bool isDanger = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isDanger ? Colors.redAccent : const Color(0xFF38BDF8)),
        const SizedBox(width: 8),
        Column(
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
      ],
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
        return 'No Repeat (One-time)';
    }
  }

  Widget _buildRepliesTab() {
    return Column(
      children: [
        // Replies List
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
                            if (r.attachmentUrl != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF334155),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.attach_file, color: Color(0xFF38BDF8), size: 14),
                                    const SizedBox(width: 4),
                                    const Text('Attachment Included', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
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
              if (_replyAttachment != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.file_present, color: Colors.greenAccent, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_replyAttachment!.name, style: const TextStyle(color: Colors.white, fontSize: 11), overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                        onPressed: () => setState(() => _replyAttachment = null),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Color(0xFF38BDF8)),
                    tooltip: 'Attach Image / File',
                    onPressed: () async {
                      final file = await _picker.pickImage(source: ImageSource.gallery);
                      if (file != null) setState(() => _replyAttachment = file);
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
