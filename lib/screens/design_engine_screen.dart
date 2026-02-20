import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_card.dart';
import '../services/firestore_service.dart';
import '../widgets/action_dialog.dart';

class DesignEngineScreen extends StatefulWidget {
  const DesignEngineScreen({super.key});

  @override
  State<DesignEngineScreen> createState() => _DesignEngineScreenState();
}

class _DesignEngineScreenState extends State<DesignEngineScreen> {
  // Theme selection
  String _selectedTheme = "auto";
  bool _showHeroImage = true;
  bool _isLoading = true;
  bool _isSaving = false;

  // Layout Order
  List<String> _layoutOrder = [
    "hero",
    "about",
    "projects",
    "expertise",
    "skills"
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirestoreService().streamDesignSettings().first;
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _selectedTheme = data['theme'] ?? "auto";
          _showHeroImage = data['showHeroImage'] ?? true;
          if (data['layoutOrder'] is List) {
            _layoutOrder = List<String>.from(data['layoutOrder']);
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading design settings: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await FirestoreService().saveDesignSettings({
        'theme': _selectedTheme,
        'showHeroImage': _showHeroImage,
        'layoutOrder': _layoutOrder,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Design settings saved successfully.",
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ActionDialog.show(context,
            title: "Error",
            message: "Failed to save settings: $e",
            type: ActionDialogType.danger,
            onConfirm: () {});
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Design Engine',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 20),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primaryColor)),
            )
          else
            IconButton(
              icon: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.primaryColor, size: 28),
              onPressed: _saveSettings,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Global Theme",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary.withOpacity(0.5),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GradientCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildThemeOption(
                            "Auto (Image Colors)", "auto", Icons.image_rounded),
                        _buildThemeOption(
                            "Dark Minimalist", "dark", Icons.dark_mode_rounded),
                        _buildThemeOption(
                            "Light Theme", "light", Icons.light_mode_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "Hero Section Settings",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary.withOpacity(0.5),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GradientCard(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: SwitchListTile(
                      title: Text(
                        "Show Hero Image",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      activeThumbColor: AppTheme.primaryColor,
                      value: _showHeroImage,
                      onChanged: (val) {
                        setState(() => _showHeroImage = val);
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "Section Layout Order",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary.withOpacity(0.5),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GradientCard(
                    padding: const EdgeInsets.all(20),
                    child: ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (int index = 0;
                            index < _layoutOrder.length;
                            index += 1)
                          Container(
                            key: Key(_layoutOrder[index]),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.1)),
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.drag_indicator_rounded,
                                  color: Colors.grey),
                              title: Text(
                                _layoutOrder[index].toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                      onReorder: (int oldIndex, int newIndex) {
                        setState(() {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }
                          final String item = _layoutOrder.removeAt(oldIndex);
                          _layoutOrder.insert(newIndex, item);
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildThemeOption(String title, String id, IconData icon) {
    final isSelected = _selectedTheme == id;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTheme = id;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor.withOpacity(0.5)
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? AppTheme.primaryColor : Colors.white54,
                size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: isSelected ? AppTheme.primaryColor : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.primaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}
