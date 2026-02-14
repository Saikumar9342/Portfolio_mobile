import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added import
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../services/cloudinary_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/gradient_card.dart';
import '../widgets/action_dialog.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final FirestoreService _service = FirestoreService();
  final Set<String> _selectedProjectIds = {};
  bool _isSelectionMode = false;

  void _enterSelectionMode(String docId) {
    setState(() {
      _isSelectionMode = true;
      _selectedProjectIds.add(docId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedProjectIds.clear();
    });
  }

  void _toggleSelection(String docId) {
    setState(() {
      if (_selectedProjectIds.contains(docId)) {
        _selectedProjectIds.remove(docId);
        if (_selectedProjectIds.isEmpty) {
          _exitSelectionMode();
        }
      } else {
        _selectedProjectIds.add(docId);
      }
    });
  }

  Future<void> _deleteSelectedProjects() async {
    ActionDialog.show(
      context,
      title: "Delete Projects?",
      message:
          "Are you sure you want to delete ${_selectedProjectIds.length} projects? This action cannot be undone.",
      confirmLabel: "DELETE ALL",
      type: ActionDialogType.danger,
      onConfirm: () async {
        final idsToDelete = List<String>.from(_selectedProjectIds);
        // Show loading or just process
        for (final id in idsToDelete) {
          await _service.deleteProject(id);
        }

        if (mounted) {
          _exitSelectionMode();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${idsToDelete.length} projects deleted'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        }
      },
      onCancel: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Hardcoded Admin Email for Legacy Data Access
    const adminEmail = "pasumarthisaikumar6266@gmail.com";

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              _isSelectionMode
                  ? '${_selectedProjectIds.length} Selected'
                  : 'Projects',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppTheme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            leading: _isSelectionMode
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _exitSelectionMode,
                  )
                : null,
            actions: [
              if (_isSelectionMode)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 28, color: AppTheme.errorColor),
                  onPressed: _deleteSelectedProjects,
                )
              else
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      size: 32, color: AppTheme.primaryColor),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProjectEditorScreen()),
                  ),
                ),
              const SizedBox(width: 16),
            ],
          ),
          StreamBuilder<QuerySnapshot>(
            stream: _service.streamProjects(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildErrorView(snapshot.error);
              }
              if (!snapshot.hasData) {
                return const SliverFillRemaining(
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryColor)),
                );
              }

              // Filter docs based on ownership or legacy admin access
              final allDocs = snapshot.data!.docs;
              final docs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final docUserId = data['userId'];

                // 1. If project has an owner, only show if it matches current user
                if (docUserId != null) {
                  return docUserId == user?.uid;
                }

                // 2. If project has NO owner (Legacy), only show to the specific Admin Email
                //    This prevents random new users from seeing old admin data.
                if (user?.email == adminEmail) {
                  return true;
                }

                return false;
              }).toList();

              if (docs.isEmpty) {
                return _buildEmptyView();
              }

              return _buildProjectList(docs);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(Object? error) {
    return SliverFillRemaining(
      child: Center(
        child: Text(
          'Error: $error',
          style: const TextStyle(color: AppTheme.errorColor),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open,
                size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No projects found',
                style: GoogleFonts.inter(
                    fontSize: 18, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectList(List<QueryDocumentSnapshot> docs) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final isSelected = _selectedProjectIds.contains(doc.id);

            return _ProjectCard(
              docId: doc.id,
              data: data,
              isSelected: isSelected,
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(doc.id);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProjectEditorScreen(docId: doc.id, initialData: data),
                    ),
                  );
                }
              },
              onLongPress: () => _enterSelectionMode(doc.id),
              onDelete: () => _confirmDelete(context, doc.id),
            );
          },
          childCount: docs.length,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    ActionDialog.show(
      context,
      title: "Delete Project?",
      message:
          "This action cannot be undone. Are you sure you want to delete this project?",
      confirmLabel: "DELETE",
      type: ActionDialogType.danger,
      onConfirm: () async {
        await _service.deleteProject(docId);
        if (context.mounted) {
          ActionDialog.show(
            context,
            title: "Project Deleted",
            message: "The project has been permanently removed.",
            onConfirm: () {},
          );
        }
      },
      onCancel: () {},
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;
  final bool isSelected;

  const _ProjectCard({
    required this.docId,
    required this.data,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GradientCard(
          padding: EdgeInsets.zero,
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: isSelected
                  ? Border.all(color: AppTheme.primaryColor, width: 2)
                  : Border.all(color: Colors.transparent),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['imageUrl'] != null &&
                    data['imageUrl'].toString().startsWith('http'))
                  Hero(
                    tag: 'project_image_$docId',
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                      child: Image.network(
                        data['imageUrl'],
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 180,
                          color: Colors.white10,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image,
                              size: 48, color: Colors.white24),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              data['title'] ?? 'Untitled',
                              style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary),
                            ),
                          ),
                          if (!isSelected) // Hide individual delete if selecting
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppTheme.errorColor),
                              onPressed: onDelete,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['description'] ?? 'No description',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 14, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (data['techStack'] as List<dynamic>? ?? [])
                            .take(3)
                            .map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              tag.toString(),
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isSelected)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.check, color: Colors.white, size: 20),
              ),
            ),
          ),
      ],
    );
  }
}

class ProjectEditorScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? initialData;

  const ProjectEditorScreen({super.key, this.docId, this.initialData});

  @override
  State<ProjectEditorScreen> createState() => _ProjectEditorScreenState();
}

