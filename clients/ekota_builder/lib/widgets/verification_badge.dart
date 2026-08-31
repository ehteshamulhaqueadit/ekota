import 'package:flutter/material.dart';

class VerificationBadge extends StatelessWidget {
  final String kycStatus;
  final bool isEmailVerified;

  const VerificationBadge({
    super.key,
    required this.kycStatus,
    required this.isEmailVerified,
  });

  @override
  Widget build(BuildContext context) {
    String text = 'Unverified';
    Color bgColor = Colors.grey[300]!;
    Color textColor = Colors.grey[800]!;
    IconData? icon;

    if (kycStatus == 'VERIFIED') {
      text = 'KYC Verified';
      bgColor = Colors.blue[100]!;
      textColor = Colors.blue[800]!;
      icon = Icons.verified_user;
    } else if (kycStatus == 'PENDING') {
      text = 'KYC Pending';
      bgColor = Colors.orange[100]!;
      textColor = Colors.orange[800]!;
      icon = Icons.hourglass_empty;
    } else if (kycStatus == 'REJECTED') {
      text = 'KYC Rejected';
      bgColor = Colors.red[100]!;
      textColor = Colors.red[800]!;
      icon = Icons.error_outline;
    } else if (isEmailVerified) {
      text = 'Email Verified';
      bgColor = Colors.green[100]!;
      textColor = Colors.green[800]!;
      icon = Icons.mark_email_read;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
