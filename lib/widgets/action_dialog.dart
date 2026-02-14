import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'primary_button.dart';

enum ActionDialogType { success, warning, danger }

class ActionDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final ActionDialogType type;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const ActionDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = "CONTINUE",
    this.cancelLabel = "CANCEL",
    this.type = ActionDialogType.success,
    required this.onConfirm,
    this.onCancel,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = "CONTINUE",
    String cancelLabel = "CANCEL",
    ActionDialogType type = ActionDialogType.success,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: type != ActionDialogType.danger,
      builder: (context) => ActionDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        type: type,
        onConfirm: onConfirm,
        onCancel: onCancel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color primaryColor;
    IconData icon;

    switch (type) {
      case ActionDialogType.warning:
        primaryColor = Colors.orangeAccent;
        icon = Icons.warning_amber_rounded;
        break;
      case ActionDialogType.danger:
        primaryColor = AppTheme.errorColor;
        icon = Icons.report_problem_outlined;
        break;
      case ActionDialogType.success:
        primaryColor = AppTheme.primaryColor;
        icon = Icons.check_circle_outline;
        break;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: primaryColor,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Column(
              children: [
                PrimaryButton(
                  text: confirmLabel,
                  onPressed: () {
                    Navigator.pop(context, true);
                    onConfirm();
                  },
                ),
                if (onCancel != null || type != ActionDialogType.success) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                        if (onCancel != null) onCancel!();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        cancelLabel,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