class _ProjectEditorScreenState extends State<ProjectEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _techStackController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _categoryController = TextEditingController();
  final _roleController = TextEditingController();
  final _fullDescController = TextEditingController();
  final _liveLinkController = TextEditingController();
  final _githubLinkController = TextEditingController();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  bool _isSaving = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _titleController.text = widget.initialData!['title'] ?? '';
      _descController.text = widget.initialData!['description'] ?? '';
      _techStackController.text =
          (widget.initialData!['techStack'] as List<dynamic>?)?.join(', ') ??
              '';
      _imageUrlController.text = widget.initialData!['imageUrl'] ?? '';
      _categoryController.text = widget.initialData!['category'] ?? '';
      _roleController.text = widget.initialData!['role'] ?? '';
      _fullDescController.text = widget.initialData!['fullDescription'] ?? '';
      _liveLinkController.text = widget.initialData!['liveLink'] ?? '';
      _githubLinkController.text = widget.initialData!['githubLink'] ?? '';
    }

    // Add listeners to track changes
    void setDirty() {
      if (!_isDirty) setState(() => _isDirty = true);
    }

    _titleController.addListener(setDirty);
    _descController.addListener(setDirty);
    _techStackController.addListener(setDirty);
    _imageUrlController.addListener(setDirty);
    _categoryController.addListener(setDirty);
    _roleController.addListener(setDirty);
    _fullDescController.addListener(setDirty);
    _liveLinkController.addListener(setDirty);
    _githubLinkController.addListener(setDirty);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _techStackController.dispose();
    _imageUrlController.dispose();
    _categoryController.dispose();
    _roleController.dispose();
    _fullDescController.dispose();
    _liveLinkController.dispose();
    _githubLinkController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      final data = {
        'title': _titleController.text,
        'description': _descController.text,
        'fullDescription': _fullDescController.text,
        'role': _roleController.text,
        'category': _categoryController.text,
        'techStack': _techStackController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'imageUrl': _imageUrlController.text,
        'liveLink': _liveLinkController.text,
        'githubLink': _githubLinkController.text,
      };

      try {
        if (widget.docId != null) {
          await FirestoreService().updateProject(widget.docId!, data);
        } else {
          await FirestoreService().addProject(data);
        }
        if (mounted) {
          setState(() => _isDirty = false);
          ActionDialog.show(
            context,
            title: "Success",
            message: widget.docId == null
                ? "Your new project has been added successfully!"
                : "Project details have been updated.",
            onConfirm: () => Navigator.pop(context),
          );
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
              content: Text('Could not save project: $e',
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

  Future<void> _pickImage() async {
    final url = await _cloudinaryService.pickAndUploadImage();
    if (url != null) {
      setState(() {
        _imageUrlController.text = url;
      });
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
        appBar: AppBar(
          title: Text(widget.docId == null ? 'Add Project' : 'Edit Project'),
          backgroundColor: AppTheme.scaffoldBackgroundColor,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              CustomTextField(
                  label: "PROJECT TITLE",
                  controller: _titleController,
                  hint: "E.g. E-Commerce App"),
              const SizedBox(height: 20),
              CustomTextField(
                  label: "SHORT DESCRIPTION",
                  controller: _descController,
                  isMultiline: true,
                  hint: "A brief summary for the gallery..."),
              const SizedBox(height: 20),
              CustomTextField(
                  label: "FULL DESCRIPTION (DEEP DIVE)",
                  controller: _fullDescController,
                  isMultiline: true,
                  hint: "Detailed narrative for the case study..."),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                        label: "CATEGORY",
                        controller: _categoryController,
                        hint: "Design + Dev"),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                        label: "ROLE",
                        controller: _roleController,
                        hint: "Lead Designer"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              CustomTextField(
                  label: "TECH STACK",
                  controller: _techStackController,
                  hint: "Flutter, Firebase, React..."),
              const SizedBox(height: 20),

              // Image Upload Section
              Text("PROJECT COVER",
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Hero(
                tag: widget.docId != null
                    ? 'project_image_${widget.docId}'
                    : 'new_project_image',
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: AppTheme.inputFillColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                        image: _imageUrlController.text.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(_imageUrlController.text),
                                fit: BoxFit.cover)
                            : null),
                    child: _imageUrlController.text.isEmpty
                        ? const Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 32, color: AppTheme.primaryColor),
                                SizedBox(height: 8),
                                Text("Tap to upload image",
                                    style: TextStyle(
                                        color: AppTheme.textSecondary))
                              ]))
                        : null,
                  ),
                ),
              ),
              if (_imageUrlController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                      onPressed: () =>
                          setState(() => _imageUrlController.clear()),
                      child: const Text("Remove Image",
                          style: TextStyle(color: AppTheme.errorColor))),
                ),

              const SizedBox(height: 20),
              CustomTextField(
                  label: "LIVE LINK",
                  controller: _liveLinkController,
                  hint: "https://myapp.com",
                  prefixIcon: Icons.link),
              const SizedBox(height: 20),
              CustomTextField(
                  label: "GITHUB LINK",
                  controller: _githubLinkController,
                  hint: "https://github.com/...",
                  prefixIcon: Icons.code),

              const SizedBox(height: 40),
              PrimaryButton(
                text: "SAVE PROJECT",
                onPressed: _save,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
