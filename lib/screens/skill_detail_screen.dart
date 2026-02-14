import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/action_dialog.dart';

class SkillDetailScreen extends StatefulWidget {
  final String sectionId;
  final String sectionTitleKey;

  const SkillDetailScreen({
    super.key,
    required this.sectionId,
    required this.sectionTitleKey,
  });

  @override
  State<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends State<SkillDetailScreen> {
  final FirestoreService _service = FirestoreService();
  bool _isLoading = true;
  List<dynamic> _items = [];
  String _currentTitle = "";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final doc = await _service.streamContent('skills').first;
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _items = List.from(data[widget.sectionId] ?? []);
          _currentTitle = data[widget.sectionTitleKey] ?? widget.sectionId;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading skill section: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges(List<dynamic> newItems, {String? newTitle}) async {
    try {
      final updates = <String, dynamic>{
        widget.sectionId: newItems,
      };
      if (newTitle != null) {
        updates[widget.sectionTitleKey] = newTitle;
      }

      await _service.updateContent('skills', updates);

      if (mounted) {
        setState(() {
          _items = newItems;
          if (newTitle != null) {
            _currentTitle = newTitle;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Changes saved"),
              backgroundColor: AppTheme.surfaceColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ActionDialog.show(context,
            title: "Error",
            message: "Failed to save: $e",
            type: ActionDialogType.danger,
            onConfirm: () {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_currentTitle,
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
            onPressed: _editSectionTitle,
            tooltip: "Edit Section Title",
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
            onPressed: () => _confirmDeleteSection(context),
            tooltip: "Delete Section",
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Column(
              children: [
                Expanded(
                  child: _items.isEmpty
                      ? Center(
                          child: Text("No skills in this section yet.",
                              style: TextStyle(
                                  color: AppTheme.textSecondary
                                      .withValues(alpha: 0.5))))
                      : ReorderableListView(
                          padding: const EdgeInsets.all(20),
                          onReorder: (oldIndex, newIndex) {
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            final item = _items.removeAt(oldIndex);
                            _items.insert(newIndex, item);
                            _saveChanges(_items); // Auto-save on reorder
                          },
                          children: [
                            for (int i = 0; i < _items.length; i++)
                              _buildSkillTile(i, _items[i])
                          ],
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: PrimaryButton(
                      text: "ADD SKILL",
                      icon: Icons.add,
                      onPressed: () => _addOrEditItem(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSkillTile(int index, dynamic item) {
    // Determine if it's a simple string or an object {name, level}
    final isObject = item is Map;
    final name = isObject ? (item['name'] ?? item.toString()) : item.toString();
    final level = isObject ? item['level'] : null;
    final iconName = isObject ? item['icon'] : null;

    return Container(
      key: ValueKey(item), // Important for ReorderableListView
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.inputFillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: iconName != null
            ? Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getIconData(iconName as String),
                    color: AppTheme.primaryColor, size: 20),
              )
            : const Icon(Icons.drag_indicator, color: Colors.white24),
        title: Text(name.toString(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: level != null
            ? Text("$level%",
                style: const TextStyle(color: AppTheme.primaryColor))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white70),
              onPressed: () => _addOrEditItem(index: index, currentItem: item),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: AppTheme.errorColor),
              onPressed: () {
                final newItems = List.from(_items)..removeAt(index);
                _saveChanges(newItems);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSectionTitle() async {
    final ctrl = TextEditingController(text: _currentTitle);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text("Edit Section Title",
            style: GoogleFonts.outfit(color: Colors.white)),
        content: CustomTextField(label: "TITLE", controller: ctrl),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                _saveChanges(_items, newTitle: ctrl.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text("Save",
                style: TextStyle(color: AppTheme.primaryColor)),
          )
        ],
      ),
    );
  }

  Future<void> _addOrEditItem({int? index, dynamic currentItem}) async {
    // Detect type preference based on existing items, or default to Object for "Frontend" etc.
    // Ideally we ask user, or infer.
    // If list is empty, we default to "Simple Tag" unless it's a known section like 'frontend' which uses levels.

    // Heuristic: If existing items are Maps, use Map editor. Else use String editor.
    // If empty: Check common keys.
    bool useRichEditor = false;
    if (_items.isNotEmpty) {
      useRichEditor = _items.first is Map;
    } else {
      // Known rich sections
      if (['frontend', 'items'].contains(widget.sectionId)) {
        useRichEditor = true;
      }
    }

    final nameCtrl = TextEditingController();
    final levelCtrl = TextEditingController(); // For rich editor

    String selectedIcon = 'Code2';

    if (currentItem != null) {
      if (currentItem is Map) {
        nameCtrl.text = currentItem['name'] ?? '';
        levelCtrl.text = (currentItem['level'] ?? '').toString();
        selectedIcon = currentItem['icon'] ?? 'Code2';
        useRichEditor = true;
      } else {
        nameCtrl.text = currentItem.toString();
        useRichEditor = false;
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          // Use StatefulBuilder to toggle modes if we want, but keeping simple for now
          builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text(index == null ? "Add Skill" : "Edit Skill",
              style: GoogleFonts.outfit(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_items.isEmpty) ...[
                // Toggle between Tag vs Rich
                Row(
                  children: [
                    const Text("Include Proficiency %?",
                        style: TextStyle(color: Colors.white70)),
                    Switch(
                      value: useRichEditor,
                      onChanged: (val) {
                        setDialogState(() => useRichEditor = val);
                      },
                      activeTrackColor:
                          AppTheme.primaryColor.withValues(alpha: 0.5),
                      activeThumbColor: AppTheme.primaryColor,
                    )
                  ],
                ),
                const SizedBox(height: 16),
              ],
              CustomTextField(
                  label: "SKILL NAME",
                  controller: nameCtrl,
                  hint: "e.g. React"),
              if (useRichEditor) ...[
                const SizedBox(height: 16),
                Text("ICON",
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
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
                      onTap: () =>
                          setDialogState(() => selectedIcon = iconName),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.inputFillColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.white10),
                        ),
                        child: Icon(_getIconData(iconName),
                            color: isSelected ? Colors.white : Colors.white70,
                            size: 20),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                    label: "PROFICIENCY (%)",
                    controller: levelCtrl,
                    hint: "e.g. 90",
                    keyboardType: TextInputType.number),
              ]
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel")),
            TextButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty) {
                  return;
                }

                dynamic newItem;
                if (useRichEditor) {
                  newItem = {
                    'name': nameCtrl.text,
                    'level': int.tryParse(levelCtrl.text) ?? 80,
                    'icon': selectedIcon,
                  };
                } else {
                  newItem = nameCtrl.text;
                }

                final newItems = List.from(_items);
                if (index == null) {
                  newItems.add(newItem);
                } else {
                  newItems[index] = newItem;
                }

                _saveChanges(newItems);
                Navigator.pop(ctx);
              },
              child: const Text("Save",
                  style: TextStyle(color: AppTheme.primaryColor)),
            )
          ],
        );
      }),
    );
  }

  void _confirmDeleteSection(BuildContext context) {
    ActionDialog.show(
      context,
      title: "Delete Section?",
      message:
          "This will effectively hide this section. You can delete the data permanently or just remove the title ref.",
      confirmLabel: "DELETE PERMANENTLY",
      type: ActionDialogType.danger,
      onConfirm: () async {
        // We delete both the Key and the KeyTitle
        await _service.updateContent('skills', {
          widget.sectionId: FieldValue.delete(),
          widget.sectionTitleKey: FieldValue.delete(),
        });
        if (context.mounted) {
          Navigator.pop(context); // Close dialog
          Navigator.pop(context); // Go back to manager
        }
      },
      onCancel: () {},
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
