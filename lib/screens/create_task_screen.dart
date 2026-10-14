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
  
  String _priority = 'medium';
  String _repeatType = 'none';
  int? _selectedDeptId;
  int? _selectedAssignedId;

  List<int> _selectedOtherIds = [];
  bool _selectAllOthers = false;

  DateTime? _selectedDueDate;
  TimeOfDay? _selectedDueTime;
  XFile? _attachedFile;
  final ImagePicker _picker = ImagePicker();

  List<dynamic> _departments = [];
  List<dynamic> _employees = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMastersAndEmployees();
  }

  void _loadMastersAndEmployees() async {
    try {
      final masters = await ApiService.getMasters();
      final emps = await ApiService.getDepartmentEmployees();
      setState(() {
        _departments = masters['departments'] ?? [];
        _employees = emps;
      });
    } catch (e) {
      debugPrint("Error loading task data: $e");
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
    setState(() => _employees = emps);
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
        departmentId: _selectedDeptId,
        assignedToId: _selectedAssignedId,
        others: _selectedOtherIds,
        attachmentFilePath: _attachedFile?.path,
      );

      setState(() => _isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Task created! Push notifications sent.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Create & Assign Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(_titleController, 'Task Title *', icon: Icons.task_alt),
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
                          const Text('Select All', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  if (_employees.isEmpty)
                    const Text('No employees found.', style: TextStyle(color: Colors.white54, fontSize: 12))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _employees.map((e) {
                        final int id = e['id'];
                        final isSelected = _selectedOtherIds.contains(id);
                        return FilterChip(
                          label: Text(e['name'], style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 11)),
                          selected: isSelected,
                          selectedColor: const Color(0xFF38BDF8),
                          backgroundColor: const Color(0xFF334155),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedOtherIds.add(id);
                              } else {
                                _selectedOtherIds.remove(id);
                                _selectAllOthers = false;
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Priority Level & Repeat Task Option
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E293B),
                    value: _priority,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Priority', icon: Icons.flag_outlined),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'medium', child: Text('Medium', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'high', child: Text('High', style: TextStyle(color: Colors.redAccent))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _priority = val);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E293B),
                    value: _repeatType,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration('Repeat Option', icon: Icons.repeat),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('No Repeat (One-time)', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'daily', child: Text('Daily', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'quarterly', child: Text('Quarterly', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'half_yearly', child: Text('Half-Yearly', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'yearly', child: Text('Yearly', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _repeatType = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Due Date & Time Pickers
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDueDate ?? DateTime.now(),
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _selectedDueDate = picked);
                    },
                    child: InputDecorator(
                      decoration: _inputDecoration('Due Date', icon: Icons.calendar_today),
                      child: Text(
                        _selectedDueDate != null
                            ? "${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}"
                            : 'Pick Date',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedDueTime ?? const TimeOfDay(hour: 12, minute: 0),
                      );
                      if (picked != null) setState(() => _selectedDueTime = picked);
                    },
                    child: InputDecorator(
                      decoration: _inputDecoration('Due Time', icon: Icons.access_time),
                      child: Text(
                        _selectedDueTime != null ? _selectedDueTime!.format(context) : 'Pick Time',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Attachment Selection
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF181C28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _attachedFile != null ? _attachedFile!.name : 'Attach Document / File',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155)),
                    onPressed: () async {
                      final file = await _picker.pickImage(source: ImageSource.gallery);
                      if (file != null) setState(() => _attachedFile = file);
                    },
                    child: Text(_attachedFile != null ? 'Change' : 'Browse', style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            _buildTextField(_descController, 'Description / Remarks', maxLines: 3, icon: Icons.notes),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.send, color: Colors.black),
                onPressed: _isLoading ? null : _submitTask,
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Create Task & Send Push Notification', style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1, IconData? icon}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: _inputDecoration(label, icon: icon),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
      prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF38BDF8), size: 18) : null,
      filled: true,
      fillColor: const Color(0xFF181C28),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
    );
  }
}
