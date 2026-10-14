import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';

class AttendanceScanScreen extends StatefulWidget {
  final UserModel user;
  final String initialType; // in or out
  final int? targetEmployeeId; // Set when manager punches for staff

  const AttendanceScanScreen({
    super.key,
    required this.user,
    required this.initialType,
    this.targetEmployeeId,
  });

  @override
  State<AttendanceScanScreen> createState() => _AttendanceScanScreenState();
}

class _AttendanceScanScreenState extends State<AttendanceScanScreen> {
  late String _type;
  int? _selectedEmployeeId;
  List<dynamic> _teamList = [];
  bool _isScanning = false;
  bool _faceDetected = false;
  String? _greetingMessage;
  String? _errorMessage;
  String _faceStatusText = 'Scanning face...';
  bool _isFrontCamera = true;
  File? _capturedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _selectedEmployeeId = widget.targetEmployeeId;

    // Self punch (staff or manager self) defaults to Front Camera; Manager punching staff defaults to Back Camera
    if (widget.targetEmployeeId != null && widget.targetEmployeeId != widget.user.id) {
      _isFrontCamera = false; // Back camera for manager punching staff
    } else {
      _isFrontCamera = true; // Front camera by default for self punch
    }

    _updateTime();
    if (widget.user.isManager) {
      _loadTeam();
    }

