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

class _AttendanceScanScreenState extends State<AttendanceScanScreen>
    with SingleTickerProviderStateMixin {
  late String _type;
  int? _selectedEmployeeId;
  bool _autoDetectStaff = true;
  List<dynamic> _teamList = [];
  bool _isScanning = false;
  bool _faceVerified = false;
  String? _greetingMessage;
  String? _errorMessage;
  String _faceStatusText = 'Align your face inside the circle...';
  bool _isFrontCamera = true;
  File? _capturedImage;
  Map<String, dynamic>? _detectedEmployee;
  final ImagePicker _picker = ImagePicker();

  late AnimationController _animCtrl;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _selectedEmployeeId = widget.targetEmployeeId;

    final bool isManagerOrCanMark = widget.user.isManager || widget.user.canMarkOthers;
    if (isManagerOrCanMark) {
      if (widget.targetEmployeeId != null && widget.targetEmployeeId != widget.user.id) {
        // Manager punching for a specific selected staff member
        _selectedEmployeeId = widget.targetEmployeeId;
        _isFrontCamera = false;
        _autoDetectStaff = false;
      } else {
        // Manager punching for self: ALWAYS self by default, front camera!
        _selectedEmployeeId = null;
        _isFrontCamera = true;
        _autoDetectStaff = false;
      }
      _loadTeam();
    } else {
      _selectedEmployeeId = null;
      _isFrontCamera = true;
      _autoDetectStaff = false;
    }

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );

    // Prompt camera capture on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capturePhotoAndVerify();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _loadTeam() async {
    try {
      final res = await ApiService.getDepartmentEmployees();
      if (mounted) {
        setState(() {
          _teamList = res;
        });
      }
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Select Staff for Attendance',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search staff by name or code...',
                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 18),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onChanged: (q) {
                    setDialogState(() {
                      filtered = _teamList.where((e) {
                        final name = (e['name'] ?? '').toString().toLowerCase();
                        final dept = (e['department'] ?? '').toString().toLowerCase();
                        final code = (e['employee_code'] ?? '').toString().toLowerCase();
                        final query = q.toLowerCase();
                        return name.contains(query) || dept.contains(query) || code.contains(query);
                      }).toList();
                    });
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 260,
                  child: ListView(
                    children: [
                      ListTile(
                        dense: true,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF0284C7),
                          radius: 16,
                          child: Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                        ),
                        title: const Text('AI Auto-Detect Face (Any Staff)',
                            style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('Scans face and recognizes staff automatically',
                            style: TextStyle(color: Colors.white54, fontSize: 11)),
                        onTap: () {
                          setState(() {
                            _autoDetectStaff = true;
                            _selectedEmployeeId = null;
                            _isFrontCamera = false;
                            _capturedImage = null;
                            _detectedEmployee = null;
                          });
                          Navigator.pop(ctx);
                          _capturePhotoAndVerify();
                        },
                      ),
                      const Divider(color: Colors.white12),
                      ListTile(
                        dense: true,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF2563EB),
                          radius: 16,
                          child: Icon(Icons.person, color: Colors.white, size: 16),
                        ),
                        title: Text('Self (${widget.user.name})',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        onTap: () {
                          setState(() {
                            _autoDetectStaff = false;
                            _selectedEmployeeId = null;
                            _isFrontCamera = true;
                            _capturedImage = null;
                            _detectedEmployee = null;
                          });
                          Navigator.pop(ctx);
                          _capturePhotoAndVerify();
                        },
                      ),
                      const Divider(color: Colors.white12),
                      ...filtered.map((e) => ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF0F172A),
                              radius: 16,
                              backgroundImage: e['photo'] != null && e['photo'].toString().isNotEmpty
                                  ? NetworkImage(e['photo'])
                                  : null,
                              child: e['photo'] == null
                                  ? Text((e['name'] ?? 'S')[0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontSize: 12))
                                  : null,
                            ),
                            title: Text(e['name'] ?? 'Staff',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text(
                              '${e['employee_code'] ?? ''} • ${e['department'] ?? 'General Staff'}',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            onTap: () {
                              setState(() {
                                _autoDetectStaff = false;
                                _selectedEmployeeId = e['id'];
                                _isFrontCamera = false;
                                _capturedImage = null;
                                _detectedEmployee = null;
                              });
                              Navigator.pop(ctx);
                              _capturePhotoAndVerify();
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

  Future<void> _capturePhotoAndVerify() async {
    setState(() {
      _errorMessage = null;
      _greetingMessage = null;
      _faceVerified = false;
      _isScanning = true;
      _faceStatusText = 'Align your face inside the circle...';
    });

    try {
      final cameraDevice = _isFrontCamera ? CameraDevice.front : CameraDevice.rear;
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: cameraDevice,
        imageQuality: 75,
        maxWidth: 900,
      );

      if (image == null) {
        setState(() {
          _isScanning = false;
          _faceStatusText = 'Face capture cancelled. Tap "Scan Face" to try again.';
        });
        return;
      }

      setState(() {
        _capturedImage = File(image.path);
        _faceStatusText = 'Fetching GPS location & verifying face with AI...';
      });

      // Get real GPS coordinates from device (falls back to office coords if GPS is unavailable)
      double punchLat = await ApiService.getOfficeLat();
      double punchLng = await ApiService.getOfficeLng();
      try {
        final pos = await ApiService.getDeviceCurrentPosition();
        if (pos != null) {
          punchLat = pos.latitude;
          punchLng = pos.longitude;
        }
      } catch (e) {
        debugPrint("Error reading device GPS: $e");
      }

      Map<String, dynamic> res;

      if (_autoDetectStaff) {
        // Manager Mode: AI auto-detects staff from registered face images
        res = await ApiService.recognizeAndPunch(
          photoPath: image.path,
          lat: punchLat,
          lng: punchLng,
        );
      } else {
        // Specific staff or Self attendance: verify against registered profile
        res = await ApiService.punchAttendance(
          type: _type,
          lat: punchLat,
          lng: punchLng,
          faceDetected: true,
          employeeId: _selectedEmployeeId,
          photoPath: image.path,
        );
      }

      setState(() => _isScanning = false);

      if (res['punch'] != null) {
        final speakMsg = res['speak'] ?? res['greeting'] ?? 'Attendance marked successfully!';
        final nextAction = res['next_action'] ?? (_type == 'in' ? 'out' : 'in');

        setState(() {
          _faceVerified = true;
          _greetingMessage = speakMsg;
          _type = nextAction;
          if (res['employee'] != null) {
            _detectedEmployee = res['employee'];
          }
        });

        // Voice Greeting
        await TtsService.speak(speakMsg);

        // Auto close after 2.8 seconds on success
        await Future.delayed(const Duration(milliseconds: 2800));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        final err = res['message'] ?? 'Face not recognized with Edit Staff Member AI Selfie Verification image.';
        setState(() {
          _faceVerified = false;
          _errorMessage = err;
        });
        await TtsService.speak('Face not recognized');
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
        _faceVerified = false;
        _errorMessage = 'Error during face verification: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyTitle = widget.user.companyName ?? 'TULSI FABRICS INDIA PVT LTD';

    String modeDescription = '';
    if (_autoDetectStaff) {
      modeDescription = 'Manager Mode: Auto-Detect Staff Face';
    } else if (_selectedEmployeeId != null && _selectedEmployeeId != widget.user.id) {
      final staffObj = _teamList.firstWhere(
        (e) => e['id'] == _selectedEmployeeId,
        orElse: () => {'name': 'Staff'},
      );
      modeDescription = 'Manager Mode: Marking for ${staffObj['name']}';
    } else {
      modeDescription = 'Self Attendance: ${widget.user.name}';
    }

    final Color ringColor = _errorMessage != null
        ? const Color(0xFFEF4444)
        : (_faceVerified ? const Color(0xFF10B981) : const Color(0xFF0284C7));

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          companyTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Flip Camera',
            icon: Icon(
              _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
              color: const Color(0xFF38BDF8),
            ),
            onPressed: () {
              setState(() {
                _isFrontCamera = !_isFrontCamera;
                _capturedImage = null;
              });
              _capturePhotoAndVerify();
            },
          ),
          IconButton(
            tooltip: 'Retry Scan',
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              setState(() {
                _capturedImage = null;
                _detectedEmployee = null;
              });
              _capturePhotoAndVerify();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Subtitle banner with shift and mode
            Container(
              width: double.infinity,
              color: const Color(0xFF1E293B),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    _autoDetectStaff ? Icons.auto_awesome : Icons.person_pin,
                    color: const Color(0xFF38BDF8),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      modeDescription,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.user.isManager || widget.user.canMarkOthers)
                    InkWell(
                      onTap: _showSelectStaffSearchDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF0284C7)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune, color: Color(0xFF38BDF8), size: 12),
                            SizedBox(width: 4),
                            Text('Change Mode', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Viewfinder Area
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),

                      // Holographic Circular Scanner Frame
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Pulsing Glow Circle
                          Container(
                            width: 270,
                            height: 270,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: ringColor.withOpacity(0.35),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),

                          // Outer Ring with Target Dashes
                          Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: ringColor, width: 3),
                            ),
                          ),

                          // Inner Clipped Face View
                          ClipOval(
                            child: Container(
                              width: 246,
                              height: 246,
                              color: const Color(0xFF0F172A),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (_capturedImage != null)
                                    Image.file(
                                      _capturedImage!,
                                      width: 246,
                                      height: 246,
                                      fit: BoxFit.cover,
                                    )
                                  else
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.face_retouching_natural,
                                          size: 110,
                                          color: Colors.white.withOpacity(0.35),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Place face here',
                                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                        ),
                                      ],
                                    ),

                                  // Animated Laser Scan Line
                                  if (_isScanning)
                                    AnimatedBuilder(
                                      animation: _scanAnimation,
                                      builder: (context, child) {
                                        return Align(
                                          alignment: Alignment(0.0, _scanAnimation.value),
                                          child: Container(
                                            height: 3,
                                            width: 246,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  ringColor,
                                                  Colors.white,
                                                  ringColor,
                                                  Colors.transparent,
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: ringColor.withOpacity(0.8),
                                                  blurRadius: 10,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                  // Corner target guides
                                  Positioned(
                                    top: 18,
                                    left: 45,
                                    child: Container(width: 14, height: 2, color: ringColor),
                                  ),
                                  Positioned(
                                    top: 18,
                                    left: 45,
                                    child: Container(width: 2, height: 14, color: ringColor),
                                  ),
                                  Positioned(
                                    top: 18,
                                    right: 45,
                                    child: Container(width: 14, height: 2, color: ringColor),
                                  ),
                                  Positioned(
                                    top: 18,
                                    right: 45,
                                    child: Container(width: 2, height: 14, color: ringColor),
                                  ),
                                  Positioned(
                                    bottom: 18,
                                    left: 45,
                                    child: Container(width: 14, height: 2, color: ringColor),
                                  ),
                                  Positioned(
                                    bottom: 18,
                                    left: 45,
                                    child: Container(width: 2, height: 14, color: ringColor),
                                  ),
                                  Positioned(
                                    bottom: 18,
                                    right: 45,
                                    child: Container(width: 14, height: 2, color: ringColor),
                                  ),
                                  Positioned(
                                    bottom: 18,
                                    right: 45,
                                    child: Container(width: 2, height: 14, color: ringColor),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Verification Success Icon Overlay
                          if (_faceVerified)
                            Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 38),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Detected Employee Card (Manager Mode Auto-Detect)
                      if (_detectedEmployee != null)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFF0F172A),
                                backgroundImage: _detectedEmployee!['avatar'] != null
                                    ? NetworkImage(_detectedEmployee!['avatar'])
                                    : null,
                                child: _detectedEmployee!['avatar'] == null
                                    ? const Icon(Icons.person, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _detectedEmployee!['name'] ?? 'Staff',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      '${_detectedEmployee!['employee_code'] ?? ''} • ${_detectedEmployee!['department'] ?? ''}',
                                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.verified, color: Color(0xFF10B981), size: 22),
                            ],
                          ),
                        ),

                      // Status & Error Messages Banner
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _errorMessage ?? _greetingMessage ?? _faceStatusText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _errorMessage != null
                                ? const Color(0xFFEF4444)
                                : (_faceVerified ? const Color(0xFF10B981) : Colors.white),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        _isFrontCamera
                            ? 'Front Camera (Selfie Mode)'
                            : 'Back Camera (${_autoDetectStaff ? "AI Auto-Detect" : "Target Staff"})',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Action Bar
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
                          backgroundColor: _faceVerified ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(
                          _faceVerified ? Icons.check_circle : Icons.camera_alt,
                          color: Colors.white,
                        ),
                        label: Text(
                          _faceVerified
                              ? 'Verified & Marked!'
                              : (_isScanning ? 'Verifying Face...' : 'Scan Face Now'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: _isScanning ? null : _capturePhotoAndVerify,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
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
