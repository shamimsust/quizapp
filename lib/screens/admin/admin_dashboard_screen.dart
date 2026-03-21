import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/auth_service.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF2264D7);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('ADMIN CONSOLE', 
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14)),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Sign Out',
            onPressed: () => _handleSignOut(context),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        children: [
          _buildSectionHeader('LIVE STATISTICS'),
          const SizedBox(height: 16),
          _buildStatCards(),
          
          const SizedBox(height: 40),
          _buildSectionHeader('EXAM MANAGEMENT'),
          const SizedBox(height: 16),
          _DashboardTile(
            title: 'Manage Exams',
            subtitle: 'Edit metadata, questions, and publish status',
            icon: Icons.inventory_2_rounded,
            onTap: () => context.push('/admin/exam-list'),
          ),
          _DashboardTile(
            title: 'Create New Exam',
            subtitle: 'Initialize settings for a new session',
            icon: Icons.add_circle_outline_rounded,
            onTap: () => context.push('/admin/exam-builder'),
          ),

          const SizedBox(height: 32),
          _buildSectionHeader('TOURNAMENT TOOLS'),
          const SizedBox(height: 16),
          _DashboardTile(
            title: 'Token Manager',
            subtitle: 'Generate and track entry codes',
            icon: Icons.key_rounded,
            onTap: () => context.push('/admin/token-manager'),
          ),
          _DashboardTile(
            title: 'Manual Grading',
            subtitle: 'Review written and LaTeX responses',
            icon: Icons.fact_check_rounded,
            onTap: () => context.push('/admin/manual-grading'), 
          ),
          _DashboardTile(
            title: 'Global Leaderboard',
            subtitle: 'View rankings and candidate performance',
            icon: Icons.emoji_events_rounded,
            color: const Color(0xFFF59E0B),
            onTap: () => context.push('/admin/leaderboard'), 
          ),

          const SizedBox(height: 40),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 32),
          
          _DashboardTile(
            title: 'Exit to Student Portal',
            subtitle: 'Switch to the candidate entry screen',
            icon: Icons.co_present_rounded,
            color: Colors.blueGrey.shade700,
            onTap: () => context.go('/'), 
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11, 
        fontWeight: FontWeight.w900, 
        color: Color(0xFF64748B), 
        letterSpacing: 1.3,
        fontFamily: 'Inter'
      ),
    );
  }

  Widget _buildStatCards() {
    return const Column( // Added 'const' here
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Active Tokens', 
                path: 'examTokens', 
                icon: Icons.vpn_key_rounded, 
                color: Color(0xFFF59E0B)
              )
            ),
            SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                label: 'Active Takers', 
                path: 'attempts', 
                icon: Icons.person_search_rounded, 
                color: Color(0xFF2264D7),
                filterActive: true,
              )
            ),
          ],
        ),
        SizedBox(height: 16),
        _StatCard(
          label: 'Total Completed Attempts', 
          path: 'attempts', 
          icon: Icons.analytics_rounded, 
          color: Color(0xFF10B981),
          fullWidth: true,
        ),
      ],
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to exit the admin console?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('SIGN OUT', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().signOut();
      if (context.mounted) context.go('/admin/signin');
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String path;
  final IconData icon;
  final Color color;
  final bool filterActive;
  final bool fullWidth;

  const _StatCard({
    required this.label, 
    required this.path, 
    required this.icon, 
    required this.color,
    this.filterActive = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref(path).onValue,
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value;
          if (data is Map) {
            if (filterActive) {
              count = data.values.where((v) => v is Map && v['status'] == 'started').length;
            } else {
              count = data.length;
            }
          }
        }

        return Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha((255 * 0.03).round()), blurRadius: 10, offset: const Offset(0, 4))
            ],
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withAlpha((255 * 0.1).round()), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  if (filterActive && count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
                      child: const Text("LIVE", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                ],
              ),
              const SizedBox(height: 16),
              Text(count.toString(), 
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'Inter', color: Color(0xFF0F172A))),
              Text(label, 
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500, fontFamily: 'Inter')),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _DashboardTile({
    required this.title, 
    required this.subtitle, 
    required this.icon, 
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? const Color(0xFF2264D7);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: themeColor.withAlpha((255 * 0.1).round()), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: themeColor, size: 24),
        ),
        title: Text(title, 
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E293B), fontFamily: 'Inter')),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Inter')),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
        onTap: onTap,
      ),
    );
  }
}