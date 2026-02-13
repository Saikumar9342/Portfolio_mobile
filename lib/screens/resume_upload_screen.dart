import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../services/firestore_service.dart';

class ResumeUploadScreen extends StatefulWidget {
  const ResumeUploadScreen({super.key});

  @override
  State<ResumeUploadScreen> createState() => _ResumeUploadScreenState();
}

class _ResumeUploadScreenState extends State<ResumeUploadScreen> {
  bool _isLoading = false;
  String _status = '';
  final FirestoreService _firestoreService = FirestoreService();

  // State to hold extracted data for review
  List<Map<String, dynamic>> _extractedProjects = [];
  Map<String, dynamic> _extractedProfile = {};
  bool _hasParsed = false;

  Future<void> _pickAndParseResume() async {
    setState(() {
      _isLoading = true;
      _status = 'Picking file...';
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        String path = result.files.single.path!;
        setState(() => _status = 'Parsing PDF...');

        final String text = await _extractTextFromPdf(path);

        setState(() => _status = 'Analyzing data...');
        _analyzeData(text);

        setState(() {
          _isLoading = false;
          _hasParsed = true;
        });
      } else {
        setState(() {
          _status = 'Cancelled';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() {
        _status = 'Error occurred';
        _isLoading = false;
      });
    }
  }

  Future<String> _extractTextFromPdf(String path) async {
    final PdfDocument document =
        PdfDocument(inputBytes: File(path).readAsBytesSync());
    String text = PdfTextExtractor(document).extractText();
    document.dispose();
    return text;
  }

  void _analyzeData(String text) {
    // 1. Basic Info Extraction
    final emailRegex = RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w{2,4}\b');
    final email = emailRegex.firstMatch(text)?.group(0) ?? '';

    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    String name = lines.isNotEmpty ? lines.first.trim() : 'My Name';
    if (name.length > 50) name = name.substring(0, 50);

    final knownSkills = [
      'Flutter',
      'React',
      'Node.js',
      'TypeScript',
      'Dart',
      'Firebase',
      'AWS',
      'Python',
      'Java',
      'C++',
      'SQL',
      'NoSQL',
      'Git',
      'Docker',
      'Kubernetes',
      'Next.js',
      'Tailwind',
      'MongoDB'
    ];
    final foundSkills = knownSkills
        .where((s) => text.toLowerCase().contains(s.toLowerCase()))
        .toList();

    String bio = "Passionate developer building scalable apps.";
    final bioMatch = RegExp(
            r'(?<=Profile|Summary)([\s\S]*?)(?=Skills|Experience|Education|Projects)',
            caseSensitive: false)
        .firstMatch(text);
    if (bioMatch != null) {
      bio = bioMatch.group(1)?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? bio;
    }

    _extractedProfile = {
      'name': name,
      'email': email,
      'bio': bio,
      'skills': foundSkills,
    };

    // 2. Project Extraction
    _extractedProjects = _extractProjects(text, knownSkills);
  }

  List<Map<String, dynamic>> _extractProjects(
      String text, List<String> knownSkills) {
    List<Map<String, dynamic>> projects = [];
    String cleanText = text.replaceAll('\r\n', '\n');

    // LOCATE PROJECTS SECTION
    final projectHeaderRegex = RegExp(
        r'\n\s*(PROJECTS|Projects|PERSONAL PROJECTS|ACADEMIC PROJECTS)\s*(\n|$)',
        caseSensitive: false);
    final match = projectHeaderRegex.firstMatch(cleanText);

    if (match == null) return [];

    int startIndex = match.end;

    // FIND END OF SECTION
    final sectionHeaders = [
      'EDUCATION',
      'SKILLS',
      'EXPERIENCE',
      'WORK EXPERIENCE',
      'CERTIFICATIONS',
      'ACHIEVEMENTS',
      'LANGUAGES',
      'REFERENCES'
    ];
    final endSectionPattern = sectionHeaders.join('|');
    final nextSectionRegex = RegExp(
        r'\n\s*(' + endSectionPattern + r')\s*(\n|$)',
        caseSensitive: false);
    final nextMatch =
        nextSectionRegex.firstMatch(cleanText.substring(startIndex));

    int endIndex =
        nextMatch != null ? (startIndex + nextMatch.start) : cleanText.length;

    String projectSection = cleanText.substring(startIndex, endIndex).trim();

    // SPLIT BLOCKS
    List<String> blocks;
    // Try splitting by double newlines first
    if (projectSection.contains(RegExp(r'\n\s*\n'))) {
      blocks = projectSection.split(RegExp(r'\n\s*\n'));
    } else {
      // If tight layout, just take lines that look significant
      blocks = projectSection.split('\n');
    }

    for (var block in blocks) {
      block = block.trim();
      if (block.length < 15) continue; // Skip short garbage
      if (block.toLowerCase().contains('page ')) continue;

      final lines = block.split('\n');
      String title = lines.first.trim();

      // Cleanup dates/bullets
      title = title.replaceAll(RegExp(r'[\|\-]\s*\d{4}.*'), '').trim();
      if (title.startsWith(RegExp(r'[-•*]\s*')))
        title = title.substring(1).trim();

      String description =
          lines.length > 1 ? lines.sublist(1).join(' ').trim() : title;

      // Heuristic: If description is too short, maybe it's just a list item, skip or merge
      if (description.length < 10) continue;

      List<String> projectStack = knownSkills
          .where((s) =>
              "$title $description".toLowerCase().contains(s.toLowerCase()))
          .toList();

      projects.add({
        'title': title,
        'description': description,
        'techStack': projectStack.isEmpty ? ['Tech'] : projectStack,
        'imageUrl': 'https://placehold.co/600x400',
        'liveLink': '',
        'githubLink': '',
        'category': 'Project',
      });
    }
    return projects;
  }

  Future<void> _saveToFirestore() async {
    setState(() => _isLoading = true);

    try {
      // 1. Update Profile
      final name = _extractedProfile['name'];
      final email = _extractedProfile['email'];
      final skills = _extractedProfile['skills'] as List<String>;

      if (email.isNotEmpty) {
        await _firestoreService.updateContent('contact', {
          'email': email,
          'personalEmail': email,
          'title': 'Get In Touch',
          'cta': 'Message Me',
          'secondaryCta': 'CV'
        });
      }

      await _firestoreService.updateContent('hero', {
        'title': "HI, I'M ${name.toUpperCase()}",
        'subtitle': skills.isNotEmpty
            ? 'I build with ${skills.take(4).join(", ")}'
            : 'Software Engineer',
        'badge': 'Available for Work',
        'cta': 'Projects',
        'secondaryCta': 'Contact'
      });

      await _firestoreService.updateContent('about', {
        'title': 'About $name',
        'biography': _extractedProfile['bio'],
      });

      await _firestoreService.updateContent('skills', {
        'frameworks': skills,
        'frontend': skills
            .where((s) => [
                  'React',
                  'HTML',
                  'CSS',
                  'Next.js',
                  'Tailwind',
                  'Flutter'
                ].contains(s))
            .map((s) => {'name': s, 'level': 85})
            .toList(),
        'frameworksTitle': 'Tech Stack',
      });

      // 2. Save Selected Projects
      // Clear old first? Assuming overwrite for now based on user intent
      final oldProjects = await _firestoreService.streamProjects().first;
      for (var doc in oldProjects.docs) {
        await FirestoreService().deleteProject(doc.id);
      }

      for (var p in _extractedProjects) {
        await _firestoreService.addProject(p);
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Portfolio Updated!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _removeProject(int index) {
    setState(() {
      _extractedProjects.removeAt(index);
    });
  }

  void _editProject(int index) {
    final project = _extractedProjects[index];
    final titleCtrl = TextEditingController(text: project['title']);
    final descCtrl = TextEditingController(text: project['description']);
    final stackCtrl =
        TextEditingController(text: (project['techStack'] as List).join(', '));

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Edit Project'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Title')),
                    const SizedBox(height: 8),
                    TextField(
                        controller: descCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                        maxLines: 3),
                    const SizedBox(height: 8),
                    TextField(
                        controller: stackCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Tech Stack (comma sep)')),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _extractedProjects[index] = {
                          ...project,
                          'title': titleCtrl.text,
                          'description': descCtrl.text,
                          'techStack': stackCtrl.text
                              .split(',')
                              .map((e) => e.trim())
                              .toList(),
                        };
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_hasParsed ? 'Review & Save' : 'Auto-fill Resume'),
        actions: _hasParsed
            ? [
                IconButton(
                    onPressed: _saveToFirestore, icon: const Icon(Icons.check))
              ]
            : [],
      ),
      floatingActionButton: _hasParsed
          ? FloatingActionButton.extended(
              onPressed: _saveToFirestore,
              label: const Text('Save to Portfolio'),
              icon: const Icon(Icons.save),
            )
          : null,
      body: _isLoading
          ? Center(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [const CircularProgressIndicator(), Text(_status)]))
          : _hasParsed
              ? _buildReviewList()
              : _buildUploadView(),
    );
  }

  Widget _buildUploadView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.upload_file, size: 80, color: Colors.blueGrey),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Upload your PDF resume.\nWe will extract your info and projects.\nYou can review them before saving.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: _pickAndParseResume,
            icon: const Icon(Icons.folder_open),
            label: const Text('Select Key Resume PDF'),
            style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        const Text('Profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: Text(_extractedProfile['name']),
            subtitle: Text(
                "${_extractedProfile['email']}\n${_extractedProfile['bio']}",
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            isThreeLine: true,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Projects Found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${_extractedProjects.length} items',
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        if (_extractedProjects.isEmpty)
          const Padding(
              padding: EdgeInsets.all(16),
              child:
                  Text("No projects found. Try checking your resume format.")),
        ..._extractedProjects.asMap().entries.map((entry) {
          final index = entry.key;
          final project = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(project['title'],
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project['description'],
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: (project['techStack'] as List)
                        .map<Widget>((t) => Chip(
                            label:
                                Text(t, style: const TextStyle(fontSize: 10)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact))
                        .toList(),
                  )
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editProject(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeProject(index),
                  ),
                ],
              ),
            ),
          );
        }).toList()
      ],
    );
  }
}
