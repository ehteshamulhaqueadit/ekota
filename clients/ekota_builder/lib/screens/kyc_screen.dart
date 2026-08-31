import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:didit_sdk/sdk_flutter.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../widgets/verification_badge.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _api = ApiClient();
  bool _isLoading = false;

  Future<void> _startKyc() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.post('/kyc/initiate', {});
      if (res != null && res['session_token'] != null) {
        final token = res['session_token'];
        
        // Wait for SDK to finish/close
        await DiditSdk.startVerification(token);
        
        // Automatically check status after SDK closes
        await _checkStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start KYC: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/kyc/status');
      if (res != null && res['kycStatus'] != null) {
        if (mounted) {
          context.read<AuthProvider>().updateKycStatus(res['kycStatus']);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity Verification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Your Current Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Center(
              child: VerificationBadge(
                kycStatus: auth.kycStatus,
                isEmailVerified: auth.isEmailVerified,
              ),
            ),
            const SizedBox(height: 48),
            if (auth.kycStatus != 'VERIFIED') ...[
              const Text(
                'Complete your KYC to unlock all platform features. This requires a quick face scan and identity check.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _startKyc,
                icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.camera_alt),
                label: const Text('Start Face Scan'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ] else ...[
              const Text(
                'You are fully verified! No further action is required.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.green),
              ),
            ],
            const Spacer(),
            TextButton(
              onPressed: _isLoading ? null : _checkStatus,
              child: const Text('Refresh Status'),
            ),
          ],
        ),
      ),
    );
  }
}
