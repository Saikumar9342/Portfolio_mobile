import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/gradient_card.dart';
import '../widgets/custom_text_field.dart';

class ResumeUploadScreen extends StatefulWidget {
  const ResumeUploadScreen({super.key});

  @override
  State<ResumeUploadScreen> createState() => _ResumeUploadScreenState();
}

class _ResumeUploadScreenState extends State<ResumeUploadScreen> {
  bool _isLoading = false;
  String _status = '';
  final FirestoreService _firestoreService = FirestoreService();

  List<Map<String, dynamic>> _extractedProjects = [];
  Map<String, dynamic> _extractedProfile = {};
  bool _hasParsed = false;

  Future<void> _pickAndParseResume() async {
    setState(() {
      _isLoading = true;
      _status = 'Selecting PDF...';
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        String path = result.files.single.path!;
        setState(() => _status = 'Reading PDF Content...');
        final String text = await _extractTextFromPdf(path);

        setState(() => _status = 'Analyzing Experience...');
        _analyzeData(text);

        setState(() {
          _isLoading = false;
          _hasParsed = true;
        });
      } else {
        setState(() {
          _status = '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
      setState(() {
        _status = '';
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
    // 1. Basic Info
    final emailRegex = RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w{2,4}\b');
    final email = emailRegex.firstMatch(text)?.group(0) ?? '';

    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    String name = lines.isNotEmpty ? lines.first.trim() : 'Unknown';
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
      'MongoDB',
      'PostgreSQL'
    ];

    final foundSkills = knownSkills
        .where((s) => text.toLowerCase().contains(s.toLowerCase()))
        .toSet() // Unique
        .toList();

    String bio =
        "Software Developer based in ${lines.length > 2 ? lines[2].split(',').last : 'World'}.";
    // Improved Bio Regex
    final bioMatch = RegExp(r'(?<=Profile|Summary\s)([\s\S]{50,300})(?=\n)',
            caseSensitive: false)
        .firstMatch(text);
    if (bioMatch != null) {
      bio = bioMatch.group(1)?.replaceAll('\n', ' ').trim() ?? bio;
    }

    _extractedProfile = {
      'name': name,
      'email': email,
      'bio': bio,
      'skills': foundSkills,
    };

    // 2. Projects
    _extractedProjects = _extractProjects(text, knownSkills);
  }

  List<Map<String, dynamic>> _extractProjects(
      String text, List<String> knownSkills) {
    List<Map<String, dynamic>> projects = [];
    String cleanText = text.replaceAll('\r\n', '\n');

    // Robust regex with better boundary detection
    final projectRegex = RegExp(
      r'Title:\s*([\s\S]+?)\s*Environment:\s*([\s\S]+?)\s*Description:\s*([\s\S]+?)(?=Roles and Responsibilities:|Title:|@\s+Finsol:|$)',
      caseSensitive: false,
    );

    final matches = projectRegex.allMatches(cleanText);

    for (final match in matches) {
      String title = match.group(1)?.replaceAll('\n', ' ').trim() ?? 'Untitled';
      String environment = match.group(2)?.replaceAll('\n', ' ').trim() ?? '';
      String description = match.group(3)?.trim() ?? '';

      // Clean up description
      description = description
          .replaceAll(RegExp(r'^\s*[-·•]\s*', multiLine: true), '')
          .trim();
      description = description.replaceAll(RegExp(r'\n+'), ' ');

      // Split environment into tech stack
      List<String> stack = environment
          .split(RegExp(r'[,\n]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && e.length < 30)
          .toList();

      if (stack.isEmpty) stack = ['Software Engineering'];

      projects.add({
        'title': title,
        'description': description,
        'techStack': stack,
        'imageUrl': '',
        'liveLink': '',
        'githubLink': '',
      });
    }

    // Supplemental logic: Fill any gaps from blocks
    final blocks = cleanText.split(RegExp(r'\n\s*\n'));
    for (var block in blocks) {
      if (block.length < 50) continue;
      final lines =
          block.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) continue;

      String potentialTitle = lines.first.trim();
      // Only supplemental if not already found
      if (!projects.any((p) =>
          p['title'].toLowerCase().contains(potentialTitle.toLowerCase()) ||
          potentialTitle.toLowerCase().contains(p['title'].toLowerCase()))) {
        if (block.toLowerCase().contains('title:') ||
            block.toLowerCase().contains('project')) {
          if (potentialTitle.length < 50 &&
              !potentialTitle.toLowerCase().contains('experience')) {
            projects.add({
              'title': potentialTitle,
              'description': lines.length > 1
                  ? lines.sublist(1).join(' ').trim()
                  : block.trim(),
              'techStack': knownSkills
                  .where((s) => block.toLowerCase().contains(s.toLowerCase()))
                  .toList(),
              'imageUrl': '',
              'liveLink': '',
              'githubLink': '',
            });
          }
        }
      }
    }

    return projects;
  }

  Future<void> _saveToFirestore() async {
    setState(() => _isLoading = true);
    try {
      // Logic same as before...
      final name = _extractedProfile['name'];
      final email = _extractedProfile['email'] ?? '';
      final skills = List<String>.from(_extractedProfile['skills'] ?? []);
      final role = _extractedProfile['role'] ?? 'Software Engineer';

      await _firestoreService.updateContent('hero', {
        'title': "HI, I'M ${name.toUpperCase()}",
        'subtitle': role,
        'badge': "Available for Work",
      });

      if (email.isNotEmpty) {
        await _firestoreService.updateContent('contact', {'email': email});
      }

      // Update about profile too
      await _firestoreService.updateContent('about', {
        'biography': _extractedProfile['bio'] ?? '',
      });

      // Add skills to skills section
      if (skills.isNotEmpty) {
        await _firestoreService.updateContent('skills', {
          'frameworks': skills,
        });
      }

      // Check if user wants to replace projects...
      for (var p in _extractedProjects) {
        await _firestoreService.addProject(p);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Portfolio updated successfully!'),
            backgroundColor: AppTheme.primaryColor));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _editProject(int index) {
    final project = _extractedProjects[index];
    final titleCtrl = TextEditingController(text: project['title']);
    final descCtrl = TextEditingController(text: project['description']);
    final techCtrl =
        TextEditingController(text: (project['techStack'] as List).join(', '));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text("Edit Project",
            style: GoogleFonts.outfit(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(label: "TITLE", controller: titleCtrl),
              const SizedBox(height: 16),
              CustomTextField(
                  label: "DESCRIPTION",
                  controller: descCtrl,
                  isMultiline: true),
              const SizedBox(height: 16),
              CustomTextField(
                  label: "TECH STACK (Comma separated)", controller: techCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _extractedProjects[index] = {
                  ..._extractedProjects[index],
                  'title': titleCtrl.text,
                  'description': descCtrl.text,
                  'techStack': techCtrl.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                };
              });
              Navigator.pop(ctx);
            },
            child: const Text("Save",
                style: TextStyle(color: AppTheme.primaryColor)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_hasParsed ? 'Review Data' : 'Upload Resume',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.scaffoldBackgroundColor,
      ),
      bottomNavigationBar: _hasParsed && !_isLoading
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: PrimaryButton(
                  text: "SAVE TO PORTFOLIO", onPressed: _saveToFirestore),
            )
          : null,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primaryColor),
                  const SizedBox(height: 24),
                  Text(_status,
                      style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : !_hasParsed
              ? _buildUploadView()
              : _buildReviewView(),
    );
  }

  Widget _buildUploadView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_upload_outlined,
                    size: 64, color: AppTheme.primaryColor)),
            const SizedBox(height: 32),
            Text(
              "Import from Resume",
              style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              "Upload your PDF resume to automatically populate your portfolio content.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 16, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 48),
            PrimaryButton(
              text: "SELECT PDF FILE",
              onPressed: _pickAndParseResume,
              icon: Icons.folder_open,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionHeader(title: "EXTRACTED PROFILE"),
        GradientCard(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(icon: Icons.person, value: _extractedProfile['name']),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.email, value: _extractedProfile['email']),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.info_outline, value: _extractedProfile['bio']),
          ],
        )),
        const SizedBox(height: 24),
        _SectionHeader(title: "PROJECTS (${_extractedProjects.length})"),
        ..._extractedProjects.asMap().entries.map((entry) {
          final index = entry.key;
          final p = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Stack(
              children: [
                GradientCard(
                    padding: const EdgeInsets.only(
                        top: 24, bottom: 20, left: 20, right: 60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['title'],
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 8),
                        Text(p['description'],
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                height: 1.4)),
                        const SizedBox(height: 16),
                        Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (p['techStack'] as List)
                                .map<Widget>((t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        border:
                                            Border.all(color: Colors.white10),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Text(t,
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w500))))
                                .toList())
                      ],
                    )),
                Positioned(
                    right: 12,
                    top: 12,
                    child: Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: AppTheme.primaryColor, size: 22),
                          onPressed: () => _editProject(index),
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppTheme.errorColor, size: 22),
                          onPressed: () => setState(
                              () => _extractedProjects.removeAt(index)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ))
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title,
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              letterSpacing: 1.0)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String value;
  const _InfoRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Expanded(
            child: Text(value,
                style: GoogleFonts.inter(color: AppTheme.textPrimary)))
      ],
    );
  }
}
