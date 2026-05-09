import 'package:flutter/material.dart';

class AntecedenteHighlightTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData icon;

  const AntecedenteHighlightTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle = 'Confirma si ya se revisaron antecedentes.',
    this.icon = Icons.fact_check_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Colors.amber.shade900;

    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade800, width: 2),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        activeColor: accent,
        activeTrackColor: Colors.amber.shade300,
        secondary: Icon(icon, color: accent),
        title: Text(
          title,
          style: TextStyle(color: accent, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: accent, fontWeight: FontWeight.w700),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
