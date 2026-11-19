import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> employee;
  final VoidCallback? onUpdated;
  final bool isSelf;
  final bool canManageEmployees;

  const EditProfileScreen({
    super.key,
    required this.employee,
    this.onUpdated,
    this.isSelf = false,
    this.canManageEmployees = false,
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
    _loadFaceImages();
  }

  List<Map<String, dynamic>> _faceImages = [];
  bool _loadingFaceImages = false;

  Future<void> _loadFaceImages() async {
    final empId = widget.employee['id'] ?? widget.employee['user_id'];
    if (empId == null) return;
    final int? userId = int.tryParse(empId.toString());
    setState(() => _loadingFaceImages = true);
    try {
      final res = await ApiService.getFaceImages(userId: userId);
      if (res['success'] == true && res['face_images'] is List) {
        if (mounted) {
          setState(() {
            _faceImages = List<Map<String, dynamic>>.from(res['face_images']);
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading face images: $e");
    } finally {
      if (mounted) setState(() => _loadingFaceImages = false);
    }
  }

  void _showAddFaceImagesModal() {
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Face Reference Photos',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Add clear front-facing face photos for AI facial recognition and selfie attendance verification.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.camera_alt, color: Color(0xFF38BDF8), size: 20),
                label: const Text('Capture with Camera', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _captureAndUploadSingleFace();
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.photo_library, color: Color(0xFF38BDF8), size: 20),
                label: const Text('Choose Multiple from Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _pickAndUploadMultipleFaces();
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _captureAndUploadSingleFace() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 900,
      );
      if (photo == null) return;
      await _uploadFaceFilePaths([photo.path]);
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  Future<void> _pickAndUploadMultipleFaces() async {
    try {
      final List<XFile> photos = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 900,
      );
      if (photos.isEmpty) return;
      await _uploadFaceFilePaths(photos.map((p) => p.path).toList());
    } catch (e) {
      debugPrint("Gallery multi-pick error: $e");
    }
  }

  Future<void> _uploadFaceFilePaths(List<String> paths) async {
    final empId = widget.employee['id'] ?? widget.employee['user_id'];
    final int? userId = empId != null ? int.tryParse(empId.toString()) : null;

    setState(() => _loadingFaceImages = true);
    try {
      final res = await ApiService.uploadFaceImages(
        filePaths: paths,
        userId: userId,
      );

      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${paths.length} face reference ${paths.length > 1 ? "images" : "image"} uploaded ✔️'),
              backgroundColor: const Color(0xFF166534),
            ),
          );
        }
        await _loadFaceImages();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Upload failed'), backgroundColor: const Color(0xFFDC2626)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading face images: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingFaceImages = false);
    }
  }

  Future<void> _deleteFaceImage(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Face Image?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this AI face reference image?', style: TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loadingFaceImages = true);
    try {
      final res = await ApiService.deleteFaceImage(id);
      if (res['success'] == true) {
        setState(() {
          _faceImages.removeWhere((img) => img['id'] == id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Face reference image deleted ✔️'), backgroundColor: Color(0xFF166534)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to delete face image'), backgroundColor: const Color(0xFFDC2626)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingFaceImages = false);
    }
  }

  Widget _buildFaceImagesSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.7),
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
                children: [
                  const Icon(Icons.face_retouching_natural, color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'AI Face References (${_faceImages.length})',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              InkWell(
                onTap: _showAddFaceImagesModal,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_photo_alternate, color: Color(0xFF38BDF8), size: 14),
                      SizedBox(width: 4),
                      Text('+ Add Photos', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload multiple photos of the staff member face for accurate AI biometric verification during attendance check-in.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 10),
          if (_loadingFaceImages)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 2),
                ),
              ),
            )
          else if (_faceImages.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  const Icon(Icons.no_photography_outlined, color: Colors.white38, size: 28),
                  const SizedBox(height: 6),
                  const Text('No face reference photos uploaded yet', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    icon: const Icon(Icons.add_a_photo, size: 14),
                    label: const Text('Add Face Photos Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: _showAddFaceImagesModal,
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _faceImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, index) {
                  final img = _faceImages[index];
                  final int? imgId = int.tryParse(img['id'].toString());
                  String imgUrl = (img['url'] ?? '').toString();
                  if (imgUrl.isEmpty && img['path'] != null) {
                    final base = ApiService.baseUrl.replaceAll('/api', '');
                    imgUrl = '$base/storage/${img['path']}';
                  }

                  return Stack(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imgUrl.isNotEmpty
                              ? Image.network(
                                  imgUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image, color: Colors.white38, size: 24),
                                  ),
                                )
                              : const Center(child: Icon(Icons.image, color: Colors.white38, size: 24)),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () {
                            if (imgId != null) _deleteFaceImage(imgId);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.delete, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
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
                if (widget.isSelf && !widget.canManageEmployees) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, color: Color(0xFFF97316), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('AI Selfie Verification', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              SizedBox(height: 2),
                              Text('Locked: Only Manager or Admin can upload or edit your AI Selfie Verification.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  _buildToggleTile('AI Selfie Verification', _aiSelfie, (v) => setState(() => _aiSelfie = v)),
                  _buildFaceImagesSection(),
                ],
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