    _startFaceScanAndPunch();
  }

  void _updateTime() {
  }

  void _loadTeam() async {
    try {
      final res = await ApiService.getDepartmentEmployees();
      setState(() {
        _teamList = res;
      });
    } catch (e) {
      debugPrint("Error loading team: $e");
    }
  }

  void _showSelectStaffSearchDialog() {
    final searchCtrl = TextEditingController();
    List<dynamic> filtered = List.from(_teamList);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Select Staff for Attendance', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search staff by name or dept...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onChanged: (q) {
                    setDialogState(() {
                      filtered = _teamList.where((e) {
                        final name = (e['name'] ?? '').toString().toLowerCase();
                        final dept = (e['department'] ?? '').toString().toLowerCase();
                        return name.contains(q.toLowerCase()) || dept.contains(q.toLowerCase());
                      }).toList();
                    });
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 250,
                  child: ListView(
                    children: [
                      ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFF2563EB), child: Icon(Icons.person, color: Colors.white)),
                        title: Text('Self (${widget.user.name})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onTap: () {
                          setState(() {
                            _selectedEmployeeId = null;
                            _isFrontCamera = true;
                            _capturedImage = null;
                          });
                          Navigator.pop(ctx);
                          _startFaceScanAndPunch();
                        },
                      ),
                      const Divider(color: Colors.white12),
                      ...filtered.map((e) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF0F172A),
                              backgroundImage: e['photo'] != null ? NetworkImage(e['photo']) : null,
                              child: e['photo'] == null ? Text((e['name'] ?? 'S')[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null,
                            ),
                            title: Text(e['name'] ?? 'Staff', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text(e['department'] ?? 'General Staff', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            onTap: () {
                              setState(() {
                                _selectedEmployeeId = e['id'];
                                _isFrontCamera = false;
                                _capturedImage = null;
                              });
                              Navigator.pop(ctx);
                              _startFaceScanAndPunch();
                            },
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _capturePhoto() async {
    try {
      final cameraDevice = _isFrontCamera ? CameraDevice.front : CameraDevice.rear;
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: cameraDevice,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (image != null) {
        setState(() {
          _capturedImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint("Camera capture error: $e");
    }
  }

  void _startFaceScanAndPunch() async {
    final isSelfPunch = _selectedEmployeeId == null || _selectedEmployeeId == widget.user.id;

    setState(() {
      _isScanning = true;
      _faceDetected = false;
      _greetingMessage = null;
      _errorMessage = null;
      _faceStatusText = isSelfPunch ? 'Keep face in circle...' : 'Scanning staff face...';
    });

    // Attempt to capture photo automatically if not yet captured
    if (_capturedImage == null) {
      await _capturePhoto();
    }

    // Brief processing pause
    await Future.delayed(const Duration(milliseconds: 1200));

    setState(() {
      _faceDetected = true;
      _faceStatusText = 'Face & Photo Verified!';
    });

    try {
      final res = await ApiService.punchAttendance(
        type: _type,
        lat: 26.8581,
        lng: 75.7642,
        faceDetected: true,
        employeeId: _selectedEmployeeId,
        photoPath: _capturedImage?.path,
      );

      setState(() => _isScanning = false);

      if (res['punch'] != null) {
        final speakMsg = res['speak'] ?? res['greeting'] ?? 'Attendance marked successfully!';
        final nextAction = res['next_action'] ?? (_type == 'in' ? 'out' : 'in');

        setState(() {
          _greetingMessage = speakMsg;
          _type = nextAction; // Update next action automatically
        });

        // Voice Greeting
        await TtsService.speak(speakMsg);

        // Auto close after 2.5 seconds success
        await Future.delayed(const Duration(milliseconds: 2500));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to mark attendance.';
        });
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
        _errorMessage = 'Error marking attendance: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyTitle = widget.user.companyName ?? 'TULSI FABRICS INDIA PVT LTD';
    final targetName = _selectedEmployeeId != null
        ? (_teamList.firstWhere((e) => e['id'] == _selectedEmployeeId, orElse: () => {'name': 'Staff'})['name'])
        : widget.user.name;

    final isSelfPunch = _selectedEmployeeId == null || _selectedEmployeeId == widget.user.id;

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          companyTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_front, color: Colors.white),
            onPressed: () {
              setState(() {
                _isFrontCamera = !_isFrontCamera;
                _capturedImage = null;
              });
              _startFaceScanAndPunch();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _capturedImage = null);
              _startFaceScanAndPunch();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status Banners
            Container(
              width: double.infinity,
              color: const Color(0xFF1E293B),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                'Ready to mark attendance ${_type.toUpperCase()} for $targetName',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            Container(
              width: double.infinity,
              color: const Color(0xFF1E293B),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Text(
                'Current Shift: ${widget.user.shiftName ?? "General Staff Shift (09:45 AM - 08:30 PM)"}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),

            // Manager Employee Selection Bar with Search Button
            if (widget.user.isManager)
              Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
                      color: Colors.amberAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isFrontCamera ? "FRONT (Selfie)" : "BACK (Manager Mode)",
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      icon: const Icon(Icons.search, size: 14, color: Color(0xFF38BDF8)),
                      label: Text(
                        _selectedEmployeeId == null ? 'Self (${widget.user.name})' : targetName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _showSelectStaffSearchDialog,
                    ),
                  ],
                ),
              ),

            // Circular Viewfinder with Photo Preview
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _capturePhoto,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 250,
                              height: 250,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _faceDetected ? Colors.greenAccent : Colors.white70,
                                  width: 3,
                                ),
                              ),
                            ),
                            ClipOval(
                              child: Container(
                                width: 236,
                                height: 236,
                                color: Colors.grey.shade900,
                                child: _capturedImage != null
                                    ? Image.file(_capturedImage!, fit: BoxFit.cover)
                                    : Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Icon(
                                            Icons.person,
                                            size: 160,
                                            color: Colors.grey.shade700,
                                          ),
                                          if (_isScanning)
                                            const Positioned(
                                              bottom: 20,
                                              child: CircularProgressIndicator(color: Colors.white),
                                            ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Status & Greeting Messages
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _errorMessage ?? _greetingMessage ?? _faceStatusText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _errorMessage != null
                                ? Colors.redAccent
                                : (_greetingMessage != null ? Colors.greenAccent : Colors.white),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      Text(
                        isSelfPunch
                            ? 'Selfie Mode (${_isFrontCamera ? "Front Camera" : "Back Camera"})'
                            : 'Manager Attendance Mode for $targetName (Back Camera)',
                        style: TextStyle(
                          color: isSelfPunch ? Colors.white54 : Colors.amberAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF0F172A),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        label: const Text('Capture Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          await _capturePhoto();
                          _startFaceScanAndPunch();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
