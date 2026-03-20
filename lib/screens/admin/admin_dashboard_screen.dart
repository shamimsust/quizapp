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
      backgroundColor: const Color(0xFFEFF2F6),
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontFamily: 'Inter')),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                context.go('/'); 
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        children: [
          // --- LIVE STATISTICS SECTION ---
          const Text(
            'Live Statistics',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatCards(),
          const SizedBox(height: 32),

          // --- ACTIVE EXAMS (EDIT & PUBLISH SECTION) ---
          const Text(
            'Active Exams',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          _buildActiveExamsList(),
          const SizedBox(height: 32),

          // --- TOURNAMENT MANAGEMENT ---
          const Text(
            'Tournament Management',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          _DashboardTile(
            title: 'Create New Exam',
            subtitle: 'Setup metadata for a new session',
            icon: Icons.add_task_outlined,
            onTap: () => context.go('/admin/exam-builder'),
          ),
          _DashboardTile(
            title: 'Token Manager',
            subtitle: 'Generate and monitor entry codes',
            icon: Icons.vpn_key_outlined,
            onTap: () => context.go('/admin/token-manager'),
          ),
          _DashboardTile(
            title: 'Manual Grading',
            subtitle: 'Review LaTeX and non-auto-graded answers',
            icon: Icons.grading_outlined,
            onTap: () => context.go('/admin/manual-grading'), 
          ),
          const Divider(height: 40),
          
          // --- SYSTEM ---
          const Text(
            'System',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          _DashboardTile(
            title: 'Student Portal',
            subtitle: 'Switch to the exam entry screen',
            icon: Icons.school_outlined,
            onTap: () => context.go('/'), 
          ),
        ],
      ),
    );
  }

  // Helper to list existing exams for Editing/Publishing
  Widget _buildActiveExamsList() {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('exams').onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text("Error loading exams");
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Text("No exams created yet.", style: TextStyle(color: Colors.black38));
        }

        final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final exams = data.entries.toList();

        return Column(
          children: exams.map((e) {
            final id = e.key;
            final val = Map<String, dynamic>.from(e.value as Map);
            final status = val['status'] ?? 'draft';
            final isPublished = status == 'published';

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text(val['title'] ?? 'Unnamed Exam', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Status: ${status.toUpperCase()}", 
                  style: TextStyle(color: isPublished ? Colors.green : Colors.orange, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // PUBLISH BUTTON
                    IconButton(
                      icon: Icon(isPublished ? Icons.cloud_done : Icons.cloud_upload_outlined),
                      color: isPublished ? Colors.green : Colors.grey,
                      onPressed: () => _togglePublish(id, status),
                      tooltip: isPublished ? 'Unpublish' : 'Publish',
                    ),
                    // EDIT QUESTIONS BUTTON
                    IconButton(
                      icon: const Icon(Icons.edit_note_outlined, color: Color(0xFF2264D7)),
                      onPressed: () => context.go('/admin/exam-builder/questions/$id'),
                      tooltip: 'Edit Questions',
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _togglePublish(String id, String currentStatus) async {
    final newStatus = currentStatus == 'published' ? 'draft' : 'published';
    await FirebaseDatabase.instance.ref('exams/$id').update({'status': newStatus});
  }

  Widget _buildStatCards() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Active Tokens',
            path: 'examTokens', 
            icon: Icons.vpn_key,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Total Attempts',
            path: 'attempts', 
            icon: Icons.people,
            color: Colors.green,
          ),
        ),
      ],
    );
  }
}

// ... Rest of your _StatCard and _DashboardTile classes remain exactly the same ...
class _StatCard extends StatelessWidget {
  final String label;
  final String path;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.path,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref(path).onValue,
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value as Map;
          count = data.length;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(
                count.toString(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
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

  const _DashboardTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2264D7).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF2264D7), size: 28),
        ),
        title: Text(
          title, 
          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 16)
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black26),
        onTap: onTap,
      ),
    );
  }
}