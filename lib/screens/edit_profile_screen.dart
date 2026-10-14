import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> employee;
  final VoidCallback? onUpdated;

  const EditProfileScreen({
    super.key,
    required this.employee,
    this.onUpdated,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _empCodeController;
  late TextEditingController _designationController;
  late TextEditingController _departmentController;
  late TextEditingController _vendorController;

  bool _mobileAttendance = true;
  bool _multipleAttendance = false;
  bool _aiSelfie = true;
  bool _liveTracking = true;
  bool _selfOdometer = false;
  bool _esiApplicable = false;
  bool _overtimeApplicable = true;

  bool _isSaving = false;
  String? _photoUrl;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final emp = widget.employee;
    final nameParts = (emp['name'] ?? emp['first_name'] ?? '').toString().split(' ');
    final firstName = emp['first_name'] ?? (nameParts.isNotEmpty ? nameParts.first : '');
    final lastName = emp['last_name'] ?? (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');

    _firstNameController = TextEditingController(text: firstName);
    _lastNameController = TextEditingController(text: lastName);
    _phoneController = TextEditingController(text: emp['phone'] ?? '');
    _emailController = TextEditingController(text: emp['email'] ?? '');
    _passwordController = TextEditingController(text: '********');
    _empCodeController = TextEditingController(text: emp['employee_code'] ?? '');
    _designationController = TextEditingController(text: emp['designation'] ?? '');
    _departmentController = TextEditingController(text: emp['department'] ?? '');
    _vendorController = TextEditingController(text: emp['vendor_name'] ?? '');

    _mobileAttendance = emp['mobile_attendance'] ?? true;
    _multipleAttendance = emp['multiple_attendance'] ?? false;
    _aiSelfie = emp['ai_selfie'] ?? true;
    _liveTracking = emp['live_tracking'] ?? true;
    _selfOdometer = emp['self_odometer'] ?? false;
    _esiApplicable = emp['esi_applicable'] ?? false;
    _overtimeApplicable = emp['overtime_applicable'] ?? true;

    _photoUrl = emp['photo'];
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint("Photo pick error: $e");
    }
  }

  void _showEditAvatarModal() {
    // Bottom Sheet matching Screenshot 2 (Edit avatar: Camera / Gallery / Remove photo)
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
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Edit avatar', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.blueGrey,
                  backgroundImage: _selectedImage != null
                      ? FileImage(_selectedImage!) as ImageProvider
                      : (_photoUrl != null && _photoUrl!.isNotEmpty ? NetworkImage(_photoUrl!) : null),
                  child: (_selectedImage == null && (_photoUrl == null || _photoUrl!.isEmpty))
                      ? Text(
                          _firstNameController.text.isNotEmpty ? _firstNameController.text[0].toUpperCase() : 'E',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Camera photo option
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                label: const Text('Take photo from Camera', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _pickImage(ImageSource.camera);
                },
              ),
            ),
            const SizedBox(height: 10),

            // Gallery photo option
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.photo_library, color: Colors.white, size: 20),
                label: const Text('Choose from Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _pickImage(ImageSource.gallery);
                },
              ),
            ),
            const SizedBox(height: 10),

            // Remove photo button
            if (_selectedImage != null || (_photoUrl != null && _photoUrl!.isNotEmpty))
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                  label: const Text('Remove photo', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                  onPressed: () {
                    setState(() {
                      _selectedImage = null;
                      _photoUrl = null;
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final empId = widget.employee['id'] ?? widget.employee['user_id'];
      final res = await ApiService.updateProfile(
        userId: empId != null ? int.tryParse(empId.toString()) : null,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        employeeCode: _empCodeController.text.trim(),
        designation: _designationController.text.trim(),
        department: _departmentController.text.trim(),
        vendorName: _vendorController.text.trim(),
        password: _passwordController.text == '********' ? null : _passwordController.text,
        mobileAttendance: _mobileAttendance,
        multipleAttendance: _multipleAttendance,
        aiSelfie: _aiSelfie,
        liveTracking: _liveTracking,
        selfOdometer: _selfOdometer,
        esiApplicable: _esiApplicable,
        overtimeApplicable: _overtimeApplicable,
        photoPath: _selectedImage?.path,
      );

      setState(() => _isSaving = false);

      if (res['ok'] == true) {
        if (widget.onUpdated != null) widget.onUpdated!();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee profile updated successfully! ✔️'), backgroundColor: Color(0xFF166534)),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to update profile'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e'), backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = '${_firstNameController.text} ${_lastNameController.text}'.trim();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit ${name.isNotEmpty ? name : "Staff"}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _saveProfile,
                    child: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Avatar with Camera Overlay
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: Colors.blueGrey,
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!) as ImageProvider
                            : (_photoUrl != null && _photoUrl!.isNotEmpty ? NetworkImage(_photoUrl!) : null),
                        child: (_selectedImage == null && (_photoUrl == null || _photoUrl!.isEmpty))
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'E',
                                style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showEditAvatarModal,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF0F172A), width: 3),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _firstNameController,
                        label: 'First Name',
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _lastNameController,
                        label: 'Last Name',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  suffixIcon: const Icon(Icons.contact_phone, color: Colors.white54),
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _emailController,
                  label: 'Email Address',
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  obscureText: true,
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _empCodeController,
                  label: 'Employee Code',
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _designationController,
                  label: 'Designation',
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _departmentController,
                  label: 'Department',
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _vendorController,
                  label: 'Vendor Name',
                ),
                const SizedBox(height: 24),

                const Text('Permissions & Configurations', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                _buildToggleTile('Mobile Attendance', _mobileAttendance, (v) => setState(() => _mobileAttendance = v)),
                _buildToggleTile('Multiple Punching', _multipleAttendance, (v) => setState(() => _multipleAttendance = v)),
                _buildToggleTile('AI Selfie Verification', _aiSelfie, (v) => setState(() => _aiSelfie = v)),
                _buildToggleTile('Live Location Tracking', _liveTracking, (v) => setState(() => _liveTracking = v)),
                _buildToggleTile('Self Odometer', _selfOdometer, (v) => setState(() => _selfOdometer = v)),
                _buildToggleTile('ESI Applicable', _esiApplicable, (v) => setState(() => _esiApplicable = v)),
                _buildToggleTile('Overtime Applicable', _overtimeApplicable, (v) => setState(() => _overtimeApplicable = v)),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1E293B),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleTile(String title, bool val, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        value: val,
        thumbColor: WidgetStateProperty.all(val ? const Color(0xFF38BDF8) : Colors.grey),
        onChanged: onChanged,
      ),
    );
  }
}
