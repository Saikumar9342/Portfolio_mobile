import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/language.dart';
import '../services/firestore_service.dart';
import '../services/translation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import 'content_editor_screen.dart';
import 'projects_screen.dart';
import 'skills_manager_screen.dart';
import '../services/language_search_service.dart';
import '../services/entitlement_service.dart';

class _TranslationUiProgress {
  final String message;
  final int completed;
  final int total;

  const _TranslationUiProgress({
    required this.message,
    required this.completed,
    required this.total,
  });

  double get fraction => total <= 0 ? 0 : (completed / total).clamp(0, 1).toDouble();

  String get counterLabel => '$completed/$total';
}

class LanguageListScreen extends StatefulWidget {
  const LanguageListScreen({super.key});

  @override
  State<LanguageListScreen> createState() => _LanguageListScreenState();
}

class _LanguageListScreenState extends State<LanguageListScreen> {
  final EntitlementService _entitlementService = EntitlementService();
  bool _autoSyncTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSyncLanguagesIfEligible();
    });
  }

  Future<void> _autoSyncLanguagesIfEligible() async {
    if (_autoSyncTriggered) return;
    _autoSyncTriggered = true;

    try {
      final entitlement = await _entitlementService.getCurrentEntitlement();
      final canUsePremium = entitlement.isPremium || entitlement.isAdmin;
      if (!canUsePremium) return;

      await LanguageSearchService().seedLanguagesFromApi();
    } catch (e) {
      debugPrint('Auto language sync failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitlementService = _entitlementService;

    return FutureBuilder<EntitlementState>(
        future: entitlementService.getCurrentEntitlement(),
        builder: (context, entSnapshot) {
          final bool canUsePremium = entSnapshot.data?.isPremium == true ||
              entSnapshot.data?.isAdmin == true;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService().streamLanguages(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Scaffold(
                  backgroundColor: AppTheme.scaffoldBackgroundColor,
                  body: Center(child: Text('Error: ${snapshot.error}')),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: AppTheme.scaffoldBackgroundColor,
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              final languages = docs
                  .map((doc) => Language.fromMap(doc.data(), doc.id))
                  .toList();

              // Ensure default English exists in list for UI
              if (!languages.any((l) => l.code == 'en')) {
                languages.insert(
                    0,
                    Language(
                      code: 'en',
                      name: 'English',
                      flag: '🇺🇸',
                      isDefault: true,
                    ));
              }

              return Scaffold(
                backgroundColor: AppTheme.scaffoldBackgroundColor,
                appBar: AppBar(
                  backgroundColor: AppTheme.scaffoldBackgroundColor,
                  elevation: 0,
                  title: Text(
                    "Languages",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.sync_rounded,
                          color: canUsePremium
                              ? Colors.blueAccent
                              : Colors.white24),
                      tooltip: "Sync global languages",
                      onPressed: () async {
                        if (!canUsePremium) {
                          await entitlementService.ensurePremiumAccess(context,
                              featureName: "Global Sync");
                          return;
                        }
                        _syncLanguages(context);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.add,
                          color: canUsePremium
                              ? AppTheme.primaryColor
                              : Colors.white24),
                      onPressed: () async {
                        if (!canUsePremium) {
                          await entitlementService.ensurePremiumAccess(context,
                              featureName: "Multi-Language");
                          return;
                        }
                        _showAddLanguageDialog(context, languages);
                      },
                    ),
                  ],
                ),
                body: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: languages.length + (canUsePremium ? 0 : 1),
                  itemBuilder: (context, index) {
                    if (!canUsePremium && index == 0) {
                      return _buildPremiumPromo(context, entitlementService);
                    }

                    final int langIndex = canUsePremium ? index : index - 1;
                    final lang = languages[langIndex];
                    final bool isLocked = !canUsePremium && lang.code != 'en';

                    return Card(
                      color: AppTheme.surfaceColor,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: Text(lang.flag ?? '🌐',
                            style: const TextStyle(fontSize: 24)),
                        title: Row(
                          children: [
                            Text(lang.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            if (isLocked) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.lock_rounded,
                                  size: 14, color: Colors.white38),
                            ],
                          ],
                        ),
                        subtitle: Text(lang.code.toUpperCase(),
                            style: const TextStyle(color: Colors.white70)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!lang.isDefault &&
                                lang.code != 'en' &&
                                canUsePremium)
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.redAccent),
                                onPressed: () =>
                                    _deleteLanguage(context, lang.code),
                              ),
                            const Icon(Icons.chevron_right,
                                color: Colors.white54),
                          ],
                        ),
                        onTap: () async {
                          if (isLocked) {
                            await entitlementService.ensurePremiumAccess(
                                context,
                                featureName: "Multi-Language");
                            return;
                          }
                          _showLanguageContentOptions(context, lang);
                        },
                      ),
                    );
                  },
                ),
              );
            },
          );
        });
  }

  Widget _buildPremiumPromo(
      BuildContext context, EntitlementService entitlementService) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.15),
            AppTheme.primaryColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: AppTheme.primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Global Presence",
                      style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    Text(
                      "Scale your portfolio across 50+ languages with automated AI translation.",
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => entitlementService.ensurePremiumAccess(context,
                  featureName: "Multi-Language"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("UPGRADE TO PREMIUM",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncLanguages(BuildContext context) async {
    _showProcessingDialog(context);
    try {
      await LanguageSearchService().seedLanguagesFromApi();
      if (context.mounted) {
        Navigator.pop(context); // pop processor
        _showStatusDialog(
          context,
          title: "Sync Successful",
          message: "The global language database has been updated.",
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // pop processor
        _showStatusDialog(
          context,
          title: "Sync Failed",
          message: e.toString(),
          isError: true,
        );
      }
    }
  }

  void _showAddLanguageDialog(
      BuildContext context, List<Language> existingLanguages) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final flagCtrl = TextEditingController();
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title:
              const Text("Add Language", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                label: "LANGUAGE NAME",
                hint: "e.g. Telugu, Hindi, Spanish",
                controller: nameCtrl,
                suffixIcon: Icons.search_rounded,
                onSuffixTap: () async {
                  final val = nameCtrl.text.trim();
                  if (val.length < 2) return;

                  setState(() => isSearching = true);
                  try {
                    // Lookup in Firebase using Language Search service
                    final match =
                        await LanguageSearchService().findLanguageByName(val);
                    if (match != null) {
                      setState(() {
                        codeCtrl.text = match['code']!;
                        flagCtrl.text = match['flag']!;
                      });
                    } else {
                      // Just a subtle feedback or do nothing, don't show an error dialog
                      // as the user can still click "Add & Translate" and it will use fallback.
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Using generic setup for '$val'"),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    }
                  } finally {
                    setState(() => isSearching = false);
                  }
                },
                onChanged: (val) {
                  // If name changes, clear the auto-filled fields to force re-search
                  if (codeCtrl.text.isNotEmpty || flagCtrl.text.isNotEmpty) {
                    setState(() {
                      codeCtrl.clear();
                      flagCtrl.clear();
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: "ISO CODE (Auto-filled)",
                controller: codeCtrl,
                enabled: false,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: "FLAG (Auto-filled)",
                controller: flagCtrl,
                enabled: false,
              ),
              if (isSearching)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                String langName = nameCtrl.text.trim();
                if (langName.isEmpty) return;

                final progressNotifier = ValueNotifier<_TranslationUiProgress>(
                  const _TranslationUiProgress(
                    message: "Preparing translation...",
                    completed: 0,
                    total: 1,
                  ),
                );

                _showProcessingDialog(context, progressNotifier: progressNotifier);

                try {
                  String langCode = codeCtrl.text.trim().toLowerCase();
                  String flagEmoji = flagCtrl.text.trim();

                  // 1. Automatic lookup if fields are empty (The "Magic" part)
                  if (langCode.isEmpty || flagEmoji.isEmpty) {
                    final match = await LanguageSearchService()
                        .findLanguageByName(langName);
                    if (match != null) {
                      langCode = match['code']!.toLowerCase();
                      flagEmoji = match['flag']!;
                    } else {
                      // Fallback if not found in database - use first 2 letters as code
                      langCode = langName.length >= 2
                          ? langName.substring(0, 2).toLowerCase()
                          : langName.toLowerCase();
                      flagEmoji = '??';
                    }
                  }

                  // Duplicate Check
                  if (existingLanguages.any((l) => l.code == langCode)) {
                    if (context.mounted) {
                      Navigator.pop(context); // pop processing
                    }
                    if (context.mounted) {
                      _showStatusDialog(
                        context,
                        title: "Already Exists",
                        message:
                            "'$langName' is already part of your portfolio.",
                        isError: true,
                      );
                    }
                    return;
                  }

                  await FirestoreService().addLanguage(langCode, {
                    'name': langName,
                    'flag': flagEmoji,
                    'isDefault': false,
                  });

                  await TranslationService().translateAndSaveContentForLanguage(
                    langCode,
                    onProgress: ({
                      required String message,
                      required int completed,
                      required int total,
                    }) {
                      progressNotifier.value = _TranslationUiProgress(
                        message: message,
                        completed: completed,
                        total: total,
                      );
                    },
                  );

                  if (context.mounted) {
                    Navigator.pop(context); // pop processing dialog
                    Navigator.pop(ctx); // pop add dialog

                    _showStatusDialog(
                      context,
                      title: "Setup Complete",
                      message:
                          "$langName (code: $langCode) has been successfully integrated and translated into your portfolio.",
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // pop processing dialog
                    _showStatusDialog(
                      context,
                      title: "Setup Failed",
                      message: "An error occurred: $e",
                      isError: true,
                    );
                  }
                } finally {
                  progressNotifier.dispose();
                }
              },
              child: const Text("Add & Translate"),
            ),
          ],
        ),
      ),
    );
  }

  void _showProcessingDialog(
    BuildContext context, {
    ValueNotifier<_TranslationUiProgress>? progressNotifier,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(32),
            border:
                Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
          ),
          child: progressNotifier == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Synchronizing Experience",
                      style: GoogleFonts.outfit(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Setting up language & translating content...",
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    )
                  ],
                )
              : ValueListenableBuilder<_TranslationUiProgress>(
                  valueListenable: progressNotifier,
                  builder: (context, progress, _) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "Synchronizing Experience",
                          style: GoogleFonts.outfit(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            decoration: TextDecoration.none,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          progress.message,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress.fraction,
                            minHeight: 8,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryColor),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          progress.counterLabel,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _deleteLanguage(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text("Delete Language?",
            style: TextStyle(color: Colors.white)),
        content: const Text(
            "This will delete the language configuration. Content might remain in database.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirestoreService().deleteLanguage(code);
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditLanguageDialog(BuildContext context, Language lang) {
    final codeCtrl = TextEditingController(text: lang.code);
    final nameCtrl = TextEditingController(text: lang.name);
    final flagCtrl = TextEditingController(text: lang.flag);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title:
            const Text("Edit Language", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
                label: "CODE",
                controller: codeCtrl,
                enabled: false), // Code is ID
            const SizedBox(height: 12),
            CustomTextField(label: "NAME", controller: nameCtrl),
            const SizedBox(height: 12),
            CustomTextField(label: "FLAG EMOJI", controller: flagCtrl),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                await FirestoreService().updateLanguage(lang.code, {
                  'name': nameCtrl.text.trim(),
                  'flag': flagCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text("Save",
                style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  void _showLanguageContentOptions(BuildContext context, Language lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow it to take more space if needed
      backgroundColor: AppTheme.surfaceColor,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            controller: controller,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text("Edit ${lang.name} Content",
                    style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 20),
                ListTile(
                  leading:
                      const Icon(Icons.edit_note, color: Colors.blueAccent),
                  title: const Text("Edit Language Details",
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text("Name & Flag",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditLanguageDialog(context, lang);
                  },
                ),
                const Divider(color: Colors.white10),
                _buildOption(
                    context, "Hero Section", Icons.monitor, 'hero', lang.code),
                _buildOption(context, "About & Socials", Icons.person, 'about',
                    lang.code),
                _buildOption(context, "Expertise", Icons.lightbulb, 'expertise',
                    lang.code),
                _buildOption(
                    context, "Contact Info", Icons.email, 'contact', lang.code),
                _buildOption(context, "Projects Page", Icons.work,
                    'projects_page', lang.code),
                ListTile(
                  leading: const Icon(Icons.apps, color: AppTheme.primaryColor),
                  title: const Text("Manage Projects",
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProjectsScreen(languageCode: lang.code),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.code, color: AppTheme.primaryColor),
                  title: const Text("Manage Skills",
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SkillsManagerScreen(languageCode: lang.code),
                      ),
                    );
                  },
                ),
                _buildOption(
                    context, "Navbar", Icons.menu, 'navbar', lang.code),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, String title, IconData icon,
      String docId, String langCode) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context); // Close sheet
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContentEditorScreen(
                docId: docId,
                title: "$title (${langCode.toUpperCase()})",
                languageCode: langCode),
          ),
        );
      },
    );
  }

  void _showStatusDialog(BuildContext context,
      {required String title, required String message, bool isError = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.redAccent : AppTheme.primaryColor,
            ),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "OK",
              style: TextStyle(
                color: isError ? Colors.redAccent : AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



