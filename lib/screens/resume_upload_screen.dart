import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../services/cloudinary_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/gradient_card.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/action_dialog.dart';

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
  String? _pickedFilePath;

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
        _pickedFilePath = path;
        setState(() => _status = 'Reading PDF Content...');
        final String text = await _extractTextFromPdf(path);

        setState(() => _status = 'Analyzing Experience...');
        _analyzeData(text);

        setState(() {
          _isLoading = false;
          _hasParsed = true;
        });
      } else {
        _pickedFilePath = null;
        setState(() {
          _status = '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            title: Text('Error',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            content: Text(e.toString(),
                style: GoogleFonts.inter(color: AppTheme.textSecondary)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK',
                    style: TextStyle(color: AppTheme.primaryColor)),
              ),
            ],
          ),
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

    final linkedinRegex =
        RegExp(r'linkedin\.com/in/[\w-]+', caseSensitive: false);
    final linkedin = linkedinRegex.firstMatch(text)?.group(0) ?? '';

    final githubRegex = RegExp(r'github\.com/[\w-]+', caseSensitive: false);
    final github = githubRegex.firstMatch(text)?.group(0) ?? '';

    _extractedProfile = {
      'name': name,
      'email': email,
      'bio': bio,
      'skills': foundSkills,
      'linkedin': linkedin.isNotEmpty ? "https://$linkedin" : "",
      'github': github.isNotEmpty ? "https://$github" : "",
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
      String block = match.group(0) ?? '';
      String title = match.group(1)?.replaceAll('\n', ' ').trim() ?? 'Untitled';
      String environment = match.group(2)?.replaceAll('\n', ' ').trim() ?? '';
      String rawDescription = match.group(3)?.trim() ?? '';

      // Extract Role if present in the block
      String role = "Software Engineer";
      final roleMatch =
          RegExp(r'Role:\s*([^\n]+)', caseSensitive: false).firstMatch(block);
      if (roleMatch != null) {
        role = roleMatch.group(1)!.trim();
      }

      // 1. Separate Short Description vs Full Narrative
      String description = "";
      String fullDescription = rawDescription;

      // If there's a clear "Roles and Responsibilities" or bullet section
      final parts = rawDescription
          .split(RegExp(r'Roles and Responsibilities:', caseSensitive: false));
      if (parts.length > 1) {
        description = parts[0].trim();
        fullDescription =
            parts[0].trim() + "\n\nKey Responsibilities:\n" + parts[1].trim();
      } else {
        // Heuristic: First 2 sentences as short description
        final sentences = rawDescription.split(RegExp(r'(?<=\. )'));
        if (sentences.isNotEmpty) {
          description = sentences.take(2).join(' ').trim();
          if (description.length > 150) {
            description = description.substring(0, 147) + '...';
          }
        } else {
          description = rawDescription;
        }
      }

      // Clean up description formatting
      description = description
          .replaceAll(RegExp(r'^\s*[-·•]\s*', multiLine: true), '')
          .replaceAll(RegExp(r'\n+'), ' ')
          .trim();

      // Split environment into tech stack
      List<String> stack = environment
          .split(RegExp(r'[,\n]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && e.length < 30)
          .toList();

      if (stack.isEmpty) stack = ['Engineering'];

      projects.add({
        'title': title,
        'role': role,
        'description': description,
        'fullDescription': fullDescription,
        'techStack': stack,
        'category': 'Professional Work',
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
      if (!projects.any((p) =>
          p['title'].toLowerCase().contains(potentialTitle.toLowerCase()) ||
          potentialTitle.toLowerCase().contains(p['title'].toLowerCase()))) {
        if (block.toLowerCase().contains('title:') ||
            block.toLowerCase().contains('project')) {
          if (potentialTitle.length < 50 &&
              !potentialTitle.toLowerCase().contains('experience')) {
            String blockText = lines.length > 1
                ? lines.sublist(1).join(' ').trim()
                : block.trim();

            projects.add({
              'title': potentialTitle,
              'role': 'Developer',
              'description': blockText.length > 150
                  ? blockText.substring(0, 147) + '...'
                  : blockText,
              'fullDescription': blockText,
              'techStack': knownSkills
                  .where((s) => block.toLowerCase().contains(s.toLowerCase()))
                  .toList(),
              'category': 'Selected Project',
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
      final linkedin = _extractedProfile['linkedin'] ?? '';
      final github = _extractedProfile['github'] ?? '';
      final skills = List<String>.from(_extractedProfile['skills'] ?? []);
      final role = _extractedProfile['role'] ?? 'Software Engineer';

      if (_pickedFilePath != null) {
        setState(() => _status = "Uploading Resume PDF...");
        final url = await CloudinaryService().uploadPdf(_pickedFilePath!);
        if (url != null) {
          print("UPLOADED SUCCESS: $url");
          _extractedProfile['resumeUrl'] = url;
        } else {
          print("UPLOAD RETURNED NULL");
        }
      } else {
        print("PICKED FILE PATH IS NULL");
      }

      await _firestoreService.updateContent('hero', {
        'title': "HI, I'M ${name.toUpperCase()}",
        'subtitle': role,
        'badge': "Available for Work",
      });

      Map<String, dynamic> contactData = {};
      if (email.isNotEmpty) contactData['email'] = email;
      if (_extractedProfile['resumeUrl'] != null) {
        contactData['resumeUrl'] = _extractedProfile['resumeUrl'];
      }
      if (contactData.isNotEmpty) {
        print("UPDATING CONTACT WITH: $contactData");
        await _firestoreService.updateContent('contact', contactData);
      } else {
        print("NO CONTACT DATA TO UPDATE");
      }

      List<Map<String, String>> socialLinks = [];
      if (linkedin.isNotEmpty) {
        socialLinks.add({'platform': 'linkedin', 'url': linkedin});
      }
      if (github.isNotEmpty) {
        socialLinks.add({'platform': 'github', 'url': github});
      }

      // Add moreLinks if they exist
      final List<Map<String, dynamic>>? moreLinks =
          _extractedProfile['moreLinks'] != null
              ? List<Map<String, dynamic>>.from(_extractedProfile['moreLinks'])
              : null;
      if (moreLinks != null) {
        for (var link in moreLinks) {
          socialLinks.add({
            'platform': link['platform'].toString(),
            'url': link['url'].toString()
          });
        }
      }

      // Update about profile including social links
      Map<String, dynamic> aboutUpdate = {
        'biography': _extractedProfile['bio'] ?? '',
      };
      if (socialLinks.isNotEmpty) {
        aboutUpdate['socialLinks'] = socialLinks;
      }
      await _firestoreService.updateContent('about', aboutUpdate);

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
        ActionDialog.show(
          context,
          title: "Success",
          message:
              "Your portfolio has been synchronized with your resume data!",
          onConfirm: () => Navigator.pop(context),
        );
      }
    } catch (e) {
      if (mounted) {
        ActionDialog.show(
          context,
          title: "Save Error",
          message: e.toString(),
          type: ActionDialogType.danger,
          onConfirm: () {},
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _editProject(int index) {
    final project = _extractedProjects[index];
    final titleCtrl = TextEditingController(text: project['title']);
    final roleCtrl =
        TextEditingController(text: project['role'] ?? 'Developer');
    final descCtrl = TextEditingController(text: project['description']);
    final fullDescCtrl =
        TextEditingController(text: project['fullDescription']);
    final techCtrl =
        TextEditingController(text: (project['techStack'] as List).join(', '));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text("Edit Extracted Project",
            style: GoogleFonts.outfit(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(label: "TITLE", controller: titleCtrl),
              const SizedBox(height: 16),
              CustomTextField(label: "ROLE", controller: roleCtrl),
              const SizedBox(height: 16),
              CustomTextField(
                  label: "SHORT SUMMARY",
                  controller: descCtrl,
                  isMultiline: true),
              const SizedBox(height: 16),
              CustomTextField(
                  label: "FULL DESCRIPTION (DEEP DIVE)",
                  controller: fullDescCtrl,
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
                  'role': roleCtrl.text,
                  'description': descCtrl.text,
                  'fullDescription': fullDescCtrl.text,
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

  void _editProfile() {
    final nameCtrl = TextEditingController(text: _extractedProfile['name']);
    final bioCtrl = TextEditingController(text: _extractedProfile['bio']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text("Edit Profile",
            style: GoogleFonts.outfit(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(label: "NAME", controller: nameCtrl),
              const SizedBox(height: 16),
              CustomTextField(
                  label: "BIO", controller: bioCtrl, isMultiline: true),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              setState(() {
                _extractedProfile['name'] = nameCtrl.text;
                _extractedProfile['bio'] = bioCtrl.text;
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

  void _editSocialLinks() {
    final lnCtrl = TextEditingController(text: _extractedProfile['linkedin']);
    final ghCtrl = TextEditingController(text: _extractedProfile['github']);

    // Add provision for more links
    final List<Map<String, dynamic>> moreLinks =
        List.from(_extractedProfile['moreLinks'] ?? []);
    final List<TextEditingController> platformCtrls = moreLinks
        .map((e) => TextEditingController(text: e['platform']))
        .toList();
    final List<TextEditingController> urlCtrls =
        moreLinks.map((e) => TextEditingController(text: e['url'])).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text("Edit Social Links",
              style: GoogleFonts.outfit(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(label: "LINKEDIN URL", controller: lnCtrl),
                const SizedBox(height: 16),
                CustomTextField(label: "GITHUB URL", controller: ghCtrl),
                const Divider(height: 32, color: Colors.white10),
                Text("ADDITIONAL LINKS",
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor)),
                const SizedBox(height: 8),
                ...List.generate(
                    platformCtrls.length,
                    (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                  flex: 2,
                                  child: CustomTextField(
                                      label: "PLATFORM",
                                      controller: platformCtrls[index])),
                              const SizedBox(width: 8),
                              Expanded(
                                  flex: 3,
                                  child: CustomTextField(
                                      label: "URL",
                                      controller: urlCtrls[index])),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  setDialogState(() {
                                    platformCtrls.removeAt(index);
                                    urlCtrls.removeAt(index);
                                  });
                                },
                              )
                            ],
                          ),
                        )),
                TextButton.icon(
                  onPressed: () {
                    setDialogState(() {
                      platformCtrls.add(TextEditingController());
                      urlCtrls.add(TextEditingController());
                    });
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("ADD LINK"),
                )
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel")),
            TextButton(
              onPressed: () {
                setState(() {
                  _extractedProfile['linkedin'] = lnCtrl.text;
                  _extractedProfile['github'] = ghCtrl.text;

                  List<Map<String, String>> savedMoreLinks = [];
                  for (int i = 0; i < platformCtrls.length; i++) {
                    if (platformCtrls[i].text.isNotEmpty &&
                        urlCtrls[i].text.isNotEmpty) {
                      savedMoreLinks.add({
                        'platform': platformCtrls[i].text.toLowerCase(),
                        'url': urlCtrls[i].text
                      });
                    }
                  }
                  _extractedProfile['moreLinks'] = savedMoreLinks;
                });
                Navigator.pop(ctx);
              },
              child: const Text("Save",
                  style: TextStyle(color: AppTheme.primaryColor)),
            )
          ],
        ),
      ),
    );
  }

  void _editSkills() {
    final skills = List<String>.from(_extractedProfile['skills'] ?? []);
    final skillsCtrl = TextEditingController(text: skills.join(', '));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text("Edit Extracted Skills",
            style: GoogleFonts.outfit(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                label: "SKILLS (Comma separated)",
                controller: skillsCtrl,
                isMultiline: true,
              )
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
                _extractedProfile['skills'] = skillsCtrl.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty && e.length < 50)
                    .toList();
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
    return PopScope(
      canPop: !_hasParsed || _isLoading,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop = await ActionDialog.show(
          context,
          title: "Stop Review?",
          message:
              "You have extracted data that hasn't been saved yet. Are you sure you want to discard the results?",
          confirmLabel: "DISCARD",
          type: ActionDialogType.warning,
          onConfirm: () {},
        );

        if (shouldPop == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
                    const CircularProgressIndicator(
                        color: AppTheme.primaryColor),
                    const SizedBox(height: 24),
                    Text(_status,
                        style:
                            GoogleFonts.inter(color: AppTheme.textSecondary)),
                  ],
                ),
              )
            : !_hasParsed
                ? _buildUploadView()
                : _buildReviewView(),
      ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionHeader(title: "EXTRACTED PROFILE"),
            IconButton(
              icon:
                  const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
              onPressed: _editProfile,
            ),
          ],
        ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionHeader(title: "SOCIAL LINKS"),
            IconButton(
              icon:
                  const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
              onPressed: _editSocialLinks,
            ),
          ],
        ),
        GradientCard(
            child: Column(
          children: [
            if (_extractedProfile['linkedin'] != null &&
                _extractedProfile['linkedin'].isNotEmpty)
              _InfoRow(icon: Icons.link, value: _extractedProfile['linkedin']),
            if (_extractedProfile['github'] != null &&
                _extractedProfile['github'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _InfoRow(
                    icon: Icons.code, value: _extractedProfile['github']),
              ),
            ...(_extractedProfile['moreLinks'] as List<Map<String, String>>? ??
                    [])
                .map((link) => Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _InfoRow(
                          icon: Icons.alternate_email,
                          value:
                              "${link['platform']?.toUpperCase()}: ${link['url']}"),
                    )),
            if ((_extractedProfile['linkedin'] == null ||
                    _extractedProfile['linkedin'].isEmpty) &&
                (_extractedProfile['github'] == null ||
                    _extractedProfile['github'].isEmpty) &&
                (_extractedProfile['moreLinks'] == null ||
                    (_extractedProfile['moreLinks'] as List).isEmpty))
              Text("No social links found. Tap edit to add.",
                  style: GoogleFonts.inter(
                      color: AppTheme.textSecondary, fontSize: 13)),
          ],
        )),
        const SizedBox(height: 24),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionHeader(title: "EXTRACTED SKILLS"),
            IconButton(
              icon:
                  const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
              onPressed: _editSkills,
            ),
          ],
        ),
        GradientCard(
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (_extractedProfile['skills'] as List<dynamic>? ?? [])
                  .map((s) => Chip(
                        label: Text(s.toString(),
                            style: GoogleFonts.inter(fontSize: 12)),
                        backgroundColor: AppTheme.inputFillColor,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        labelStyle: const TextStyle(color: Colors.white),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ))
                  .toList(),
            ),
          ),
        ),
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
                        const SizedBox(height: 4),
                        Text(p['role'] ?? 'Developer',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 12),
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
