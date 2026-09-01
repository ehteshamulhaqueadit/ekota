import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/rental_service.dart';

/// Active Rental Portal — shown to a renter once a booking is confirmed.
///
/// Features:
///  * Real-time countdown timer for the rental duration
///  * Live status tracking (Pending Pickup / Active / Returned)
///  * Auto-generated QR-coded digital gate-pass scanned at the warehouse
///  * Audit trail of warehouse scans (pickup / return)
class RentalPortalScreen extends StatefulWidget {
  final String rentalId;
  const RentalPortalScreen({super.key, required this.rentalId});

  @override
  State<RentalPortalScreen> createState() => _RentalPortalScreenState();
}

class _RentalPortalScreenState extends State<RentalPortalScreen> {
  Map<String, dynamic>? _portal;
  bool _isLoading = true;
  String? _error;
  Timer? _ticker;
  DateTime? _now;
  bool _isReturning = false;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    // Real-time countdown: re-render every second.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadPortal();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadPortal() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final portal = await PublicRentalService.getRentalPortal(widget.rentalId);
      if (!mounted) return;
      setState(() {
        _portal = portal;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load rental portal: $e';
        _isLoading = false;
      });
    }
  }

  String get _status {
    final s = (_portal?['status'] ?? '').toString();
    if (s == 'ACTIVE') return 'Active';
    if (s == 'RETURNED') return 'Returned';
    return 'Pending Pickup';
  }

  /// True once the renter has requested a return — a NEW return gate-pass QR
  /// has been generated and is awaiting warehouse verification.
  bool get _isReturnRequested {
    final code = (_portal?['returnGatePassCode'] ?? '').toString();
    return code.isNotEmpty;
  }

  Color get _statusColor {
    final s = (_portal?['status'] ?? '').toString();
    if (s == 'ACTIVE') return const Color(0xFF10B981);
    if (s == 'RETURNED') return const Color(0xFF64748B);
    return const Color(0xFFF59E0B);
  }

  IconData get _statusIcon {
    final s = (_portal?['status'] ?? '').toString();
    if (s == 'ACTIVE') return Icons.play_circle_fill;
    if (s == 'RETURNED') return Icons.check_circle;
    return Icons.schedule;
  }

  /// Remaining rental time, recomputed live every second.
  Duration? get _remaining {
    final expected = _portal?['expectedReturnAt'];
    if (expected == null || _now == null) return null;
    final target = DateTime.tryParse(expected.toString());
    if (target == null) return null;
    return target.difference(_now!);
  }

  String _formatCountdown(Duration d) {
    if (d.isNegative) return '00:00:00';
    final days = d.inDays;
    final h = d.inHours % 24;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return days > 0 ? '${days}d ${two(h)}:${two(m)}:${two(s)}' : '${two(h)}:${two(m)}:${two(s)}';
  }

  Future<void> _returnProduct() async {
    final poolItemId = _portal?['poolItemId']?.toString();
    if (poolItemId == null || poolItemId.isEmpty) return;

    // Confirm the return request. The server generates a NEW return gate-pass
    // QR that the warehouse scans to finally complete the return.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return Product'),
        content: const Text(
          'Requesting a return will generate a NEW return gate-pass QR. '
          'Show this QR at the warehouse so they can verify and complete your return.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Request Return', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isReturning = true);
    try {
      final result = await PublicRentalService.returnProduct(poolItemId);
      if (!mounted) return;
      if (result['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Return requested! Show the new QR at the warehouse to complete it.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadPortal();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      await _loadPortal();
    } finally {
      if (mounted) setState(() => _isReturning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: const Text('Rental Portal'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadPortal,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStatusCard(),
                      const SizedBox(height: 16),
                      _buildCountdownCard(),
                      const SizedBox(height: 16),
                      _buildGatePassCard(),
                      const SizedBox(height: 16),
                      _buildTimelineCard(),
                      const SizedBox(height: 16),
                      if (_status == 'Active' && !_isReturnRequested) _buildReturnButton(),
                      if (_status == 'Active' && _isReturnRequested) _buildReturnPendingCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadPortal, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  // ── Status card ──────────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    final listing = _portal?['listing'] ?? {};
    final imageUrls = List<String>.from(listing['imageUrls'] ?? []);
    final start = _portal?['startDate'] != null
        ? DateTime.tryParse(_portal!['startDate'].toString())
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrls.isNotEmpty
                ? Image.network(imageUrls.first,
                    width: 64, height: 64, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 64, height: 64, color: Colors.grey[100],
                      child: const Icon(Icons.inventory_2, color: Colors.grey)))
                : Container(
                    width: 64, height: 64, color: Colors.grey[100],
                    child: const Icon(Icons.inventory_2, color: Colors.grey)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing['assetName'] ?? 'Product',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('৳${(_portal?['dailyRate'] ?? 0).toStringAsFixed(0)}/day',
                    style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w600)),
                if (start != null)
                  Text('Booked ${DateFormat('MMM d, h:mm a').format(start)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon, size: 16, color: _statusColor),
                const SizedBox(width: 4),
                Text(_status,
                    style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Countdown card ───────────────────────────────────────────────────────
  Widget _buildCountdownCard() {
    final remaining = _remaining;
    final isReturned = _status == 'Returned';
    final isOverdue = remaining != null && remaining.isNegative && !isReturned;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF8B7BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isReturned ? Icons.verified : Icons.timer_outlined,
                  color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                isReturned
                    ? 'Rental Completed'
                    : isOverdue
                        ? 'Rental Overdue'
                        : _status == 'Pending Pickup'
                            ? 'Rental Window Ends In'
                            : 'Time Remaining',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isReturned ? '—' : _formatCountdown(remaining ?? Duration.zero),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isReturned
                ? 'Product returned successfully'
                : 'Expected return: ${_formatDate(_portal?['expectedReturnAt'])}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso.toString());
    if (d == null) return '—';
    return DateFormat('MMM d, yyyy • h:mm a').format(d);
  }

  // ── Digital gate-pass card ───────────────────────────────────────────────
  Widget _buildGatePassCard() {
    final returnCode = (_portal?['returnGatePassCode'] ?? '').toString();
    final code = (_portal?['gatePassCode'] ?? '').toString();
    final scannedAt = _portal?['gatePassScannedAt'];
    final isReturnRequested = returnCode.isNotEmpty;

    // Once a return is requested, the card switches to the NEW return QR.
    final displayCode = isReturnRequested ? returnCode : code;
    final title = isReturnRequested ? 'Return Gate-Pass' : 'Digital Gate-Pass';
    final subtitle = isReturnRequested
        ? 'Show this QR at the warehouse to complete your return.'
        : 'Show this QR at the warehouse gate to verify pickup & return.';
    final accent = isReturnRequested ? const Color(0xFFDC2626) : const Color(0xFF6C63FF);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2, color: accent),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              if (isReturnRequested)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Return Pending',
                      style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                )
              else if (scannedAt != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Scanned',
                      style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (displayCode.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withOpacity(0.3)),
              ),
              child: QrImageView(
                data: displayCode,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1E1B4B)),
                dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1E1B4B)),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Gate-pass not available yet.',
                  style: TextStyle(color: Colors.grey)),
            ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 8),
          SelectableText(
            displayCode,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 11, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  // ── Timeline / audit trail ───────────────────────────────────────────────
  Widget _buildTimelineCard() {
    final events = List<Map<String, dynamic>>.from(_portal?['events'] ?? []);
    final pickupBy = _portal?['pickupVerifiedBy'];
    final returnBy = _portal?['returnVerifiedBy'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activity Log',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          if (events.isEmpty)
            Text('No activity yet.', style: TextStyle(color: Colors.grey[500]))
          else
            ...events.map((e) => _buildTimelineRow(e)).toList(),
          if (pickupBy != null) ...[
            const SizedBox(height: 8),
            Text('Pickup verified by ${pickupBy['fullName'] ?? 'Warehouse'}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
          if (returnBy != null) ...[
            const SizedBox(height: 4),
            Text('Return verified by ${returnBy['fullName'] ?? 'Warehouse'}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineRow(Map<String, dynamic> event) {
    final type = (event['type'] ?? '').toString();
    final createdAt = event['createdAt'] != null
        ? DateTime.tryParse(event['createdAt'].toString())
        : null;

    IconData icon;
    Color color;
    String label;
    switch (type) {
      case 'CREATED':
        icon = Icons.event_available;
        color = const Color(0xFF6C63FF);
        label = 'Booking confirmed';
        break;
      case 'PICKED_UP':
        icon = Icons.inventory_2;
        color = const Color(0xFF10B981);
        label = 'Picked up at warehouse';
        break;
      case 'RETURNED':
        icon = Icons.assignment_return;
        color = const Color(0xFF64748B);
        label = 'Returned to warehouse';
        break;
      case 'SCANNED':
        icon = Icons.qr_code_scanner;
        color = const Color(0xFFF59E0B);
        label = 'Gate-pass scanned';
        break;
      default:
        icon = Icons.info_outline;
        color = Colors.grey;
        label = type;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (createdAt != null)
                  Text(DateFormat('MMM d, h:mm a').format(createdAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Return button ────────────────────────────────────────────────────────
  Widget _buildReturnButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isReturning ? null : _returnProduct,
        icon: _isReturning
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.assignment_return),
        label: Text(_isReturning ? 'Processing…' : 'Return Product'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.red.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  // ── Return pending card ─────────────────────────────────────────────────
  Widget _buildReturnPendingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.hourglass_top, color: Color(0xFFF59E0B)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Return requested. Show the return gate-pass QR above at the warehouse to complete your return.',
              style: TextStyle(color: Color(0xFF92400E), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}