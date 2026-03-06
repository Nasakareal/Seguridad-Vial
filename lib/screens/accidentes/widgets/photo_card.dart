import 'dart:io';
import 'package:flutter/material.dart';

class PhotoCard extends StatelessWidget {
  final String title;
  final File? file;
  final bool disabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const PhotoCard({
    super.key,
    required this.title,
    required this.file,
    required this.disabled,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            if (file == null)
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text('Sin imagen'),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Image.file(file!, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: disabled ? null : onPick,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Elegir'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (disabled || file == null) ? null : onClear,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Quitar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
