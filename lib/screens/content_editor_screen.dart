import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/action_dialog.dart';

enum DataType { string, stringList, objectList, json, image }

class FieldData {
  TextEditingController controller;
  DataType type;
  FieldData(this.controller, this.type);
}

class ContentEditorScreen extends StatefulWidget {
  final String docId;
  final String title;

  const ContentEditorScreen({
    super.key,
    required this.docId,
    required this.title,
  });

  @override
  State<ContentEditorScreen> createState() => _ContentEditorScreenState();
}

class _ContentEditorScreenState extends State<ContentEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, FieldData> _fields = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDirty = false;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  @override
  void initState() {
    super.initState();
    _loadData();
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
      final snapshot =
          await FirestoreService().streamContent(widget.docId).first;

      Map<String, dynamic> fetchedData = {};
      if (snapshot.exists && snapshot.data() != null) {
        fetchedData = snapshot.data()!;
      }

      final defaultData = _getDefaultData(widget.docId);
      final Map<String, dynamic> data = {...defaultData, ...fetchedData};

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
              text = const JsonEncoder.withIndent('  ').convert(value);
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
            text = const JsonEncoder.withIndent('  ').convert(value);
            type = DataType.objectList;
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
          if (!_isDirty && !_isLoading) {
            setState(() => _isDirty = true);
          }
        });
        _fields[key] = FieldData(controller, type);
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
          'interests': [],
          'socialLinks': [
            {'platform': 'github', 'url': ''}
          ]
        };
      case 'contact':
        return {
          'title': 'Get In Touch',
          'description': 'Contact description',
          'email': 'email@example.com',
          'personalEmail': 'personal@example.com',
          'cta': 'Contact Me',
          'secondaryCta': 'Other Action'
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
            case DataType.image:
              data[key] = field.controller.text;
              break;
            case DataType.stringList:
              data[key] = field.controller.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              break;
            case DataType.json:
            case DataType.objectList:
              data[key] = jsonDecode(field.controller.text);
              break;
          }
        } catch (e) {
          hasError = true;
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
        await FirestoreService().updateContent(widget.docId, data);
        if (mounted) {
          setState(() => _isDirty = false);
          ActionDialog.show(
            context,
            title: "Success",
            message: "Your changes have been saved successfully!",
            onConfirm: () => Navigator.pop(context),
          );
        }
      } catch (e) {
        if (mounted) {
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
    final url = await _cloudinaryService.pickAndUploadImage();
    if (url != null) {
      setState(() {
        field.controller.text = url;
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
                setState(() {
                  // Add the list field
                  _fields[key] = FieldData(
                      TextEditingController(text: '[]'), DataType.objectList);
                  // Add the title field
                  _fields['${key}Title'] = FieldData(
                      TextEditingController(text: title), DataType.string);
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
    nameCtrl.dispose();
    titleCtrl.dispose();
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomTextField(
            label: key.toUpperCase(),
            controller: field.controller,
            hint: "Image URL",
            prefixIcon: Icons.link,
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              image: field.controller.text.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(field.controller.text),
                      fit: BoxFit.cover,
                      onError: (_, __) => const Icon(
                          Icons.broken_image), // Placeholder handling
                    )
                  : null,
            ),
            child: field.controller.text.isEmpty
                ? const Center(
                    child: Icon(Icons.image, size: 48, color: Colors.white24))
                : null,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            text: "Upload New Image",
            onPressed: () => _pickImage(field),
            icon: Icons.cloud_upload_outlined,
          ),
        ],
      );
    }

    return CustomTextField(
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
  }

  Widget _buildObjectListEditor(String key, FieldData field) {
    List<dynamic> items = [];
    try {
      items = jsonDecode(field.controller.text);
    } catch (e) {/* ignore */}

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
          final item = entry.value as Map<String, dynamic>;
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
                        field.controller.text = jsonEncode(items);
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

  void _editListItem(
      String key, List<dynamic> items, int index, FieldData field) {
    final isNew = index == -1;
    Map<String, dynamic> itemData = isNew
        ? _getTemplateForItem(key)
        : Map<String, dynamic>.from(items[index]);

    final controllers = <String, TextEditingController>{};
    itemData.forEach((k, v) {
      controllers[k] = TextEditingController(text: v.toString());
    });

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              title: Text(isNew ? "Add Item" : "Edit Item",
                  style: GoogleFonts.outfit(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: itemData.keys.map((k) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: CustomTextField(
                          label: k.toUpperCase(), controller: controllers[k]!),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
                TextButton(
                    onPressed: () {
                      final newItem = <String, dynamic>{};
                      controllers.forEach((k, v) {
                        // Try to keep types if possible, essentially for numbers
                        if (num.tryParse(v.text) != null &&
                            !v.text.contains(',')) {
                          // Generic check for level field in skills
                          if (k == 'level' && widget.docId == 'skills') {
                            newItem[k] = num.tryParse(v.text) ?? v.text;
                            return;
                          }
                        }
                        newItem[k] = v.text;
                      });

                      setState(() {
                        if (isNew) {
                          items.add(newItem);
                        } else {
                          items[index] = newItem;
                        }
                        field.controller.text = jsonEncode(items);
                      });
                      Navigator.pop(context);
                    },
                    child: const Text("Save",
                        style: TextStyle(color: AppTheme.primaryColor)))
              ],
            )).whenComplete(() {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    });
  }

  Map<String, dynamic> _getTemplateForItem(String key) {
    // Provide templates for known keys to ensure structure
    if (key == 'education') {
      return {"degree": "", "institution": "", "year": ""};
    }
    if (key == 'stats') return {"label": "", "value": ""};
    if (key == 'services') return {"id": "", "title": "", "description": ""};

    // Default template for ANY list in the SKILLS document
    if (widget.docId == 'skills') {
      return {"name": "", "level": "90"};
    }

    if (key == 'items') return {"label": "", "href": ""};
    if (key == 'socialLinks') return {"platform": "", "url": ""};

    return {"title": "", "description": ""}; // Generic fallback
  }
}
