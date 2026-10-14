import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DayAttendanceHistoryDialog extends StatefulWidget {
  final String employeeName;
  final int? userId;
  final String formattedDate;
  final String dateStr;
  final List<dynamic> punches; // list of serialized punch objects
  final VoidCallback? onRefreshNeeded;

  const DayAttendanceHistoryDialog({
    super.key,
    required this.employeeName,
    this.userId,
    required this.formattedDate,
    required this.dateStr,
    required this.punches,
    this.onRefreshNeeded,
  });

  static void show(
    BuildContext context, {
    required String employeeName,
    int? userId,
    required String formattedDate,
    required String dateStr,
    required List<dynamic> punches,
    VoidCallback? onRefreshNeeded,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DayAttendanceHistoryDialog(
        employeeName: employeeName,
        userId: userId,
        formattedDate: formattedDate,
        dateStr: dateStr,
        punches: punches,
        onRefreshNeeded: onRefreshNeeded,
      ),
    );
  }

  @override
  State<DayAttendanceHistoryDialog> createState() => _DayAttendanceHistoryDialogState();
}

class _DayAttendanceHistoryDialogState extends State<DayAttendanceHistoryDialog> {
  late List<dynamic> _punchesList;

  @override
  void initState() {
    super.initState();
    _punchesList = List.from(widget.punches);
  }

  void _showZoomImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black,
              title: const Text('Attendance Photo', style: TextStyle(color: Colors.white, fontSize: 16)),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('Failed to load image', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showEditModal(dynamic punch) {
    final int punchId = punch['id'] ?? 0;
    String status = (punch['type'] ?? 'IN').toString().toUpperCase();
    final timeController = TextEditingController(text: punch['time'] ?? '09:49 AM');
    final locationController = TextEditingController(text: punch['location'] ?? '');
    final remarksController = TextEditingController(text: punch['remarks'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.employeeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text(widget.formattedDate, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              const Text('Edit Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 14),

              // Status Dropdown
              const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: ['IN', 'OUT', 'ABSENT', 'LEAVE', 'HOLIDAY', 'WEEK OFF'].contains(status) ? status : 'IN',
                    isExpanded: true,
                    items: ['IN', 'OUT', 'ABSENT', 'LEAVE', 'HOLIDAY', 'WEEK OFF']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => status = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Shift Info
              const Text('Shift', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                child: const Text('General Staff Shift (09:45 AM - 08:30 PM)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
              ),
              const SizedBox(height: 12),

              // Timestamp Input
              const Text('Timestamp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 4),
              TextField(
                controller: timeController,
                decoration: InputDecoration(
                  suffixIcon: const Icon(Icons.access_time),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Geo Address
              const Text('Geo Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 4),
              TextField(
                controller: locationController,
                decoration: InputDecoration(
                  hintText: 'Enter location',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Remarks
              const Text('Remarks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              const SizedBox(height: 4),
              TextField(
                controller: remarksController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Enter remarks (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 18),

              // Action Buttons matching SS
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                    icon: const Icon(Icons.check, size: 16, color: Colors.white),
                    label: const Text('Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      await ApiService.updateAttendancePunch(
                        punchId: punchId,
                        status: status,
                        time: timeController.text,
                        locationText: locationController.text,
                        remarks: remarksController.text,
                      );
                      if (mounted) {
                        Navigator.pop(ctx);
                        if (widget.onRefreshNeeded != null) widget.onRefreshNeeded!();
                        Navigator.pop(context);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                    icon: const Icon(Icons.delete, size: 16, color: Colors.white),
                    label: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      await ApiService.deleteAttendancePunch(punchId);
                      if (mounted) {
                        Navigator.pop(ctx);
                        if (widget.onRefreshNeeded != null) widget.onRefreshNeeded!();
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header Bar matching SS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF0F2644),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.employeeName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.formattedDate,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Table Header (Action | Status | Time | Location | Photo) matching SS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: const [
                SizedBox(
                  width: 50,
                  child: Text('Action', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                SizedBox(
                  width: 65,
                  child: Text('Status', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Time', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Location', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                SizedBox(
                  width: 60,
                  child: Text('Photo', textAlign: TextAlign.end, style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),

          // List of Punches
          Expanded(
            child: _punchesList.isEmpty
                ? const Center(
                    child: Text('No punch records for this date', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _punchesList.length,
                    separatorBuilder: (ctx, i) => const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (ctx, index) {
                      final p = _punchesList[index];
                      final isIn = (p['type'] ?? '').toString().toUpperCase() == 'IN';
                      final String time = p['time'] ?? '10:00 AM';
                      final String location = p['location'] ?? 'N/A';
                      final String? photoUrl = p['photo'];

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            // Action Edit Icon Button matching SS
                            SizedBox(
                              width: 50,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: InkWell(
                                  onTap: () => _showEditModal(p),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF38BDF8)),
                                    ),
                                    child: const Icon(Icons.edit_square, color: Color(0xFF38BDF8), size: 16),
                                  ),
                                ),
                              ),
                            ),

                            // Status Badge (IN / OUT)
                            SizedBox(
                              width: 65,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isIn ? const Color(0xFF14532D) : const Color(0xFF7F1D1D),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isIn ? 'IN' : 'OUT',
                                    style: TextStyle(
                                      color: isIn ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Punch Time
                            Expanded(
                              flex: 2,
                              child: Text(time, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                            ),

                            // Location Text
                            Expanded(
                              flex: 3,
                              child: Text(
                                location,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),

                            // Photo Thumbnail with Click to Zoom
                            SizedBox(
                              width: 60,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () {
                                    if (photoUrl != null && photoUrl.isNotEmpty) {
                                      _showZoomImage(photoUrl);
                                    }
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: photoUrl != null && photoUrl.isNotEmpty
                                        ? Image.network(
                                            photoUrl,
                                            width: 50,
                                            height: 34,
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, stack) => _placeholderPhoto(),
                                          )
                                        : _placeholderPhoto(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderPhoto() {
    return Container(
      width: 50,
      height: 34,
      color: Colors.grey.shade800,
      child: const Icon(Icons.person, color: Colors.white54, size: 18),
    );
  }
}
