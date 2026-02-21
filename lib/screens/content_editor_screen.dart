import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/action_dialog.dart';
import '../services/ai_service.dart';

enum DataType { string, stringList, objectList, json, image }

class FieldData {
  TextEditingController controller;
  DataType type;
  List<Map<String, dynamic>>? objectItems;

  FieldData(this.controller, this.type, {this.objectItems});
}

class ContentEditorScreen extends StatefulWidget {
  final String docId;
  final String title;
  final String? languageCode;

  const ContentEditorScreen({
    super.key,
    required this.docId,
    required this.title,
    this.languageCode,
  });

  @override
  State<ContentEditorScreen> createState() => _ContentEditorScreenState();
}

class _ContentEditorScreenState extends State<ContentEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, FieldData> _fields = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _isDirty = false;
  bool _isProgrammaticFieldUpdate = false;
  final CloudinaryService _cloudinaryService = CloudinaryService();
  static const Set<String> _numericObjectKeys = {
    'level',
    'score',
    'percentage',
    'percent',
    'order',
    'priority',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _markDirty() {
    if (mounted && !_isDirty && !_isLoading) {
      setState(() => _isDirty = true);
    }
  }

  void _setFieldText(FieldData field, String value) {
    _isProgrammaticFieldUpdate = true;
    field.controller.text = value;
    _isProgrammaticFieldUpdate = false;
  }

  void _disposeDialogControllersSafely(
    Iterable<TextEditingController> controllers,
  ) {
    // Let route transition + keyboard teardown finish before disposing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        for (final controller in controllers) {
          controller.dispose();
        }
      });
    });
  }

  List<Map<String, dynamic>> _normalizeObjectItems(List<dynamic> rawItems) {
    return rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.fromEntries(
              item.entries.map((e) => MapEntry(e.key.toString(), e.value)),
            ))
        .toList();
  }

  List<Map<String, dynamic>> _decodeObjectItems(String raw) {
    if (raw.trim().isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return _normalizeObjectItems(decoded);
    } catch (_) {
      // Ignore malformed JSON and return empty list for UI stability.
    }
    return <Map<String, dynamic>>[];
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final isDefaultLanguage =
          widget.languageCode == null || widget.languageCode == 'en';

      Map<String, dynamic> baseFirestoreData = {};
      if (!isDefaultLanguage) {
        // Fetch base data (English) to preserve common fields like images
        final baseSnapshot = await FirestoreService()
            .streamContent(widget.docId, languageCode: 'en')
            .first;
        if (baseSnapshot.exists && baseSnapshot.data() != null) {
          baseFirestoreData = baseSnapshot.data()!;
        }
      }

      final snapshot = await FirestoreService()
          .streamContent(widget.docId, languageCode: widget.languageCode)
          .first;

      Map<String, dynamic> fetchedData = {};
      if (snapshot.exists && snapshot.data() != null) {
        fetchedData = snapshot.data()!;
      }

      final defaultData = _getDefaultData(widget.docId);
      // Merge order: Hardcoded Defaults < Base Firestore (EN) < Localized Firestore
      final Map<String, dynamic> data = {
        ...defaultData,
        ...baseFirestoreData,
        ...fetchedData
      };

      // Explicitly remove legacy social fields from contact section to avoid confusion
      if (widget.docId == 'contact') {
        data.remove('github');
        data.remove('linkedin');
        data.remove('socialLinks'); // socialLinks moved to 'about'
      }

      final sortedKeys = data.keys.toList()..sort();

      for (var key in sortedKeys) {
        final value = data[key];
        String text = '';
        DataType type = DataType.string;
        List<Map<String, dynamic>>? objectItems;

        if (value is String) {
          text = value;
          if (key.toLowerCase().contains('image') || key == 'imageUrl') {
            type = DataType.image;
          } else {
            type = DataType.string;
          }
        } else if (value is List) {
          if (value.isEmpty) {
            // Try to infer type from default data if empty
            final defaultVal = defaultData[key];
            if (defaultVal is List &&
                defaultVal.isNotEmpty &&
                defaultVal.first is Map) {
              type = DataType.objectList;
              objectItems = <Map<String, dynamic>>[];
            } else if (defaultVal is List &&
                defaultVal.isNotEmpty &&
                defaultVal.first is String) {
              type = DataType.stringList;
              text = '';
            } else {
              // Fallback
              text = const JsonEncoder.withIndent('  ').convert(value);
              type = DataType.json;
            }
          } else if (value.first is String) {
            text = (value).join(', ');
            type = DataType.stringList;
          } else if (value.first is Map) {
            type = DataType.objectList;
            objectItems = _normalizeObjectItems(value);
          } else {
            text = const JsonEncoder.withIndent('  ').convert(value);
            type = DataType.json;
          }
        } else {
          if (value == null) {
            text = '';
          } else {
            text = const JsonEncoder.withIndent('  ').convert(value);
            type = DataType.json;
          }
        }
        final controller = TextEditingController(text: text);
        controller.addListener(() {
          if (_isProgrammaticFieldUpdate) return;
          if (!_isDirty && !_isLoading && mounted) {
            setState(() => _isDirty = true);
          }
        });
        _fields[key] = FieldData(
          controller,
          type,
          objectItems: objectItems,
        );
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Same logic as before for default data
  Map<String, dynamic> _getDefaultData(String docId) {
    switch (docId) {
      case 'seo':
        return {
          'seoTitle': 'My Portfolio',
          'seoDescription': 'A professional portfolio.',
          'ogImage':
              '' // Empty matches the 'image' data type dynamically if the key has "image"
        };
      case 'hero':
        return {
          'title': 'Your Title',
          'subtitle': 'Your Subtitle',
          'badge': 'Badge Text',
          'cta': 'Click Me',
          'secondaryCta': 'Secondary Action',
          'imageUrl': ''
        };
      case 'about':
        return {
          'title': 'About Me',
          'biography': 'Write your bio here...',
          'location': 'City, Country',
          'education': [
            {"degree": "Degree", "institution": "University", "year": "2024"}
          ],
          'interests': ['Photography', 'Music', 'Travel'],
          'socialLinks': [
            {'platform': 'github', 'url': ''}
          ],
          'resumeUrl': '',
          'experience': [
            {
              'position': 'Position',
              'company': 'Company',
              'startDate': '2023',
              'endDate': 'Present',
              'description': 'Role description...'
            }
          ]
        };
      case 'contact':
        return {
          'title': 'Get In Touch',
          'description': 'Contact description',
          'email': 'email@example.com',
          'personalEmail': 'personal@example.com',
          'cta': 'Contact Me',
          'secondaryCta': 'Other Action',
          'formNameLabel': 'Full Name',
          'formNamePlaceholder': 'John Doe',
          'formEmailLabel': 'Email Address',
          'formEmailPlaceholder': 'john@example.com',
          'formSubjectLabel': 'Subject (Optional)',
          'formSubjectPlaceholder': 'Project Inquiry',
          'formMessageLabel': 'Your Message',
          'formMessagePlaceholder': 'How can I help you?',
          'formSubmitButton': 'Send Message'
        };
      case 'skills':
        return {
          'frontendTitle': 'Frontend',
          'mobileTitle': 'Mobile',
          'backendTitle': 'Backend',
          'toolsTitle': 'Tools',
          'frameworksTitle': 'Frameworks',
          'frontend': [
            {'name': 'React', 'level': 90}
          ],
          'mobile': ['Flutter', 'React Native'],
          'backend': ['Node.js', 'Firebase'],
          'tools': ['Git', 'VS Code'],
          'frameworks': ['Next.js']
        };
      case 'expertise':
        return {
          'title': 'My Expertise',
          'label': 'What I Do',
          'stats': [
            {'label': 'Years', 'value': '5+'}
          ],
          'services': [
            {
              'id': '1',
              'title': 'Web Development',
              'description': 'Modern websites'
            }
          ]
        };
      case 'navbar':
        return {
          'logoText': 'S',
          'ctaText': 'Hire Me',
          'items': [
            {'label': 'Home', 'href': '/'}
          ]
        };
      case 'projects_page':
        return {
          'title': 'Selected',
          'titleHighlight': 'Works',
          'label': 'Works Portfolio',
          'description': 'A curated collection of digital experiences...'
        };
      default:
        return {'title': 'New Section'};
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      final Map<String, dynamic> data = {};
      bool hasError = false;

      _fields.forEach((key, field) {
        try {
          switch (field.type) {
            case DataType.string:
              data[key] = field.controller.text;
              break;
            case DataType.image:
              // Only save image updates if we are in the default language
              // This prevents images from being reset or duplicated across languages
              final isDefaultLanguage =
                  widget.languageCode == null || widget.languageCode == 'en';
              if (isDefaultLanguage) {
                data[key] = field.controller.text;
              }
              break;
            case DataType.stringList:
              data[key] = field.controller.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              break;
            case DataType.json:
              data[key] = jsonDecode(field.controller.text);
              break;
            case DataType.objectList:
              data[key] = field.objectItems ?? <Map<String, dynamic>>[];
              break;
          }
        } catch (e) {
          hasError = true;
          SoundService.playError();
          ActionDialog.show(
            context,
            title: "Format Error",
            message: 'Error parsing field $key: $e',
            type: ActionDialogType.danger,
            onConfirm: () {},
          );
        }
      });

      if (hasError) {
        setState(() => _isSaving = false);
        return;
      }

      try {
        await FirestoreService().updateContent(widget.docId, data,
            languageCode: widget.languageCode);
        if (mounted) {
          setState(() => _isDirty = false);
          SoundService.playSuccess();
          ActionDialog.show(
            context,
            title: "Success",
            message: "Your changes have been saved successfully!",
            onConfirm: () => Navigator.pop(context),
          );
        }
      } catch (e) {
        if (mounted) {
          SoundService.playError();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              title: Text('Save Error',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              content: Text('Failed to save changes: $e',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
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
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickImage(FieldData field) async {
    setState(() => _isUploadingImage = true);
    try {
      final url = await _cloudinaryService.pickAndUploadImage();
      if (url != null) {
        setState(() {
          _setFieldText(field, url);
        });
      } else {
        if (mounted) {
          ActionDialog.show(
            context,
            title: "Upload Failed",
            message: "The image could not be uploaded to Cloudinary.",
            type: ActionDialogType.danger,
            onConfirm: () {},
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty || _isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldPop = await ActionDialog.show(
          context,
          title: "Unsaved Changes",
          message:
              "You have unsaved changes. Are you sure you want to discard them?",
          confirmLabel: "DISCARD",
          type: ActionDialogType.warning,
          onConfirm: () {},
        );

        if (shouldPop == true && mounted) {
          Navigator.pop(this.context);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBackgroundColor,
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : Form(
                key: _formKey,
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar.large(
                      title: Text(widget.title,
                          style:
                              GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      backgroundColor: AppTheme.scaffoldBackgroundColor,
                      surfaceTintColor: Colors.transparent,
                      pinned: true,
                      actions: [
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: _isSaving
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: AppTheme.primaryColor,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.check_circle,
                                      color: AppTheme.primaryColor, size: 32),
                                  onPressed: _save,
                                ),
                        ),
                      ],
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final entry = _fields.entries.toList()[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: _buildField(entry.key, entry.value),
                            );
                          },
                          childCount: _fields.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            if (widget.docId == 'skills')
                              Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: PrimaryButton(
                                  text: "ADD NEW SKILL SECTION",
                                  icon: Icons.playlist_add,
                                  onPressed: _addNewSection,
                                ),
                              ),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        floatingActionButton: _isSaving
            ? null
            : FloatingActionButton.extended(
                onPressed: _save,
                label: Text("Save Changes",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                icon: const Icon(Icons.save),
                backgroundColor: AppTheme.primaryColor,
              ),
      ),
    );
  }

  Future<void> _addNewSection() async {
    final nameCtrl = TextEditingController();
    final titleCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text("Add New Skill Section",
            style: GoogleFonts.outfit(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              label: "SECTION KEY (e.g. devops)",
              controller: nameCtrl,
              hint: "lowercase, no spaces",
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: "DISPLAY TITLE (e.g. DevOps)",
              controller: titleCtrl,
              hint: "Visible Section Title",
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              final key = nameCtrl.text.trim().toLowerCase();
              final title = titleCtrl.text.trim();

              if (key.isNotEmpty && title.isNotEmpty) {
                final sectionController = TextEditingController(text: '[]');
                sectionController.addListener(_markDirty);
                final titleController = TextEditingController(text: title);
                titleController.addListener(_markDirty);

                setState(() {
                  // Add the list field
                  _fields[key] = FieldData(
                    sectionController,
                    DataType.objectList,
                    objectItems: <Map<String, dynamic>>[],
                  );
                  // Add the title field
                  _fields['${key}Title'] =
                      FieldData(titleController, DataType.string);
                  _isDirty = true;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text("Add",
                style: TextStyle(color: AppTheme.primaryColor)),
          )
        ],
      ),
    );
    _disposeDialogControllersSafely([nameCtrl, titleCtrl]);
  }

  Widget _buildField(String key, FieldData field) {
    if (field.type == DataType.objectList) {
      return _buildObjectListEditor(key, field);
    }

    String hint = '';
    bool isMultiline = false;

    if (field.type == DataType.json) {
      isMultiline = true;
      hint = 'Enter valid JSON structure';
    } else if (field.type == DataType.string &&
        field.controller.text.length > 50) {
      isMultiline = true;
    } else if (field.type == DataType.stringList) {
      isMultiline = true;
      hint = 'Values separated by commas';
    }

    if (field.type == DataType.image) {
      final isDefaultLanguage =
          widget.languageCode == null || widget.languageCode == 'en';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextField(
            label: key.toUpperCase(),
            controller: field.controller,
            hint: "Image URL",
            prefixIcon: Icons.link,
            readOnly:
                !isDefaultLanguage, // Restrict direct edit for translations
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              image: !_isUploadingImage && field.controller.text.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(field.controller.text),
                      fit: BoxFit.cover,
                      onError: (_, __) => const Icon(
                          Icons.broken_image), // Placeholder handling
                    )
                  : null,
            ),
            child: _isUploadingImage
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primaryColor),
                        SizedBox(height: 12),
                        Text("Uploading...",
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                : field.controller.text.isEmpty
                    ? const Center(
                        child:
                            Icon(Icons.image, size: 48, color: Colors.white24))
                    : null,
          ),
          const SizedBox(height: 12),
          if (isDefaultLanguage)
            PrimaryButton(
              text:
                  _isUploadingImage ? "Wait for Upload..." : "Upload New Image",
              onPressed: () => _pickImage(field),
              isLoading: _isUploadingImage,
              icon: Icons.cloud_upload_outlined,
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Images are common across all languages. To update this image, please switch back to the default (English) version.",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    final textField = CustomTextField(
      label: key.toUpperCase(),
      controller: field.controller,
      isMultiline: isMultiline,
      hint: hint,
      validator: (value) {
        if (field.type == DataType.json) {
          try {
            if (value != null && value.isNotEmpty) {
              jsonDecode(value);
            }
          } catch (e) {
            return 'Invalid JSON format';
          }
        }
        return null;
      },
    );

    if (isMultiline && field.type == DataType.string) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          textField,
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final currentText = field.controller.text.trim();
                if (currentText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text("Please enter some text first to enhance.")),
                  );
                  return;
                }

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.primaryColor),
                  ),
                );

                try {
                  final enhancedText =
                      await AIService().enhanceText(currentText, key);
                  if (mounted) Navigator.pop(context); // close dialog
                  if (enhancedText != null && mounted) {
                    _setFieldText(field, enhancedText);
                    _markDirty();
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              icon: const Icon(Icons.auto_awesome,
                  color: AppTheme.primaryColor, size: 18),
              label: Text(
                "AI Enhance",
                style: GoogleFonts.inter(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          )
        ],
      );
    }

    return textField;
  }

  Widget _buildObjectListEditor(String key, FieldData field) {
    final items =
        field.objectItems ??= _decodeObjectItems(field.controller.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final title = item.values.firstOrNull?.toString() ?? 'Item $index';
          final subtitle =
              item.values.length > 1 ? item.values.elementAt(1).toString() : '';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: AppTheme.inputFillColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10)),
            child: ListTile(
              title: Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: subtitle.isNotEmpty
                  ? Text(subtitle,
                      style: const TextStyle(color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                    onPressed: () => _editListItem(key, items, index, field),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                    onPressed: () {
                      setState(() {
                        items.removeAt(index);
                        field.objectItems =
                            List<Map<String, dynamic>>.from(items);
                        _isDirty = true;
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }),
        PrimaryButton(
          text: "Add ${key.toUpperCase()}",
          onPressed: () => _editListItem(key, items, -1, field),
          icon: Icons.add,
        )
      ],
    );
  }

  void _editListItem(String listKey, List<Map<String, dynamic>> items,
      int index, FieldData field) {
    final bool isNew = index == -1;

    // 1. Determine the initial data map
    late Map<String, dynamic> initialData;
    if (isNew) {
      initialData = _getTemplateForItem(listKey);
    } else {
      initialData = Map<String, dynamic>.from(items[index] as Map);
    }

    // 2. Create controllers for each field in the map
    // We map each key to a TextEditingController
    final Map<String, TextEditingController> controllers = {};
    initialData.forEach((key, value) {
      controllers[key] = TextEditingController(text: value.toString());
    });

    // 3. Show Bottom Sheet (Better for keyboard handling)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isNew ? "Add Item" : "Edit Item",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: controllers.entries.map((entry) {
                      final key = entry.key;
                      final controller = entry.value;

                      if (key.toLowerCase() == 'icon') {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildIconPickerForDialog(controller),
                        );
                      }

                      final isDateKey = key.toLowerCase() == 'year' ||
                          key.toLowerCase() == 'period' ||
                          (key.toLowerCase() == 'value' &&
                              controllers['label']
                                      ?.text
                                      .toLowerCase()
                                      .contains('experience') ==
                                  true);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: CustomTextField(
                          label: key.toUpperCase(),
                          controller: controller,
                          hint: _getPlaceholderForKey(key),
                          suffixIcon: isDateKey ? Icons.calendar_month : null,
                          onSuffixTap: isDateKey
                              ? () =>
                                  _pickDateRangeForField(ctx, key, controller)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                text: "Save Item",
                onPressed: () {
                  try {
                    // 4. Collect values from controllers
                    final Map<String, dynamic> newItem = {};

                    controllers.forEach((key, controller) {
                      final text = controller.text;
                      final normalizedKey = key.trim().toLowerCase();
                      final shouldParseNumber =
                          _numericObjectKeys.contains(normalizedKey) &&
                              !text.contains(',');
                      if (shouldParseNumber) {
                        final parsedNum = num.tryParse(text);
                        newItem[key] = parsedNum ?? text;
                      } else {
                        newItem[key] = text;
                      }
                    });

                    final updatedItems = List<Map<String, dynamic>>.from(items);

                    if (isNew) {
                      updatedItems.add(newItem);
                    } else {
                      updatedItems[index] = newItem;
                    }

                    if (!mounted) {
                      Navigator.of(ctx).pop();
                      return;
                    }

                    setState(() {
                      field.objectItems = updatedItems;
                      _isDirty = true;
                    });

                    Navigator.of(ctx).pop(); // Close sheet
                  } catch (e) {
                    if (!mounted) return;
                    ActionDialog.show(
                      context,
                      title: "Save Failed",
                      message: "Could not save item: $e",
                      type: ActionDialogType.danger,
                      onConfirm: () {},
                    );
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    ).then((_) {
      _disposeDialogControllersSafely(controllers.values);
    });

    // Note: controllers are disposed in the .then() block to avoid leaks
  }

  Map<String, dynamic> _getTemplateForItem(String key) {
    // Provide templates for known keys to ensure structure
    if (key == 'education') {
      return {"degree": "", "institution": "", "year": ""};
    }
    if (key == 'stats') return {"label": "", "value": ""};
    if (key == 'services') {
      return {"id": "", "title": "", "description": "", "icon": "Code2"};
    }

    // Default template for ANY list in the SKILLS document
    if (widget.docId == 'skills') {
      return {"name": "", "level": "90", "icon": "Code2"};
    }

    if (key == 'experience') {
      return {
        "role": "",
        "company": "",
        "period": "",
        "description": "",
        "isCurrent": false
      };
    }
    if (key == 'items') return {"label": "", "href": ""};
    if (key == 'socialLinks') return {"platform": "", "url": ""};

    return {"title": "", "description": ""}; // Generic fallback
  }

  String _getPlaceholderForKey(String key) {
    switch (key.toLowerCase()) {
      case 'title':
        return 'e.g. Project Title / Job Title';
      case 'description':
        return 'e.g. A breif description...';
      case 'degree':
        return 'e.g. Bachelor of Science';
      case 'institution':
        return 'e.g. mit';
      case 'year':
        return 'e.g. 2020 - 2024';
      case 'period':
        return 'e.g. Jan 2020 - Present';
      case 'company':
        return 'e.g. Google';
      case 'role':
        return 'e.g. Senior Software Engineer';
      case 'label':
        return 'e.g. Projects Completed';
      case 'value':
        return 'e.g. 15+';
      case 'platform':
        return 'e.g. github / linkedin';
      case 'url':
        return 'e.g. https://github.com/username';
      case 'href':
        return 'e.g. https://example.com';
      case 'name':
        return 'e.g. React Native';
      case 'level':
        return 'e.g. 90';
      case 'id':
        return 'e.g. unique-id';
      default:
        return 'Enter $key...';
    }
  }

  Future<void> _pickDateRangeForField(BuildContext context, String key,
      TextEditingController controller) async {
    final lowerKey = key.toLowerCase();
    final isEducationYear = lowerKey == 'year';
    final isExperiencePeriod = lowerKey == 'period';
    // Check if this is the "Stats" value field for Experience
    // We can infer this if the key is 'value' (since we only enable the button in that case)
    final isStatsExperience = lowerKey == 'value';

    if (!isEducationYear && !isExperiencePeriod && !isStatsExperience) return;

    final now = DateTime.now();
    final firstDate = DateTime(1960); // Reasonable start
    final lastDate = now;

    // Custom Theme Builder for DatePicker
    Widget datePickerTheme(BuildContext context, Widget? child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.primaryColor, // Header background & selected day
            onPrimary: Colors.black, // Text on selected day
            surface: AppTheme.surfaceColor, // Dialog background
            onSurface: Colors.white, // Normal text
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor, // Button text color
            ),
          ),
          dialogTheme:
              const DialogThemeData(backgroundColor: AppTheme.surfaceColor),
        ),
        child: child!,
      );
    }

    // 1. Pick Start Date
    final start = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: "SELECT START DATE",
      builder: datePickerTheme,
    );
    if (start == null) return;

    // Special Case: Stats Experience (Years.Months)
    if (isStatsExperience) {
      int totalMonths =
          (now.year - start.year - 1) * 12 + now.month - start.month;
      if (now.day < start.day) {
        totalMonths--;
      }
      if (totalMonths < 0) totalMonths = 0;

      final years = totalMonths ~/ 12;
      final months = totalMonths % 12;

      if (months > 0) {
        controller.text = "$years.$months+";
      } else {
        controller.text = "$years+";
      }
      return;
    }

    DateTime? end;
    bool isPresent = false;

    // 2. Pick End Date or "Present"
    if (isExperiencePeriod) {
      if (!context.mounted) return;
      // Ask if currently working
      final isCurrent = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text("Currently working here?",
              style: GoogleFonts.outfit(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("No, I left",
                  style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Yes, Current",
                  style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        ),
      );

      if (isCurrent == true) {
        isPresent = true;
        end = DateTime.now();
      } else {
        if (!context.mounted) return;
        end = await showDatePicker(
          context: context,
          initialDate: start,
          firstDate: start,
          lastDate: lastDate,
          helpText: "SELECT END DATE",
          builder: datePickerTheme,
        );
        if (end == null) return; // User cancelled end date
      }
    } else {
      if (!context.mounted) return;
      // Education: Just pick end date usually
      end = await showDatePicker(
        context: context,
        initialDate: start,
        firstDate: start,
        lastDate: lastDate,
        helpText: "SELECT END DATE",
        builder: datePickerTheme,
      );
      if (end == null) return;
    }

    // 3. Format String
    String result = "";
    if (isEducationYear) {
      // Education: "2018 - 2022"
      result = "${start.year} - ${end.year}";
    } else {
      // Experience: "Jan 2021 - Present · 2 yrs 3 mos"
      final endYear =
          isPresent ? "Present" : "${_monthName(end.month)} ${end.year}";
      final startStr = "${_monthName(start.month)} ${start.year}";

      // Calculate duration
      final endDate = isPresent ? DateTime.now() : end;

      // Improve calculation: using month difference
      int totalMonths =
          (endDate.year - start.year) * 12 + endDate.month - start.month;
      if (endDate.day >= start.day) {
        // Full month passed
      } else {
        // Not quite a full month
        totalMonths--;
      }

      // Ensure specific "joined today" doesn't show negative
      if (totalMonths < 0) totalMonths = 0;

      final yearsVal = totalMonths ~/ 12;
      final monthsVal = totalMonths % 12;

      String durationStr = "";
      if (yearsVal > 0) durationStr += "$yearsVal yrs ";
      if (monthsVal > 0) durationStr += "$monthsVal mos";
      if (durationStr.isEmpty) durationStr = "1 mo";

      result = "$startStr - $endYear · ${durationStr.trim()}";
    }

    controller.text = result;
  }

  String _monthName(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return months[month - 1];
  }

  Widget _buildIconPickerForDialog(TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "SELECT ICON",
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        StatefulBuilder(builder: (context, setDialogState) {
          final selectedIcon = controller.text;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Code2',
              'Layout',
              'Maximize2',
              'Globe',
              'Database',
              'Cpu',
              'Layers',
              'Smartphone',
              'Terminal',
              'Shield',
              'Workflow',
              'Palette'
            ].map((iconName) {
              final isSelected = selectedIcon == iconName;
              return GestureDetector(
                onTap: () {
                  // Update state using the StateSetter from StatefulBuilder
                  setDialogState(() {
                    controller.text = iconName;
                  });
                  // Also trigger main widget rebuild to show dirty state
                  setState(() {
                    _isDirty = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.inputFillColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isSelected ? AppTheme.primaryColor : Colors.white10,
                    ),
                  ),
                  child: Icon(
                    _getIconData(iconName),
                    color: isSelected ? Colors.white : Colors.white70,
                    size: 20,
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'Code2':
        return Icons.code_rounded;
      case 'Layout':
        return Icons.dashboard_customize_rounded;
      case 'Maximize2':
        return Icons.zoom_out_map_rounded;
      case 'Globe':
        return Icons.public_rounded;
      case 'Database':
        return Icons.storage_rounded;
      case 'Cpu':
        return Icons.memory_rounded;
      case 'Layers':
        return Icons.layers_rounded;
      case 'Smartphone':
        return Icons.smartphone_rounded;
      case 'Terminal':
        return Icons.terminal_rounded;
      case 'Shield':
        return Icons.security_rounded;
      case 'Workflow':
        return Icons.account_tree_rounded;
      case 'Palette':
        return Icons.palette_rounded;
      default:
        return Icons.code_rounded;
    }
  }
}
