import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class LeaveRequestScreen extends StatefulWidget {
  final UserModel user;
  const LeaveRequestScreen({super.key, required this.user});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  bool _isLoading = true;
  String _selectedFilter = 'All'; // All, Leave, Loan, Pending, Approved, Rejected

  Map<String, dynamic>? _dashboardSummary;
  List<dynamic> _holidaysList = [];
  List<dynamic> _requestsList = [];

  // Controllers for New Leave Request
  final _leaveReasonController = TextEditingController();
  String _leaveType = 'Casual Leave';
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedDocumentPath;

  @override
  void initState() {
    super.initState();
    _loadAllRequestData();
  }

  Future<void> _loadAllRequestData() async {
    setState(() => _isLoading = true);
    try {
      final dashRes = await ApiService.getRequestDashboard();
      final listRes = await ApiService.getRequests();

      setState(() {
        _dashboardSummary = dashRes['summary'];
        _holidaysList = dashRes['holidays'] ?? [];
        _requestsList = listRes['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF166534),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _submitLeaveForm() async {
    final reason = _leaveReasonController.text.trim();
    if (reason.isEmpty) {
      _showMsg('Please enter a reason for your leave request.', isError: true);
      return;
    }

    if (_fromDate.isAfter(_toDate)) {
      _showMsg('From Date cannot be after To Date.', isError: true);
      return;
    }

    final fromStr = _fromDate.toIso8601String().split('T')[0];
    final toStr = _toDate.toIso8601String().split('T')[0];

    final res = await ApiService.submitLeaveRequest(
      leaveType: _leaveType,
      fromDate: fromStr,
      toDate: toStr,
      reason: reason,
      photoPath: _selectedDocumentPath,
    );

    if (res['ok'] == true || res['data'] != null) {
      _leaveReasonController.clear();
      _selectedDocumentPath = null;
      if (!mounted) return;
      Navigator.pop(context);
      _loadAllRequestData();
      _showMsg('New Leave Request submitted successfully!');
    } else {
      _showMsg(res['message'] ?? 'Failed to submit leave request', isError: true);
    }
  }

  void _handleAdminStatusUpdate(int id, String category, String status) async {
    final res = await ApiService.updateRequestStatus(
      id: id,
      category: category,
      status: status,
    );

    if (res['ok'] == true) {
      _loadAllRequestData();
      if (status == 'approved') {
        _showMsg('Request Approved successfully! ✔️');
      } else {
        _showMsg('Request Rejected! ❌', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Requests & Approvals', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAllRequestData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllRequestData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Apply Action Buttons (Apply Leave)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_task, color: Colors.white, size: 18),
                        label: const Text('Apply Leave Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: _showNewLeaveModal,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Filter Chips (All, Leave, Loan, Pending, Approved, Rejected) matching SS
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'Leave', 'Loan / Advance', 'Pending', 'Approved', 'Rejected']
                            .map((f) => _buildFilterChip(f))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Company Holidays Card Section matching SS
                    if (_holidaysList.isNotEmpty) ...[
                      _buildHolidaysSection(),
                      const SizedBox(height: 20),
                    ],

                    // Requests List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.user.isManager ? 'All Staff Requests' : 'My Submitted Requests',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Total: ${_getFilteredRequests().length}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Request Cards List
                    _buildRequestsList(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSel = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSel ? const Color(0xFF0F172A) : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSel ? Colors.white : const Color(0xFF475569),
            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildHolidaysSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.beach_access, color: Color(0xFFF97316), size: 18),
              SizedBox(width: 6),
              Text('Upcoming Company Holidays', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _holidaysList.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final h = _holidaysList[i];
                return Container(
                  width: 170,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDBA74)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h['name'] ?? 'Holiday', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF9A3412))),
                      const SizedBox(height: 4),
                      Text(h['date'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                      Text(h['day'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
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

  List<dynamic> _getFilteredRequests() {
    return _requestsList.where((r) {
      final category = (r['request_category'] ?? '').toString().toLowerCase();
      final status = (r['status'] ?? '').toString().toLowerCase();

      if (_selectedFilter == 'Leave' && category != 'leave') return false;
      if (_selectedFilter == 'Loan / Advance' && category != 'loan') return false;
      if (_selectedFilter == 'Pending' && status != 'pending') return false;
      if (_selectedFilter == 'Approved' && status != 'approved') return false;
      if (_selectedFilter == 'Rejected' && status != 'rejected') return false;

      return true;
    }).toList();
  }

  Widget _buildRequestsList() {
    final filtered = _getFilteredRequests();

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Column(
          children: [
            Icon(Icons.inbox, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('No requests found under this filter.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final req = filtered[i];
        final isLeave = req['request_category'] == 'leave';
        final String title = req['title'] ?? (isLeave ? 'Leave Request' : 'Loan Request');
        final String status = (req['status'] ?? 'pending').toString().toLowerCase();
        final String userName = req['user_name'] ?? 'Staff Member';
        final String dateText = isLeave ? (req['date_range'] ?? '') : (req['formatted_amount'] ?? '₹0');

        final isPending = status == 'pending';
        final isApproved = status == 'approved';
        final isRejected = status == 'rejected';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          color: Colors.white,
          child: InkWell(
            onTap: () => _showRequestDetailsModal(req),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isLeave ? const Color(0xFFEFF6FF) : const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isLeave ? 'LEAVE' : 'LOAN',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isLeave ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                        ],
                      ),

                      // Status Badge (Pending ⏳, Approved ✔️, Rejected ❌)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isApproved
                              ? const Color(0xFFDCFCE7)
                              : (isRejected ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isApproved ? Icons.check_circle : (isRejected ? Icons.cancel : Icons.hourglass_top),
                              size: 13,
                              color: isApproved
                                  ? const Color(0xFF166534)
                                  : (isRejected ? const Color(0xFF991B1B) : const Color(0xFF92400E)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isApproved
                                    ? const Color(0xFF166534)
                                    : (isRejected ? const Color(0xFF991B1B) : const Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (widget.user.isManager) ...[
                    Text('Requested by: $userName', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF475569))),
                    const SizedBox(height: 2),
                  ],

                  Text(dateText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
                  if (req['reason'] != null && req['reason'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      req['reason'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],

                  // Manager Action Buttons (Approve / Reject) directly on card
                  if (widget.user.isManager && isPending) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFDC2626)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => _handleAdminStatusUpdate(req['id'], req['request_category'], 'rejected'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF166534),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          ),
                          icon: const Icon(Icons.check, color: Colors.white, size: 16),
                          label: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => _handleAdminStatusUpdate(req['id'], req['request_category'], 'approved'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showNewLeaveModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Submit Leave Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: _leaveType,
                decoration: InputDecoration(
                  labelText: 'Leave Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 'Casual Leave', child: Text('Casual Leave')),
                  DropdownMenuItem(value: 'Paid Leave', child: Text('Paid Leave')),
                  DropdownMenuItem(value: 'Sick Leave', child: Text('Sick Leave')),
                  DropdownMenuItem(value: 'Vacation', child: Text('Vacation')),
                  DropdownMenuItem(value: 'Unpaid Leave', child: Text('Unpaid Leave')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => _leaveType = val);
                },
              ),
              const SizedBox(height: 12),

              // Date Pickers Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('From: ${_fromDate.toString().split(' ')[0]}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _fromDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setModalState(() => _fromDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('To: ${_toDate.toString().split(' ')[0]}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _toDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setModalState(() => _toDate = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _leaveReasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason for Leave',
                  hintText: 'Describe your leave reason here...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _submitLeaveForm,
                  child: const Text('Submit Leave Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  void _showRequestDetailsModal(Map<String, dynamic> req) {
    final isLeave = req['request_category'] == 'leave';
    final String status = (req['status'] ?? 'pending').toString().toLowerCase();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(req['title'] ?? 'Request Details', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'approved' ? const Color(0xFFDCFCE7) : (status == 'rejected' ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 20),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text((req['user_name'] ?? 'S')[0])),
              title: Text(req['user_name'] ?? 'Staff Member', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(req['user_designation'] ?? 'Employee'),
            ),

            const SizedBox(height: 8),
            Text(isLeave ? 'Date Range: ${req['date_range']}' : 'Loan Amount: ${req['formatted_amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Reason: ${req['reason'] ?? 'N/A'}', style: const TextStyle(color: Colors.black87)),

            if (widget.user.isManager && status == 'pending') ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleAdminStatusUpdate(req['id'], req['request_category'], 'rejected');
                      },
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF166534)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleAdminStatusUpdate(req['id'], req['request_category'], 'approved');
                      },
                      child: const Text('Approve', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
