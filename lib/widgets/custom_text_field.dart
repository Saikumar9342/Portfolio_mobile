import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool isMultiline;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscureText;
  final bool enabled;
  final void Function(String)? onChanged;

  const CustomTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.isMultiline = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
                letterSpacing: 1.2,
              ),
            ),
          ),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: isMultiline ? 5 : 1,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon,
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    size: 20)
                : null,
            suffixIcon: suffixIcon != null
                ? IconButton(
                    icon: Icon(suffixIcon,
                        color: AppTheme.primaryColor, size: 20),
                    onPressed: onSuffixTap,
                  )
                : null,
            filled: true,
            fillColor: AppTheme.inputFillColor,
          ),
          validator: validator,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
