import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/resume_data.dart';
import '../services/firestore_service.dart';
import '../services/resume_parser_service.dart';

import '../services/cloudinary_service.dart';
import '../theme/app_theme.dart';
import '../widgets/action_dialog.dart';

import '../widgets/primary_button.dart';

class ResumeUploadScreen extends StatefulWidget {
  const ResumeUploadScreen({super.key});

  @override
  State<ResumeUploadScreen> createState() => _ResumeUploadScreenState();
}

class _ResumeUploadScreenState extends State<ResumeUploadScreen> {
  // Gemini API Key — read lazily so dotenv is already loaded
  static String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? "";
  bool _isLoading = false;
  bool _isParsing = false;
  String _statusMessage = "";
  ResumeData? _parsedData;
  File? _selectedFile;

  Future<void> _pickResume() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _parsedData = null; // Reset previous parse
        });
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
      if (mounted) {
        ActionDialog.show(
          context,
          title: "Error",
          message: "Could not select file: $e",
          type: ActionDialogType.danger,
          onConfirm: () {},
        );
      }
    }
  }

  Future<void> _parseResume() async {
    if (_selectedFile == null) return;

    setState(() {
      _isParsing = true;
      _statusMessage = "Extracting text from PDF...";
    });

    try {
      // 1. Extract Text
      final bytes = await _selectedFile!.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      String text = PdfTextExtractor(document).extractText();
      document.dispose();

      if (text.isEmpty) {
        throw Exception(
            "Could not extract any text from the PDF. It might be an image scan.");
      }

      // 2. Send to AI
      setState(() {
        _statusMessage = "Phase 1: Studying your profile...";
      });

      final parser = GeminiResumeParser(apiKey: _geminiApiKey);

      // Update message mid-way (approximate — actual phase change is in the service)
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted && _isParsing) {
          setState(
              () => _statusMessage = "Phase 2: Extracting portfolio data...");
        }
      });
      final data = await parser.parseResume(text);

      setState(() {
        _parsedData = data;
        _isParsing = false;
      });
    } catch (e) {
      setState(() {
        _isParsing = false;
        _statusMessage = "";
      });
      if (mounted) {
        ActionDialog.show(
          context,
          title: "Parsing Failed",
          message: e.toString(),
          type: ActionDialogType.danger,
          onConfirm: () {},
        );
      }
    }
  }

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
      _statusMessage = "Uploading PDF to Cloudinary...";
    });

    try {
      final firestore = FirestoreService();
      String? pdfUrl;

      // 1. Upload PDF
      if (_selectedFile != null) {
        pdfUrl = await CloudinaryService().uploadPdf(_selectedFile!.path);
      }

      setState(() => _statusMessage = "Saving portfolio data...");

      // 2. Update Personal (name, role)
      if (_parsedData!.name.isNotEmpty || _parsedData!.role.isNotEmpty) {
        await firestore.updateContent('personal', {
          if (_parsedData!.name.isNotEmpty) 'name': _parsedData!.name,
          if (_parsedData!.role.isNotEmpty) 'role': _parsedData!.role,
        });
      }

      // 3. Update Hero section
      if (_parsedData!.hero.isNotEmpty) {
        await firestore.updateContent('hero', _parsedData!.hero);
      }

      // 4. Update About (Bio, Location, Education, Experience, ResumeURL)
      Map<String, dynamic> aboutData = {
        if (_parsedData!.summary.isNotEmpty) 'biography': _parsedData!.summary,
        if (_parsedData!.location.isNotEmpty) 'location': _parsedData!.location,
        'education': _parsedData!.education.map((e) => e.toMap()).toList(),
        'experience': _parsedData!.experience.map((e) => e.toMap()).toList(),
      };
      // Merge with AI's about map (interests, etc.)
      if (_parsedData!.about.isNotEmpty) {
        aboutData.addAll(_parsedData!.about);
      }
      if (pdfUrl != null) {
        aboutData['resumeUrl'] = pdfUrl;
      }
      await firestore.updateContent('about', aboutData);

      // 5. Update Expertise (stats, services, title)
      if (_parsedData!.expertise.isNotEmpty) {
        await firestore.updateContent('expertise', _parsedData!.expertise);
      }

      // 6. Update Skills — save the full map directly (includes titles + proficiency levels)
      if (_parsedData!.skills.isNotEmpty) {
        await firestore.updateContent('skills', _parsedData!.skills);
      }

      // 7. Update Contact info
      Map<String, dynamic> contactData = {};
      if (_parsedData!.email.isNotEmpty) {
        contactData['email'] = _parsedData!.email;
      }
      if (_parsedData!.personalEmail.isNotEmpty) {
        contactData['personalEmail'] = _parsedData!.personalEmail;
      }
      if (contactData.isNotEmpty) {
        await firestore.updateContent('contact', contactData);
      }

      // 8. Add Projects (with full details)
      for (var project in _parsedData!.projects) {
        await firestore.addProject(project.toMap());
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = "";
          _selectedFile = null;
          _parsedData = null;
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
        ActionDialog.show(
          context,
          title: "Save Failed",
          message: e.toString(),
          type: ActionDialogType.danger,
          onConfirm: () {},
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            if (_isParsing) ...[
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    const SizedBox(
                      height: 40,
                      width: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _statusMessage, // "Analyzing document..."
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please wait while we process your resume...",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_parsedData != null) _buildPreviewSection(),
          ],
        ),
      ),
    );
  }

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
          onPressed: _selectedFile != null ? _parseResume : () {},
          isLoading: _isParsing,
          icon: Icons.auto_awesome,
        ),
      ],
    );
  }

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
            "Summary: ${data.summary.substring(0, data.summary.length > 50 ? 50 : data.summary.length)}...",
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
            ...data.skills.entries.map(
                (e) => "• ${e.key.toUpperCase()}: ${e.value.length} skills"),
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
