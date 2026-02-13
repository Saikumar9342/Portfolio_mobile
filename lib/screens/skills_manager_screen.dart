import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_card.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import 'skill_detail_screen.dart';

class SkillsManagerScreen extends StatelessWidget {
  const SkillsManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Manage Skills',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService().streamContent('skills'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final data = snapshot.data!.data() ?? {};
          final sections = _parseSections(data);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSection(context, data),
                const SizedBox(height: 24),
                Text(
                  "SKILL SECTIONS",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                if (sections.isEmpty)
                  const Center(
                      child: Text("No skill sections found",
                          style: TextStyle(color: Colors.white54))),
                ...sections
                    .map((section) => _buildSectionCard(context, section)),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: "ADD NEW SECTION",
                  icon: Icons.add,
                  onPressed: () => _addNewSection(context),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_SkillSection> _parseSections(Map<String, dynamic> data) {
    final sections = <_SkillSection>[];

    data.forEach((key, value) {
      // We identify a section by the list data.
      // The Web App logic: it filters keys that are NOT arrays.
      // So any Array in this document is effectively a Skill Section.
      if (value is List) {
        final titleKey = '${key}Title';
        final title =
            data[titleKey] as String? ?? key; // Fallback to key if no title
        sections.add(_SkillSection(
            id: key,
            titleKey: titleKey,
            title: title,
            itemCount: value.length,
            isCustom: !['frontend', 'backend', 'mobile', 'tools', 'frameworks']
                .contains(key)));
      }
    });

    // Sort: Standard ones first, then custom
    // Simple sort by ID for now or defined order
    return sections;
  }

  Widget _buildHeaderSection(BuildContext context, Map<String, dynamic> data) {
    return GradientCard(
      onTap: () => _editHeader(context, data),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Page Header",
                  style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const Icon(Icons.edit, color: AppTheme.primaryColor, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data['title'] ?? 'Technical Expertise',
            style: GoogleFonts.outfit(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            data['description'] ?? 'No description set',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, _SkillSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GradientCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SkillDetailScreen(
                sectionId: section.id, sectionTitleKey: section.titleKey),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.code, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title, // Display Name
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${section.itemCount} items • Key: ${section.id}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Future<void> _editHeader(
      BuildContext context, Map<String, dynamic> data) async {
    final titleCtrl = TextEditingController(text: data['title'] ?? '');
    final descCtrl = TextEditingController(text: data['description'] ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text("Edit Page Header",
            style: GoogleFonts.outfit(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(label: "PAGE TITLE", controller: titleCtrl),
            const SizedBox(height: 16),
            CustomTextField(
                label: "DESCRIPTION", controller: descCtrl, isMultiline: true),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirestoreService().updateContent('skills', {
                'title': titleCtrl.text,
                'description': descCtrl.text,
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Save",
                style: TextStyle(color: AppTheme.primaryColor)),
          )
        ],
      ),
    );
  }

  Future<void> _addNewSection(BuildContext context) async {
    final keyCtrl = TextEditingController();
    final titleCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text("Add New Section",
            style: GoogleFonts.outfit(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
                label: "KEY (e.g. devops)",
                controller: keyCtrl,
                hint: "Lowercase, no spaces"),
            const SizedBox(height: 16),
            CustomTextField(
                label: "TITLE (e.g. DevOps)",
                controller: titleCtrl,
                hint: "Display Title"),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final key = keyCtrl.text.trim().toLowerCase();
              final title = titleCtrl.text.trim();
              if (key.isNotEmpty && title.isNotEmpty) {
                await FirestoreService().updateContent('skills', {
                  key: [], // Empty list
                  '${key}Title': title
                });
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text("Create",
                style: TextStyle(color: AppTheme.primaryColor)),
          )
        ],
      ),
    );
  }
}

class _SkillSection {
  final String id;
  final String titleKey;
  final String title;
  final int itemCount;
  final bool isCustom;

  _SkillSection({
    required this.id,
    required this.titleKey,
    required this.title,
    required this.itemCount,
    required this.isCustom,
  });
}
