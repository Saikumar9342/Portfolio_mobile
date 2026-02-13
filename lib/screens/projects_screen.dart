import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.streamProjects(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No projects yet'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['title'] ?? 'Untitled'),
                subtitle: Text(
                  data['description'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => service.deleteProject(doc.id),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProjectEditorScreen(docId: doc.id, initialData: data),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProjectEditorScreen()),
          );
        },
      ),
    );
  }
}

class ProjectEditorScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? initialData;

  const ProjectEditorScreen({super.key, this.docId, this.initialData});

  @override
  State<ProjectEditorScreen> createState() => _ProjectEditorScreenState();
}

class _ProjectEditorScreenState extends State<ProjectEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _techStackController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _liveLinkController = TextEditingController();
  final _githubLinkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _titleController.text = widget.initialData!['title'] ?? '';
      _descController.text = widget.initialData!['description'] ?? '';
      _techStackController.text =
          (widget.initialData!['techStack'] as List<dynamic>?)?.join(', ') ??
              '';
      _imageUrlController.text = widget.initialData!['imageUrl'] ?? '';
      _liveLinkController.text = widget.initialData!['liveLink'] ?? '';
      _githubLinkController.text = widget.initialData!['githubLink'] ?? '';
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final data = {
        'title': _titleController.text,
        'description': _descController.text,
        'techStack': _techStackController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'imageUrl': _imageUrlController.text,
        'liveLink': _liveLinkController.text,
        'githubLink': _githubLinkController.text,
      };

      try {
        if (widget.docId != null) {
          await FirestoreService().updateProject(widget.docId!, data);
        } else {
          await FirestoreService().addProject(data);
        }
        if (mounted) Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.docId == null ? 'Add Project' : 'Edit Project'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            TextFormField(
              controller: _techStackController,
              decoration: const InputDecoration(
                labelText: 'Tech Stack (comma separated)',
              ),
            ),
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Image URL',
                hintText: 'https://example.com/image.png',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                if (!value.startsWith('http')) return 'Must be a valid URL';
                if (value.contains('google.com/search')) {
                  return 'This is a Google Search link, not an image link.\nRight-click image -> Copy Image Address';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _liveLinkController,
              decoration: const InputDecoration(labelText: 'Live Link'),
            ),
            TextFormField(
              controller: _githubLinkController,
              decoration: const InputDecoration(labelText: 'GitHub Link'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
