import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/resume_data.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import '../services/resume_parser_service.dart';
import '../theme/app_theme.dart';
import '../widgets/action_dialog.dart';
import '../widgets/primary_button.dart';

// ─── Progress Step Model ──────────────────────────────────────────────────────

class _ProgressStep {
  final String label;
  final String detail;
  final IconData icon;
  final double targetPercent;

  const _ProgressStep({
    required this.label,
    required this.detail,
    required this.icon,
    required this.targetPercent,
  });
}

const List<_ProgressStep> _steps = [
  _ProgressStep(
    label: 'Reading PDF',
    detail: 'Extracting text from your resume...',
    icon: Icons.picture_as_pdf_outlined,
    targetPercent: 0.10,
  ),
  _ProgressStep(
    label: 'Studying Profile',
    detail: 'AI is deeply analysing your career, projects & skills...',
    icon: Icons.psychology_outlined,
    targetPercent: 0.45,
  ),
  _ProgressStep(
    label: 'Extracting Data',
    detail: 'Structuring your portfolio data from AI analysis...',
    icon: Icons.data_object_outlined,
    targetPercent: 0.75,
  ),
  _ProgressStep(
    label: 'Saving Data',
    detail: 'Uploading PDF & writing all sections to database...',
    icon: Icons.cloud_upload_outlined,
    targetPercent: 0.95,
  ),
  _ProgressStep(
    label: 'Complete!',
    detail: 'Your portfolio has been fully updated.',
    icon: Icons.check_circle_outline,
    targetPercent: 1.0,
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class ResumeUploadScreen extends StatefulWidget {
  const ResumeUploadScreen({super.key});

  @override
  State<ResumeUploadScreen> createState() => _ResumeUploadScreenState();
}

class _ResumeUploadScreenState extends State<ResumeUploadScreen> {
  static String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? "";

  bool _isLoading = false;
  bool _isParsing = false;
  ResumeData? _parsedData;
  File? _selectedFile;

  // Progress state
  int _currentStep = 0;
  double _progress = 0.0;

  void _advanceToStep(int step) {
    if (!mounted) return;
    setState(() {
      _currentStep = step;
      _progress = _steps[step].targetPercent;
    });
  }

  // ─── Pick Resume ─────────────────────────────────────────────────────────────

  Future<void> _pickResume() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _parsedData = null;
          _currentStep = 0;
          _progress = 0.0;
        });
      }
    } catch (e) {
      if (mounted) {
        ActionDialog.show(context,
            title: "Error",
            message: "Could not select file: $e",
            type: ActionDialogType.danger,
            onConfirm: () {});
      }
    }
  }

  // ─── Parse Resume ─────────────────────────────────────────────────────────────

  Future<void> _parseResume() async {
    if (_selectedFile == null) return;

    setState(() {
      _isParsing = true;
      _currentStep = 0;
      _progress = 0.0;
    });

    try {
      // Step 0 — Read PDF
      _advanceToStep(0);
      final bytes = await _selectedFile!.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final String text = PdfTextExtractor(document).extractText();
      document.dispose();

      if (text.isEmpty) {
        throw Exception(
            "Could not extract text from the PDF. It might be an image scan.");
      }

      // Step 1 — Phase 1: AI studies profile
      _advanceToStep(1);
      final parser = GeminiResumeParser(apiKey: _geminiApiKey);

      // Advance to step 2 after ~8s (approximate phase 1 duration)
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && _isParsing && _currentStep == 1) {
          _advanceToStep(2);
        }
      });

      final data = await parser.parseResume(text);

      // Ensure step 2 is shown after parse completes
      _advanceToStep(2);

      setState(() {
        _parsedData = data;
        _isParsing = false;
      });
    } catch (e) {
      setState(() {
        _isParsing = false;
        _progress = 0.0;
        _currentStep = 0;
      });
      if (mounted) {
        ActionDialog.show(context,
            title: "Parsing Failed",
            message: e.toString(),
            type: ActionDialogType.danger,
            onConfirm: () {});
      }
    }
  }

  // ─── Apply Data ───────────────────────────────────────────────────────────────

  Future<void> _applyData() async {
    if (_parsedData == null) return;

    final shouldApply = await ActionDialog.show(
      context,
      title: "Apply Changes?",
      message:
          "This will overwrite Hero, About, Skills, Expertise sections and add new Projects from your resume. Proceed?",
      confirmLabel: "APPLY ALL",
      type: ActionDialogType.warning,
      onConfirm: () {},
    );

    if (shouldApply != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final firestore = FirestoreService();
      String? pdfUrl;

      // Step 3 — Upload + Save
      _advanceToStep(3);

      if (_selectedFile != null) {
        pdfUrl = await CloudinaryService().uploadPdf(_selectedFile!.path);
      }

      // Personal
      if (_parsedData!.name.isNotEmpty || _parsedData!.role.isNotEmpty) {
        await firestore.updateContent('personal', {
          if (_parsedData!.name.isNotEmpty) 'name': _parsedData!.name,
          if (_parsedData!.role.isNotEmpty) 'role': _parsedData!.role,
        });
      }

      // Hero
      if (_parsedData!.hero.isNotEmpty) {
        await firestore.updateContent('hero', _parsedData!.hero);
      }

      // About
      final Map<String, dynamic> aboutData = {
        if (_parsedData!.summary.isNotEmpty) 'biography': _parsedData!.summary,
        if (_parsedData!.location.isNotEmpty) 'location': _parsedData!.location,
        'education': _parsedData!.education.map((e) => e.toMap()).toList(),
        'experience': _parsedData!.experience.map((e) => e.toMap()).toList(),
      };
      if (_parsedData!.about.isNotEmpty) {
        aboutData.addAll(_parsedData!.about);
      }
      if (pdfUrl != null) {
        aboutData['resumeUrl'] = pdfUrl;
      }
      await firestore.updateContent('about', aboutData);

      // Expertise
      if (_parsedData!.expertise.isNotEmpty) {
        await firestore.updateContent('expertise', _parsedData!.expertise);
      }

      // Skills
      if (_parsedData!.skills.isNotEmpty) {
        await firestore.updateContent('skills', _parsedData!.skills);
      }

      // Contact
      final Map<String, dynamic> contactData = {};
      if (_parsedData!.email.isNotEmpty) {
        contactData['email'] = _parsedData!.email;
      }
      if (_parsedData!.personalEmail.isNotEmpty) {
        contactData['personalEmail'] = _parsedData!.personalEmail;
      }
      if (contactData.isNotEmpty) {
        await firestore.updateContent('contact', contactData);
      }

      // Projects
      for (final project in _parsedData!.projects) {
        await firestore.addProject(project.toMap());
      }

      // Step 4 — Done
      _advanceToStep(4);
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedFile = null;
          _parsedData = null;
          _progress = 0.0;
          _currentStep = 0;
        });

        ActionDialog.show(
          context,
          title: "Success! 🚀",
          message:
              "Resume uploaded! Hero, About, Skills, Expertise & Projects all updated.",
          onConfirm: () => Navigator.pop(context),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ActionDialog.show(context,
            title: "Save Failed",
            message: e.toString(),
            type: ActionDialogType.danger,
            onConfirm: () {});
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool showProgress = _isParsing || _isLoading;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("RESUME PARSER",
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            _buildUploadSection(),
            if (showProgress) ...[
              const SizedBox(height: 40),
              _buildProgressCard(),
            ],
            if (_parsedData != null && !showProgress) _buildPreviewSection(),
          ],
        ),
      ),
    );
  }

  // ─── Progress Card ────────────────────────────────────────────────────────────

  Widget _buildProgressCard() {
    final step = _steps[_currentStep];
    final int percent = (_progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(step.icon, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.label,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.detail,
                      style: GoogleFonts.inter(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: GoogleFonts.outfit(
                  color: AppTheme.primaryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Animated progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOut,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: Colors.white10,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Step indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_steps.length, (i) {
              final bool done = i < _currentStep;
              final bool active = i == _currentStep;
              return Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? AppTheme.primaryColor
                            : active
                                ? AppTheme.primaryColor.withValues(alpha: 0.3)
                                : Colors.white10,
                        border: Border.all(
                          color: done || active
                              ? AppTheme.primaryColor
                              : Colors.white12,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: done
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.black)
                            : active
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryColor,
                                    ),
                                  )
                                : Text(
                                    '${i + 1}',
                                    style: GoogleFonts.outfit(
                                        color: Colors.white38, fontSize: 11),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _steps[i].label.split(' ').first,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: done || active ? Colors.white70 : Colors.white24,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),

          const SizedBox(height: 20),

          // Tip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white38, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentStep <= 1
                        ? "AI is reading every word of your resume. This takes 15–30 seconds."
                        : _currentStep == 2
                            ? "Structuring your data. Almost there..."
                            : "Writing to Firestore. Do not close the app.",
                    style:
                        GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Upload Section ───────────────────────────────────────────────────────────

  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Upload Resume",
            style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 16),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: InkWell(
            onTap: _pickResume,
            borderRadius: BorderRadius.circular(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedFile == null
                        ? Icons.cloud_upload_outlined
                        : Icons.description_outlined,
                    size: 48,
                    color: _selectedFile == null
                        ? Colors.white24
                        : AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFile == null
                        ? "Tap to select PDF Resume"
                        : _selectedFile!.path.split('/').last,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: _selectedFile == null
                          ? AppTheme.textSecondary
                          : Colors.white,
                      fontWeight: _selectedFile == null
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          text: "ANALYZE RESUME",
          onPressed:
              _selectedFile != null && !_isParsing ? _parseResume : () {},
          isLoading: _isParsing,
          icon: Icons.auto_awesome,
        ),
      ],
    );
  }

  // ─── Preview Section ──────────────────────────────────────────────────────────

  Widget _buildPreviewSection() {
    final data = _parsedData!;
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: AppTheme.successColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text("Analysis Complete",
                    style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoCard("Personal", [
            "Name: ${data.name}",
            "Email: ${data.email}",
            "Role: ${data.role}",
            "Summary: ${data.summary.substring(0, data.summary.length > 80 ? 80 : data.summary.length)}...",
          ]),
          const SizedBox(height: 16),
          _buildInfoCard("Experience", [
            "Jobs Found: ${data.experience.length}",
            ...data.experience.map((e) => "• ${e.position} at ${e.company}")
          ]),
          const SizedBox(height: 16),
          _buildInfoCard("Projects", [
            "Projects Found: ${data.projects.length}",
            ...data.projects
                .map((e) => "• ${e.title} (${e.techStack.length} tech tags)")
          ]),
          const SizedBox(height: 16),
          _buildInfoCard("Skills", [
            "Categories Found: ${data.skills.length}",
            if ((data.skills['frontend'] as List?)?.isNotEmpty == true)
              "• Frontend: ${(data.skills['frontend'] as List).length} skills",
            if ((data.skills['mobile'] as List?)?.isNotEmpty == true)
              "• Mobile: ${(data.skills['mobile'] as List).length} skills",
            if ((data.skills['backend'] as List?)?.isNotEmpty == true)
              "• Backend: ${(data.skills['backend'] as List).length} skills",
          ]),
          const SizedBox(height: 48),
          PrimaryButton(
            text: "APPLY DATA TO PORTFOLIO",
            onPressed: _isLoading ? () {} : _applyData,
            isLoading: _isLoading,
            icon: Icons.save_alt,
          ),
          const SizedBox(height: 16),
          Center(
              child: Text("This will update your database instantly.",
                  style:
                      GoogleFonts.inter(fontSize: 12, color: Colors.white38))),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<String> lines) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.inputFillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          const SizedBox(height: 12),
          ...lines.map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line,
                    style:
                        GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
              )),
        ],
      ),
    );
  }
}
