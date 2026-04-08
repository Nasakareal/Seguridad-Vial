import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/vialidades_urbanas_dispositivo.dart';
import '../../services/auth_service.dart';
import '../../services/vialidades_urbanas_detalles_form_service.dart';
import '../../services/vialidades_urbanas_detalles_service.dart';
import '../../services/vialidades_urbanas_service.dart';

class VialidadesUrbanasDispositivoFormScreen extends StatefulWidget {
  final int dispositivoId;
  final bool isEditing;

  const VialidadesUrbanasDispositivoFormScreen({
    super.key,
    required this.dispositivoId,
    required this.isEditing,
  });

  @override
  State<VialidadesUrbanasDispositivoFormScreen> createState() =>
      _VialidadesUrbanasDispositivoFormScreenState();
}

class _VialidadesUrbanasDispositivoFormScreenState
    extends State<VialidadesUrbanasDispositivoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  bool _hasAccess = false;
  String? _error;

  VialidadesUrbanasDispositivo? _dispositivo;
  final List<_DetalleDraft> _detalles = <_DetalleDraft>[];
  final List<File> _fotosNuevas = <File>[];
  final Set<int> _eliminarFotoIds = <int>{};
  int? _fotoPortadaId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bootstrap();
    });
  }

  @override
  void dispose() {
    for (final detalle in _detalles) {
      detalle.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final isVialidadesUser = await AuthService.isVialidadesUrbanasUser(
        refresh: true,
      );
      final permission = widget.isEditing
          ? 'editar operativos vialidades'
          : 'crear operativos vialidades';
      final canAccess = await AuthService.can(permission);

      if (!isVialidadesUser || !canAccess) {
        throw Exception('No tienes acceso a esta captura operativa.');
      }

      final dispositivo =
          await VialidadesUrbanasDetallesService.fetchDispositivo(
            dispositivoId: widget.dispositivoId,
          );

      if (!mounted) return;

      _dispositivo = dispositivo;
      _detalles.clear();

      if (widget.isEditing) {
        if (dispositivo.detalles.isEmpty) {
          _detalles.add(_DetalleDraft.blank());
        } else {
          for (final detalle in dispositivo.detalles) {
            _detalles.add(_DetalleDraft.fromModel(detalle));
          }
        }

        final portada = dispositivo.fotos.where((foto) => foto.portada);
        _fotoPortadaId = portada.isNotEmpty ? portada.first.id : null;
      } else {
        _detalles.add(_DetalleDraft.blank());
      }

      setState(() {
        _hasAccess = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasAccess = false;
        _loading = false;
        _error = '$e';
      });
    }
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  String _shortHour(String raw) {
    final value = raw.trim();
    if (value.length >= 5) return value.substring(0, 5);
    return value;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _fotosNuevas.add(File(picked.path)));
  }

  void _addDetalle() {
    setState(() => _detalles.add(_DetalleDraft.blank()));
  }

  void _removeDetalle(int index) {
    if (_detalles.length == 1) {
      _detalles[index].clear();
      setState(() {});
      return;
    }

    final draft = _detalles.removeAt(index);
    draft.dispose();
    setState(() {});
  }

  Future<void> _pickDetalleHora(_DetalleDraft detalle) async {
    final initial = detalle.hora ?? const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked == null) return;
    setState(() => detalle.hora = picked);
  }

  int? _firstRemainingFotoId() {
    final dispositivo = _dispositivo;
    if (dispositivo == null) return null;

    for (final foto in dispositivo.fotos) {
      if (!_eliminarFotoIds.contains(foto.id)) {
        return foto.id;
      }
    }

    return null;
  }

  void _toggleEliminarFoto(int fotoId) {
    setState(() {
      if (_eliminarFotoIds.contains(fotoId)) {
        _eliminarFotoIds.remove(fotoId);
      } else {
        _eliminarFotoIds.add(fotoId);
        if (_fotoPortadaId == fotoId) {
          _fotoPortadaId = _firstRemainingFotoId();
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_saving) return;

    final payload = VialidadesUrbanasDetallesFormPayload(
      dispositivoId: widget.dispositivoId,
      detalles: _detalles.map((detalle) => detalle.toInput()).toList(),
      fotosNuevas: List<File>.from(_fotosNuevas),
      eliminarFotoIds: _eliminarFotoIds.toList(),
      fotoPortadaId: _fotoPortadaId,
    );

    final validation =
        await VialidadesUrbanasDetallesFormService.validateBeforeSubmit(
          payload: payload,
        );

    if (validation != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validation)));
      return;
    }

    setState(() => _saving = true);

    try {
      final result = widget.isEditing
          ? await VialidadesUrbanasDetallesFormService.update(payload: payload)
          : await VialidadesUrbanasDetallesFormService.create(payload: payload);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dispositivo = _dispositivo;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: Text(
          widget.isEditing
              ? 'Editar informacion operativa'
              : 'Captura operativa del dispositivo',
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : !_hasAccess || dispositivo == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error ?? 'No fue posible cargar la captura operativa.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _card(
                      title: 'Dispositivo padre',
                      child: Column(
                        children: [
                          _ReadOnlyRow(label: 'ID', value: '${dispositivo.id}'),
                          _ReadOnlyRow(
                            label: 'Fecha',
                            value: dispositivo.fecha.isEmpty
                                ? '—'
                                : dispositivo.fecha,
                          ),
                          _ReadOnlyRow(
                            label: 'Hora',
                            value: dispositivo.hora.isEmpty
                                ? '—'
                                : _shortHour(dispositivo.hora),
                          ),
                          _ReadOnlyRow(
                            label: 'Catalogo',
                            value: dispositivo.catalogoNombre,
                          ),
                          _ReadOnlyRow(
                            label: 'Asunto',
                            value: dispositivo.asunto.isEmpty
                                ? 'SIN ASUNTO'
                                : dispositivo.asunto,
                          ),
                          _ReadOnlyRow(
                            label: 'Municipio',
                            value: dispositivo.municipio.isEmpty
                                ? '—'
                                : dispositivo.municipio,
                          ),
                          _ReadOnlyRow(
                            label: 'Lugar',
                            value: dispositivo.lugar.isEmpty
                                ? '—'
                                : dispositivo.lugar,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      title: 'Detalles de lo realizado',
                      child: Column(
                        children: [
                          ...List<Widget>.generate(_detalles.length, (index) {
                            final detalle = _detalles[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Detalle ${index + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              _removeDetalle(index),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: detalle.tipoCtrl,
                                      decoration: _dec('Tipo'),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: detalle.tituloCtrl,
                                      decoration: _dec('Titulo'),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: detalle.ubicacionCtrl,
                                      decoration: _dec('Ubicacion'),
                                    ),
                                    const SizedBox(height: 12),
                                    InkWell(
                                      onTap: () => _pickDetalleHora(detalle),
                                      borderRadius: BorderRadius.circular(14),
                                      child: InputDecorator(
                                        decoration: _dec('Hora'),
                                        child: Text(
                                          detalle.hora == null
                                              ? 'Seleccionar'
                                              : _shortHour(
                                                  '${detalle.hora!.hour.toString().padLeft(2, '0')}:${detalle.hora!.minute.toString().padLeft(2, '0')}',
                                                ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: detalle.contenidoCtrl,
                                      minLines: 4,
                                      maxLines: 5,
                                      decoration: _dec('Contenido'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _addDetalle,
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar detalle'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.isEditing)
                      _card(
                        title: 'Fotos existentes',
                        child: dispositivo.fotos.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('Este dispositivo no tiene fotos.'),
                              )
                            : Column(
                                children: dispositivo.fotos.map((foto) {
                                  final marcada = _eliminarFotoIds.contains(
                                    foto.id,
                                  );
                                  final url =
                                      VialidadesUrbanasService.toPublicUrl(
                                        foto.ruta,
                                      );

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: marcada
                                            ? const Color(0xFFFEE2E2)
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: marcada
                                              ? const Color(0xFFFCA5A5)
                                              : Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Image.network(
                                              url,
                                              height: 180,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                    height: 180,
                                                    color: const Color(
                                                      0xFFE2E8F0,
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: const Icon(
                                                      Icons.image_not_supported,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _toggleEliminarFoto(
                                                        foto.id,
                                                      ),
                                                  icon: Icon(
                                                    marcada
                                                        ? Icons.restore
                                                        : Icons.delete_outline,
                                                  ),
                                                  label: Text(
                                                    marcada
                                                        ? 'Restaurar'
                                                        : 'Eliminar',
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: marcada
                                                      ? null
                                                      : () {
                                                          setState(() {
                                                            _fotoPortadaId =
                                                                foto.id;
                                                          });
                                                        },
                                                  icon: Icon(
                                                    _fotoPortadaId == foto.id
                                                        ? Icons.star
                                                        : Icons.star_border,
                                                  ),
                                                  label: Text(
                                                    _fotoPortadaId == foto.id
                                                        ? 'Portada'
                                                        : 'Usar portada',
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    if (widget.isEditing) const SizedBox(height: 12),
                    _card(
                      title: 'Fotos nuevas',
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _pickPhoto(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('Galeria'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _pickPhoto(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Camara'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_fotosNuevas.isEmpty)
                            const Text('Todavia no agregas fotos nuevas.')
                          else
                            SizedBox(
                              height: 96,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _fotosNuevas.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final foto = _fotosNuevas[index];
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.file(
                                          foto,
                                          width: 96,
                                          height: 96,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        right: 4,
                                        top: 4,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _fotosNuevas.removeAt(index);
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _saving
                            ? 'Guardando...'
                            : widget.isEditing
                            ? 'Guardar cambios'
                            : 'Guardar informacion',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetalleDraft {
  final TextEditingController tipoCtrl;
  final TextEditingController tituloCtrl;
  final TextEditingController contenidoCtrl;
  final TextEditingController ubicacionCtrl;
  TimeOfDay? hora;

  _DetalleDraft({
    required this.tipoCtrl,
    required this.tituloCtrl,
    required this.contenidoCtrl,
    required this.ubicacionCtrl,
    required this.hora,
  });

  factory _DetalleDraft.blank() {
    return _DetalleDraft(
      tipoCtrl: TextEditingController(text: 'texto'),
      tituloCtrl: TextEditingController(),
      contenidoCtrl: TextEditingController(),
      ubicacionCtrl: TextEditingController(),
      hora: null,
    );
  }

  factory _DetalleDraft.fromModel(VialidadesUrbanasDispositivoDetalle detalle) {
    TimeOfDay? parsedTime;
    final raw = detalle.hora.trim();
    final parts = raw.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        parsedTime = TimeOfDay(hour: hour, minute: minute);
      }
    }

    return _DetalleDraft(
      tipoCtrl: TextEditingController(
        text: detalle.tipo.isEmpty ? 'texto' : detalle.tipo,
      ),
      tituloCtrl: TextEditingController(text: detalle.titulo),
      contenidoCtrl: TextEditingController(text: detalle.contenido),
      ubicacionCtrl: TextEditingController(text: detalle.ubicacion),
      hora: parsedTime,
    );
  }

  void clear() {
    tipoCtrl.text = 'texto';
    tituloCtrl.clear();
    contenidoCtrl.clear();
    ubicacionCtrl.clear();
    hora = null;
  }

  VialidadesUrbanasDetalleInput toInput() {
    return VialidadesUrbanasDetalleInput(
      tipo: tipoCtrl.text,
      titulo: tituloCtrl.text,
      contenido: contenidoCtrl.text,
      ubicacion: ubicacionCtrl.text,
      hora: hora,
    );
  }

  void dispose() {
    tipoCtrl.dispose();
    tituloCtrl.dispose();
    contenidoCtrl.dispose();
    ubicacionCtrl.dispose();
  }
}
