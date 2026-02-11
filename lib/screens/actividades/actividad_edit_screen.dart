import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/actividades_service.dart';
import '../../models/actividad.dart';
import '../../models/actividad_categoria.dart';
import '../../models/actividad_subcategoria.dart';

class ActividadEditScreen extends StatefulWidget {
  const ActividadEditScreen({super.key});

  @override
  State<ActividadEditScreen> createState() => _ActividadEditScreenState();
}

class _ActividadEditScreenState extends State<ActividadEditScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  Actividad? _actividad;

  List<ActividadCategoria> _categorias = [];
  List<ActividadSubcategoria> _subcategorias = [];

  int? _categoriaId;
  int? _subcategoriaId;

  File? _fotoNueva;

  int? _idFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final v = args['actividad_id'] ?? args['id'];
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '');
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final id = _idFromArgs();
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'Falta actividad_id';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cats = await ActividadesService.fetchCategorias();
      final a = await ActividadesService.fetchShow(id);

      if (!mounted) return;

      setState(() {
        _categorias = cats;
        _actividad = a;

        _categoriaId = a.actividadCategoriaId;
        _subcategoriaId = a.actividadSubcategoriaId;

        _loading = false;
      });

      if (_categoriaId != null) {
        await _loadSubcategorias(_categoriaId!);
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar.\n$e';
      });
    }
  }

  Future<void> _loadSubcategorias(int categoriaId) async {
    try {
      final subs = await ActividadesService.fetchSubcategorias(categoriaId);
      if (!mounted) return;

      setState(() {
        _subcategorias = subs;
        if (_subcategoriaId != null) {
          final exists = subs.any((s) => s.id == _subcategoriaId);
          if (!exists) _subcategoriaId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _subcategorias = [];
        _subcategoriaId = null;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (x == null) return;

    setState(() {
      _fotoNueva = File(x.path);
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    final a = _actividad;
    if (a == null) return;

    if (_categoriaId == null || _categoriaId! <= 0) {
      setState(() => _error = 'Selecciona una categoría.');
      return;
    }

    if (_saving) return;
    setState(() => _saving = true);

    try {
      await ActividadesService.update(
        id: a.id,
        actividadCategoriaId: _categoriaId!,
        actividadSubcategoriaId: _subcategoriaId,
        foto: _fotoNueva,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo actualizar.\n$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _currentPhoto(Actividad a) {
    if (_fotoNueva != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.file(_fotoNueva!, fit: BoxFit.cover),
        ),
      );
    }

    final p = (a.fotoPath ?? '').trim();
    if (p.isEmpty) {
      return Container(
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
      );
    }

    final url = ActividadesService.toPublicUrl(p);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey.shade200,
            child: const Center(child: Text('No se pudo cargar la imagen.')),
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = _actividad;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Editar actividad'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _bootstrap),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(_error!)
            else if (a == null)
              const Text('Sin datos.')
            else ...[
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
                    _currentPhoto(a),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _pickImage,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Cambiar foto'),
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
                    : const Text('Guardar cambios'),
              ),
            ],
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
