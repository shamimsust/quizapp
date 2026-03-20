import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

class AdminSignInScreen extends ConsumerStatefulWidget {
  const AdminSignInScreen({super.key});

  @override
  ConsumerState<AdminSignInScreen> createState() => _AdminSignInScreenState();
}

class _AdminSignInScreenState extends ConsumerState<AdminSignInScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  final Color _primaryBlue = const Color(0xFF2264D7); //

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF2F6), //
      appBar: AppBar(
        title: const Text('Admin Access', style: TextStyle(fontFamily: 'Inter')),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.admin_panel_settings, size: 80, color: Color(0xFF2264D7)),
                const SizedBox(height: 16),
                const Text(
                  'Tournament Management',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                ),
                const Text(
                  'Enter credentials to access dashboard',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Admin Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _loading ? null : _handleSignIn,
                    child: _loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Sign In to Dashboard', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignIn() async {
    final email = _email.text.trim();
    final pass = _pass.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all credentials.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // Sign in via Firebase
      await AuthService().signInAdmin(email, pass);
      
      // Small delay to allow the 'userRoleProvider' to catch up with the 'admin' claim
      // This prevents the GoRouter redirect from kicking you back to '/' immediately.
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        // Use go() to clear the navigation stack
        context.go('/admin'); 
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}