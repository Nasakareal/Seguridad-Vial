import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'normalized_integer_input_formatter.dart';

class ActividadCountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color color;
  final String? helperText;
  final String? badgeText;
  final int? max;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const ActividadCountField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.color,
    this.helperText,
    this.badgeText,
    this.max,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                softWrap: true,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: .32)),
                ),
                child: Text(
                  badgeText!,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: onChanged,
          inputFormatters: <TextInputFormatter>[
            NormalizedIntegerInputFormatter(max: max),
          ],
          decoration: InputDecoration(
            hintText: '0',
            helperText: helperText,
            helperMaxLines: 2,
            errorText: errorText,
            errorMaxLines: 3,
            filled: true,
            fillColor: color.withValues(alpha: .08),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: color.withValues(alpha: .82),
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: color, width: 3),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 3),
            ),
          ),
        ),
      ],
    );
  }
}
