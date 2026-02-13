import 'package:flutter/material.dart';
import 'content_editor_screen.dart';
import 'projects_screen.dart';
import 'resume_upload_screen.dart';
import '../services/seed_data.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio Admin')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildNavItem(context, 'Edit Hero Section', 'hero', Icons.home),
          _buildNavItem(context, 'Edit About Section', 'about', Icons.person),
          _buildNavItem(
            context,
            'Edit Expertise',
            'expertise',
            Icons.lightbulb,
          ),
          _buildNavItem(context, 'Edit Skills', 'skills', Icons.code),
          _buildNavItem(context, 'Edit Contact Info', 'contact', Icons.email),
          _buildNavItem(context, 'Edit Navbar', 'navbar', Icons.menu),
          _buildNavItem(context, 'Personal Info', 'personal', Icons.face),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.work, color: Colors.amber),
            title: const Text('Manage Projects'),
            subtitle: const Text('Add, edit, or remove projects'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            tileColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProjectsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description, color: Colors.blueAccent),
            title: const Text('Auto-fill from Resume'),
            subtitle: const Text('Upload PDF to populate fields'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            tileColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ResumeUploadScreen()),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.greenAccent),
            title: const Text('Seed Database'),
            subtitle: const Text('Fill with initial portfolio data'),
            tileColor: Colors.white.withOpacity(0.05),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Seeding database...')));
              await DataSeeder().seedAllData();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Database seeded!')));
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    String title,
    String docId,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        tileColor: Colors.white.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContentEditorScreen(docId: docId, title: title),
          ),
        ),
      ),
    );
  }
}
