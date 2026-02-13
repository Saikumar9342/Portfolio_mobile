import 'package:flutter/material.dart';
import 'package:portfolio_mobile/services/cloudinary_service.dart';
import '../services/firestore_service.dart';
import 'dart:convert';

enum DataType { string, stringList, json, image }

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
  final CloudinaryService _cloudinaryService = CloudinaryService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final snapshot =
          await FirestoreService().streamContent(widget.docId).first;

      Map<String, dynamic> fetchedData = {};
      if (snapshot.exists && snapshot.data() != null) {
        fetchedData = snapshot.data()!;
      }

      // Always get default data to ensure all fields are present
      final defaultData = _getDefaultData(widget.docId);

      // Merge fetched data into default data (fetched overrides default)
      final data = {...defaultData, ...fetchedData};

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
          if (value.isEmpty || (value.isNotEmpty && value.first is String)) {
            text = (value).join(', ');
            type = DataType.stringList;
          } else {
            text = const JsonEncoder.withIndent('  ').convert(value);
            type = DataType.json;
          }
        } else {
          // Handle null or other types gracefully
          if (value == null) {
            text = '';
          } else {
            text = const JsonEncoder.withIndent('  ').convert(value);
            type = DataType.json;
          }
        }
        _fields[key] = FieldData(TextEditingController(text: text), type);
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _getDefaultData(String docId) {
    switch (docId) {
      case 'hero':
        return {
          'title': 'Your Title',
          'subtitle': 'Your Subtitle',
          'badge': 'Badge Text',
          'cta': 'Click Me',
          'secondaryCta': 'Secondary Action',
          'imageUrl': '' // Add image URL field
        };
      case 'about':
        return {
          'title': 'About Me',
          'biography': 'Write your bio here...',
          'location': 'City, Country',
          'education': [], // JSON
          'interests': []
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
          // Use example data to ensure they are detected as JSON (list of objects) and not StringList
          'frontend': [
            {'name': 'React', 'level': 90}
          ],
          'mobile': ['Flutter', 'React Native'], // String List
          'backend': ['Node.js', 'Firebase'], // String List
          'tools': ['Git', 'VS Code'], // String List
          'frameworks': ['Next.js'] // String List
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
        return {'logoText': 'S', 'ctaText': 'Hire Me', 'items': []};
      default:
        return {'title': 'New Section'};
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
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
              data[key] = jsonDecode(field.controller.text);
              break;
          }
        } catch (e) {
          hasError = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error parsing field $key: $e')),
          );
        }
      });

      if (hasError) return;

      try {
        await FirestoreService().updateContent(widget.docId, data);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saved successfully')));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
        }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload failed. Check console for details.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _save)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _fields.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _buildField(entry.key, entry.value),
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildField(String key, FieldData field) {
    int maxLines = 1;
    String? hint;

    if (field.type == DataType.json) {
      maxLines = 10;
      hint = 'Enter valid JSON';
    } else if (field.type == DataType.string &&
        field.controller.text.length > 50) {
      maxLines = 3;
    } else if (field.type == DataType.stringList) {
      maxLines = 2;
      hint = 'Comma separated values';
    }

    Widget inputField = TextFormField(
      controller: field.controller,
      decoration: InputDecoration(
        labelText: key,
        hintText: hint,
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      maxLines: maxLines,
      validator: (value) {
        if (field.type == DataType.json) {
          try {
            jsonDecode(value!);
          } catch (e) {
            return 'Invalid JSON';
          }
        }
        return null;
      },
    );

    if (field.type == DataType.image) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          inputField,
          const SizedBox(height: 8),
          if (field.controller.text.isNotEmpty)
            Image.network(field.controller.text,
                height: 100,
                errorBuilder: (_, __, ___) => const Text("Invalid Image URL")),
          TextButton.icon(
              onPressed: () => _pickImage(field),
              icon: const Icon(Icons.cloud_upload),
              label: const Text("Upload New Image"))
        ],
      );
    }

    return inputField;
  }
}
