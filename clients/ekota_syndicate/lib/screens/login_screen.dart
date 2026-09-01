import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../services/chat_socket_service.dart';
import '../theme/app_theme.dart';
import 'investor_withdrawal_screen.dart';
import 'syndicate_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/auth/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Reset socket state before logging in
        ChatSocketService().dispose();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_email', _emailController.text.trim());
        if (data['token'] != null) {
          await prefs.setString('auth_token', data['token']);
        }
        if (data['user'] != null) {
          if (data['user']['id'] != null) {
            await prefs.setString('user_id', data['user']['id']);
          }
          if (data['user']['fullName'] != null) {
            await prefs.setString('user_name', data['user']['fullName']);
          }
          if (data['user']['email'] != null) {
            await prefs.setString('user_email', data['user']['email']);
          }
          if (data['user']['role'] != null) {
            await prefs.setString('user_role', data['user']['role']);
          }
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SyndicateHomeScreen()));
      } else {
        final data = jsonDecode(response.body);
        setState(() => _error = data['message'] ?? 'Login failed');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primary, Color(0xFF1E293B)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 8,
                shadowColor: Colors.black38,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.blueAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'INVESTOR PORTAL',
                            style: TextStyle(
                              color: AppTheme.blueAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ekota Syndicate',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Institutional split-buying & asset equity platform',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline, size: 20),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.dangerBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, size: 18, color: AppTheme.dangerText),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: AppTheme.dangerText, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_error != null) const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyndicateSignupScreen())),
                            child: const Text('Create Account'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordResetRequestScreen())),
                            child: const Text('Forgot Password?'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class SyndicateSignupScreen extends StatefulWidget {
  const SyndicateSignupScreen({super.key});

  @override
  State<SyndicateSignupScreen> createState() => _SyndicateSignupScreenState();
}

class _SyndicateSignupScreenState extends State<SyndicateSignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/auth/signup');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': _fullNameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'role': 'INVESTOR',
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Reset socket state before initializing new session
        ChatSocketService().dispose();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_email', _emailController.text.trim());
        if (data['token'] != null) {
          await prefs.setString('auth_token', data['token']);
        }
        if (data['user'] != null) {
          if (data['user']['id'] != null) {
            await prefs.setString('user_id', data['user']['id']);
          }
          if (data['user']['fullName'] != null) {
            await prefs.setString('user_name', data['user']['fullName']);
          }
          if (data['user']['email'] != null) {
            await prefs.setString('user_email', data['user']['email']);
          }
          if (data['user']['role'] != null) {
            await prefs.setString('user_role', data['user']['role']);
          }
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SyndicateHomeScreen()));
      } else {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Signup failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Investor Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Sign Up for Ekota', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Join prospective co-owners & investors', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Sign Up'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordResetRequestScreen extends StatefulWidget {
  const PasswordResetRequestScreen({super.key});

  @override
  State<PasswordResetRequestScreen> createState() => _PasswordResetRequestScreenState();
}

class _PasswordResetRequestScreenState extends State<PasswordResetRequestScreen> {
  final _emailController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/auth/password-reset/request');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim()}),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('If the account exists, an OTP has been sent.')),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => PasswordResetConfirmScreen(email: _emailController.text.trim()),
        ));
      } else {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to request reset')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Request Password Reset', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Enter your registered email to receive OTP', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 20),
                    TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined))),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Send Reset OTP'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordResetConfirmScreen extends StatefulWidget {
  final String email;
  const PasswordResetConfirmScreen({super.key, required this.email});

  @override
  State<PasswordResetConfirmScreen> createState() => _PasswordResetConfirmScreenState();
}

class _PasswordResetConfirmScreenState extends State<PasswordResetConfirmScreen> {
  late final TextEditingController _emailController;
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email);
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/auth/password-reset/reset-password');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'otpCode': _otpController.text.trim(),
          'newPassword': _newPasswordController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successful. Please login.')),
        );
        Navigator.pop(context);
      } else {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to reset password')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Reset')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Enter OTP & New Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email'), readOnly: true),
                    const SizedBox(height: 12),
                    TextField(controller: _otpController, decoration: const InputDecoration(labelText: 'OTP Code')),
                    const SizedBox(height: 12),
                    TextField(controller: _newPasswordController, decoration: const InputDecoration(labelText: 'New Password'), obscureText: true),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Reset Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
