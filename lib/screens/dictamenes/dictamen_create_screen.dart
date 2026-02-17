import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/dictamenes_service.dart';

class DictamenCreateScreen extends StatefulWidget {
  const DictamenCreateScreen({super.key});

  @override
  State<DictamenCreateScreen> createState() => _DictamenCreateScreenState();
}

class _DictamenCreateScreenState extends State<DictamenCreateScreen> {
  final _svc = DictamenesService();

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nombrePolicia = TextEditingController();
  final TextEditingController _nombreMp = TextEditingController();

  bool _busy = false;
  String? _error;

  File? _pdf;
  String? _pdfName;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _nombrePolicia.dispose();
    _nombreMp.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    // Usamos image_picker porque ya lo traes en el proyecto.
    // Para PDF normalmente lo ideal es file_picker, pero aquí lo resolvemos con lo que ya tienes:
    // En Android/iOS recientes, pickMedia puede permitir seleccionar documentos según proveedor.
    // Si tu dispositivo no deja escoger PDF, te paso versión con file_picker.
    try {
      final x = await _picker.pickMedia(); // puede abrir selector de archivos
      if (x == null) return;

      final path = x.path;
      if (!path.toLowerCase().endsWith('.pdf')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona un archivo .pdf')),
        );
        return;
      }

      setState(() {
        _pdf = File(path);
        _pdfName = path.split(Platform.pathSeparator).last;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar el archivo: $e')),
      );
    }
  }

  void _removePdf() {
    setState(() {
      _pdf = null;
      _pdfName = null;
    });
  }

  Future<void> _save() async {
    if (_busy) return;

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final res = await _svc.store(
        nombrePolicia: _nombrePolicia.text.trim(),
        nombreMp: _nombreMp.text.trim(),
        archivoPdf: _pdf,
      );

      if (!mounted) return;

      final numero = (res['data']?['numero_dictamen'] ?? '').toString();
      final anio = (res['data']?['anio'] ?? '').toString();
      final area = (res['area_autollenada'] ?? '').toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Dictamen creado: $numero/$anio • Área: ${area.isEmpty ? '—' : area}',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo dictamen')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    color: Colors.black.withOpacity(.04),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_error != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.error_outline),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextFormField(
                      controller: _nombrePolicia,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del policía',
                        hintText: 'Ej: JUAN PÉREZ GARCÍA',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'Este campo es obligatorio';
                        if (s.length > 100) return 'Máximo 100 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nombreMp,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del MP',
                        hintText: 'Ej: MARÍA LÓPEZ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.length > 100) return 'Máximo 100 caracteres';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Archivo (opcional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _pdf == null
                                ? Icons.picture_as_pdf_outlined
                                : Icons.picture_as_pdf,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _pdfName == null ? 'Sin archivo' : _pdfName!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_pdf == null)
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _pickPdf,
                              icon: const Icon(Icons.attach_file),
                              label: const Text('Elegir PDF'),
                            )
                          else ...[
                            IconButton(
                              tooltip: 'Quitar',
                              onPressed: _busy ? null : _removePdf,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_busy ? 'Guardando...' : 'Crear dictamen'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
