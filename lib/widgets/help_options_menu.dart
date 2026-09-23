import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Selector de ayudas que respeta la navegación del sistema y puede desplazarse.
class HelpOptionsMenu extends StatelessWidget {
  final String description;
  final List<Widget> children;

  const HelpOptionsMenu({
    super.key,
    required this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewInsets.bottom;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.max(240, availableHeight * .78),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + media.viewPadding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.help_outline, color: Colors.blue, size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¿En qué necesitas ayuda?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(description, style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
