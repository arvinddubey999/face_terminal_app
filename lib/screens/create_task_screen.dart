import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class CreateTaskScreen extends StatefulWidget {
  final UserModel user;
  const CreateTaskScreen({super.key, required this.user});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _clientController = TextEditingController();

  int? _selectedCategoryId;
  String _priority = 'medium';
  String _repeatType = 'none';
  int? _selectedDeptId;
  int? _selectedAssignedId;

  List<int> _selectedOtherIds = [];
  bool _selectAllOthers = false;

  DateTime? _selectedDueDate;
  TimeOfDay? _selectedDueTime;
  final List<XFile> _attachedFiles = [];
  final ImagePicker _picker = ImagePicker();

  List<dynamic> _categories = [];
  List<dynamic> _departments = [];
  List<dynamic> _employees = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMastersAndEmployees();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _clientController.dispose();
    super.dispose();
  }

  void _loadMastersAndEmployees() async {
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
      debugPrint("Error loading task creation data: $e");
    }
  }

  void _onDeptChanged(int? deptId) async {
    setState(() {
      _selectedDeptId = deptId;
      _selectedAssignedId = null;
      _selectedOtherIds = [];
      _selectAllOthers = false;
    });
    final emps = await ApiService.getDepartmentEmployees(deptId);
    if (mounted) {
      setState(() => _employees = emps);
    }
  }

  void _toggleSelectAllOthers(bool? val) {
    setState(() {
      _selectAllOthers = val ?? false;
      if (_selectAllOthers) {
        _selectedOtherIds = _employees.map<int>((e) => e['id'] as int).toList();
      } else {
        _selectedOtherIds = [];
      }
    });
  }

  void _openAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.label_outline, color: Color(0xFF38BDF8), size: 20),
                  SizedBox(width: 8),
                  Text('Add New Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Category Name *',
                        labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
                        hintText: 'e.g. Electricity Bill, Compliance...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: descCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
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
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter category name')));
                      return;
                    }
                    Navigator.pop(ctx);
                    try {
                      final res = await ApiService.createTaskCategory(
                        name: name,
                        description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                      );
                      if (res['ok'] == true && res['data'] != null) {
                        final newCat = res['data'];
                        setState(() {
                          _categories.add(newCat);
                          _selectedCategoryId = newCat['id'];
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Category created!')));
                        }
                      }
                    } catch (e) {
                      debugPrint("Error creating category: $e");
                    }
                  },
                  child: const Text('Save Category', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _submitTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter task title')),
      );
      return;
    }

    setState(() => _isLoading = true);

    String? dueDateStr = _selectedDueDate != null
        ? "${_selectedDueDate!.year}-${_selectedDueDate!.month.toString().padLeft(2, '0')}-${_selectedDueDate!.day.toString().padLeft(2, '0')}"
        : null;

    String? dueTimeStr = _selectedDueTime != null
        ? "${_selectedDueTime!.hour.toString().padLeft(2, '0')}:${_selectedDueTime!.minute.toString().padLeft(2, '0')}"
        : null;

    try {
      final res = await ApiService.createTask(
        title: title,
        description: _descController.text.trim(),
        client: _clientController.text.trim(),
        priority: _priority,
        repeatType: _repeatType,
        dueDate: dueDateStr,
        dueTime: dueTimeStr,
        categoryId: _selectedCategoryId,
        departmentId: _selectedDeptId,
        assignedToId: _selectedAssignedId,
        others: _selectedOtherIds,
        attachmentFilePaths: _attachedFiles.map((f) => f.path).toList(),
      );

      setState(() => _isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Task created! Push notifications sent.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create task: $e')),
        );
      }
    }
  }

  Color _parseHexColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Create & Assign Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(_titleController, 'Task Title *', icon: Icons.task_alt),
            const SizedBox(height: 14),

            // Task Category Dropdown + Add Category Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Task Category', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: _openAddCategoryDialog,
                  child: Row(
                    children: const [
                      Icon(Icons.add_circle_outline, color: Color(0xFF38BDF8), size: 15),
                      SizedBox(width: 4),
                      Text('Add New Category', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int?>(
              dropdownColor: const Color(0xFF1E293B),
              value: _selectedCategoryId,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Select Category (Optional)', icon: Icons.label_outline),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('No Category (General)', style: TextStyle(color: Colors.white70))),
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
              onChanged: (val) => setState(() => _selectedCategoryId = val),
            ),
            const SizedBox(height: 14),

            _buildTextField(_clientController, 'Client Name (Optional)', icon: Icons.person_pin),
            const SizedBox(height: 14),

            // Department Selection (Filters next employee dropdown)
            DropdownButtonFormField<int?>(
              dropdownColor: const Color(0xFF1E293B),
              value: _selectedDeptId,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Department (Filters Staff Below)', icon: Icons.account_tree),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All Departments', style: TextStyle(color: Colors.white))),
                ..._departments.map((d) => DropdownMenuItem<int?>(
                      value: d['id'],
                      child: Text(d['name'], style: const TextStyle(color: Colors.white)),
                    )),
              ],
              onChanged: _onDeptChanged,
            ),
            const SizedBox(height: 14),

            // Primary Employee Selection
            DropdownButtonFormField<int?>(
              dropdownColor: const Color(0xFF1E293B),
              value: _selectedAssignedId,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Primary Assigned Employee *', icon: Icons.person_outline),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Unassigned', style: TextStyle(color: Colors.white54))),
                ..._employees.map((e) => DropdownMenuItem<int?>(
                      value: e['id'],
                      child: Text('${e['name']} (${e['department'] ?? '-'})', style: const TextStyle(color: Colors.white)),
                    )),
              ],
              onChanged: (val) => setState(() => _selectedAssignedId = val),
            ),
            const SizedBox(height: 14),

            // Assign To Others (Multiple Selection with Select All)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF181C28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Assign To Others (Multiple)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _selectAllOthers,
                            activeColor: const Color(0xFF38BDF8),
                            onChanged: _toggleSelectAllOthers,
                          ),
                          const Text('Select All', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  if (_employees.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No employees found for this department.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _employees.map((e) {
                        final isSelected = _selectedOtherIds.contains(e['id']);
                        return FilterChip(
                          label: Text(e['name'], style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 11)),
                          selected: isSelected,
                          selectedColor: const Color(0xFF2563EB),
                          backgroundColor: const Color(0xFF1E293B),
                          checkmarkColor: Colors.white,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedOtherIds.add(e['id']);
                              } else {
                                _selectedOtherIds.remove(e['id']);
                              }
                              _selectAllOthers = _selectedOtherIds.length == _employees.length;
                            });
                          },
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Priority & Repeat Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E293B),
                    value: _priority,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Priority Level', icon: Icons.flag),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low Priority', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'medium', child: Text('Medium Priority', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'high', child: Text('High Priority', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (val) => setState(() => _priority = val ?? 'medium'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E293B),
                    value: _repeatType,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Repeat Task', icon: Icons.repeat),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('No Repeat', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'daily', child: Text('Daily', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'quarterly', child: Text('Quarterly', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'half_yearly', child: Text('Half-Yearly', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'yearly', child: Text('Yearly', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (val) => setState(() => _repeatType = val ?? 'none'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Due Date & Due Time Pickers
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDueDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => _selectedDueDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Color(0xFF38BDF8), size: 18),
                          const SizedBox(width: 10),
                          Text(
                            _selectedDueDate != null
                                ? "${_selectedDueDate!.day.toString().padLeft(2, '0')}-${_selectedDueDate!.month.toString().padLeft(2, '0')}-${_selectedDueDate!.year}"
                                : 'Select Due Date',
                            style: TextStyle(color: _selectedDueDate != null ? Colors.white : Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedDueTime ?? const TimeOfDay(hour: 18, minute: 0),
                      );
                      if (picked != null) setState(() => _selectedDueTime = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, color: Color(0xFF38BDF8), size: 18),
                          const SizedBox(width: 10),
                          Text(
                            _selectedDueTime != null
                                ? _selectedDueTime!.format(context)
                                : 'Select Due Time',
                            style: TextStyle(color: _selectedDueTime != null ? Colors.white : Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildTextField(_descController, 'Task Description (Optional)', icon: Icons.notes, maxLines: 3),
            const SizedBox(height: 14),

            // Multiple File Attachments Picker
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF181C28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.attach_file, color: Color(0xFF38BDF8), size: 18),
                          SizedBox(width: 6),
                          Text('Task Attachments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF334155),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.add_photo_alternate, size: 16, color: Colors.white),
                        label: const Text('Add Files', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final picked = await _picker.pickMultiImage(imageQuality: 85);
                          if (picked.isNotEmpty) {
                            setState(() => _attachedFiles.addAll(picked));
                          }
                        },
                      ),
                    ],
                  ),
                  if (_attachedFiles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No files attached yet. (Images, PDFs, docs)', style: TextStyle(color: Colors.white38, fontSize: 11.5)),
                    )
                  else ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _attachedFiles.map((f) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.file_present, color: Colors.greenAccent, size: 14),
                              const SizedBox(width: 4),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 130),
                                child: Text(f.name, style: const TextStyle(color: Colors.white, fontSize: 11), overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setState(() => _attachedFiles.remove(f)),
                                child: const Icon(Icons.close, color: Colors.redAccent, size: 14),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _submitTask,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.send, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Create Task & Send Push Notification',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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

  Widget _buildTextField(TextEditingController ctrl, String label, {IconData? icon, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: _inputDecoration(label, icon: icon),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
      prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF38BDF8), size: 18) : null,
      filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
    );
  }
}
