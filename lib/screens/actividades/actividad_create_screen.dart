import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/actividades_service.dart';
import '../../models/actividad_categoria.dart';
import '../../models/actividad_subcategoria.dart';

class ActividadCreateScreen extends StatefulWidget {
  const ActividadCreateScreen({super.key});

  @override
  State<ActividadCreateScreen> createState() => _ActividadCreateScreenState();
}

class _ActividadCreateScreenState extends State<ActividadCreateScreen> {
  bool _saving = false;
  String? _error;

  List<ActividadCategoria> _categorias = [];
  List<ActividadSubcategoria> _subcategorias = [];

  int? _categoriaId;
  int? _subcategoriaId;

  File? _foto;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCategorias();
  }

  Future<void> _loadCategorias() async {
    try {
      final cats = await ActividadesService.fetchCategorias();
      if (!mounted) return;
      setState(() => _categorias = cats);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudieron cargar categorías.\n$e');
    }
  }

  Future<void> _loadSubcategorias(int categoriaId) async {
    setState(() {
      _subcategorias = [];
      _subcategoriaId = null;
    });

    try {
      final subs = await ActividadesService.fetchSubcategorias(categoriaId);
      if (!mounted) return;
      setState(() => _subcategorias = subs);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudieron cargar subcategorías.\n$e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _error = null);

    final x = await _picker.pickImage(source: source, imageQuality: 85);
    if (x == null) return;

    setState(() {
      _foto = File(x.path);
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    if (_categoriaId == null || _categoriaId! <= 0) {
      setState(() => _error = 'Selecciona una categoría.');
      return;
    }

    if (_foto == null) {
      setState(() => _error = 'Selecciona una foto (obligatoria).');
      return;
    }

    if (_saving) return;
    setState(() => _saving = true);

    try {
      await ActividadesService.create(
        actividadCategoriaId: _categoriaId!,
        actividadSubcategoriaId: _subcategoriaId,
        foto: _foto!,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo crear.\n$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Crear actividad'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withOpacity(.2)),
                ),
                child: Text(_error!),
              ),
            if (_error != null) const SizedBox(height: 12),

            _card(
              title: 'Datos',
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    value: _categoriaId,
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Seleccione categoría…'),
                      ),
                      ..._categorias.map(
                        (c) => DropdownMenuItem<int>(
                          value: c.id,
                          child: Text(c.nombre),
                        ),
                      ),
                    ],
                    onChanged: (v) async {
                      setState(() {
                        _categoriaId = v;
                        _subcategoriaId = null;
                        _subcategorias = [];
                      });
                      if (v != null) {
                        await _loadSubcategorias(v);
                      }
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _subcategoriaId,
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Subcategoría (opcional)…'),
                      ),
                      ..._subcategorias.map(
                        (s) => DropdownMenuItem<int>(
                          value: s.id,
                          child: Text(s.nombre),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _subcategoriaId = v),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _card(
              title: 'Foto',
              child: Column(
                children: [
                  if (_foto != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.file(_foto!, fit: BoxFit.cover),
                      ),
                    )
                  else
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Center(
                        child: Text(
                          'Sin foto',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galería'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Cámara'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(.06),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
