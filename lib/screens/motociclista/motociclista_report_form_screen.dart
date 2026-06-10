import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/actividad_share_service.dart';
import '../../services/auth_service.dart';
import '../../services/geo_service.dart';
import '../../services/motociclista_report_service.dart';
import '../../services/photo_picker_service.dart';

class MotociclistaReportFormScreen extends StatefulWidget {
  const MotociclistaReportFormScreen({super.key});

  @override
  State<MotociclistaReportFormScreen> createState() =>
      _MotociclistaReportFormScreenState();
}

class _MotociclistaReportFormScreenState
    extends State<MotociclistaReportFormScreen>
    with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  final List<File> _fotos = <File>[];
  final _fechaCtrl = TextEditingController();
  final _horaCtrl = TextEditingController();
  final _ubicacionCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _coordenadasCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  MotociclistaReportKind _kind = MotociclistaReportKind.abanderamiento;
  String _tipoPreliminar = 'Choque';
  String _lesionados = 'Se desconoce';
  String _estado = 'En espera de UAS';
  String _apoyoMotivo = 'Apoyo a la vialidad';
  String _tipoCierre = 'Parcial';
  String _cierreMotivo = 'Hecho de tránsito';
  String _estadoCirculacion = 'Con precaución';
  String _dispositivoMotivo = 'Paso continuo';
  String _zonaMonitoreada = 'Avenidas';
  String _kilometros = '0';
  String _informa = 'Águilas Motocicletas';
  var _elementos = 1;
  var _locating = false;
  var _saving = false;
  var _routeLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setNow();
    _loadReporter();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeLoaded) return;
    _routeLoaded = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is MotociclistaReportKind) {
      _kind = args;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fechaCtrl.dispose();
    _horaCtrl.dispose();
    _ubicacionCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _coordenadasCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await ActividadShareService.onAppResumed();
    }
  }

  void _setNow() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    _fechaCtrl.text = '${now.year}-${two(now.month)}-${two(now.day)}';
    _horaCtrl.text = '${two(now.hour)}:${two(now.minute)}';
  }

  Future<void> _loadReporter() async {
    final name = await AuthService.getUserName();
    final email = await AuthService.getUserEmail();
    final value = (name ?? '').trim().isNotEmpty
        ? name!.trim()
        : (email ?? '').trim();
    if (!mounted || value.isEmpty) return;
    setState(() => _informa = value);
  }

  String get _ubicacion {
    final manual = _ubicacionCtrl.text.trim();
    if (manual.isNotEmpty) return manual;

    final coords = _coordenadasCtrl.text.trim();
    if (coords.isNotEmpty) return 'Ubicación GPS $coords';

    return '';
  }

  MotociclistaReportDraft _draft() {
    return MotociclistaReportDraft(
      kind: _kind,
      fecha: _fechaCtrl.text,
      hora: _horaCtrl.text,
      ubicacion: _ubicacion,
      lat: _latCtrl.text,
      lng: _lngCtrl.text,
      coordenadas: _coordenadasCtrl.text,
      tipoPreliminar: _tipoPreliminar,
      lesionados: _lesionados,
      estado: _estado,
      motivo: _motivo(),
      descripcion: _notaCtrl.text,
      tipoCierre: _tipoCierre,
      vialidadAfectada: _ubicacion,
      sentidoAfectado: 'No especificado',
      estadoCirculacion: _estadoCirculacion,
      puntosCubiertos: _ubicacion.isEmpty ? 'Lugar informado' : _ubicacion,
      estadoFuerza: '$_elementos elementos',
      zonaMonitoreada: _zonaMonitoreada,
      kilometrosRecorridos: _kilometros,
      unidadCrp: MotociclistaReportService.reportSourceMarker,
      numeroElementos: '$_elementos',
      informa: _informa,
    );
  }

  String _motivo() {
    switch (_kind) {
      case MotociclistaReportKind.abanderamiento:
        return _tipoPreliminar;
      case MotociclistaReportKind.apoyoPreventivo:
        return _apoyoMotivo;
      case MotociclistaReportKind.cierreVialidad:
        return _cierreMotivo;
      case MotociclistaReportKind.dispositivoVial:
        return _dispositivoMotivo;
      case MotociclistaReportKind.monitoreoSinNovedad:
        return 'Monitoreo sin novedad';
    }
  }

  Future<void> _captureLocation() async {
    if (_locating) return;
    setState(() => _locating = true);

    final geo = await GeoService.getCurrent();
    if (!mounted) return;

    setState(() {
      if (geo.lat != null && geo.lng != null) {
        final lat = geo.lat!.toStringAsFixed(6);
        final lng = geo.lng!.toStringAsFixed(6);
        _latCtrl.text = lat;
        _lngCtrl.text = lng;
        _coordenadasCtrl.text = '$lat, $lng';
      }
      _locating = false;
    });
  }

  Future<void> _addPhoto(ImageSource source) async {
    final file = await PhotoPickerService.pickAndCropImage(
      context,
      _picker,
      source: source,
    );
    if (!mounted || file == null) return;
    setState(() => _fotos.add(file));
  }

  Future<void> _addGalleryPhotos() async {
    final files = await PhotoPickerService.pickAndCropMultiImage(
      context,
      _picker,
    );
    if (!mounted || files.isEmpty) return;
    setState(() => _fotos.addAll(files));
  }

  Future<void> _saveAndShare() async {
    if (_saving) return;
    final draft = _draft();
    final issues = MotociclistaReportService.validateDraft(
      draft,
      photoCount: _fotos.length,
    );
    if (issues.isNotEmpty) {
      await _showIssues(issues);
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await MotociclistaReportService.guardarReporte(
        draft: draft,
        fotos: _fotos,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      await _shareText(draft);
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No se pudo guardar'),
          content: Text(
            e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareText(MotociclistaReportDraft draft) {
    final text = MotociclistaReportService.buildInstitutionalText(draft);
    return ActividadShareService.compartirTextoConArchivosLocales(
      texto: text,
      archivos: [for (final foto in _fotos) foto.path],
    );
  }

  Future<void> _showIssues(List<String> issues) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Falta completar'),
        content: Text(issues.join('\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTextPreview() {
    final text = MotociclistaReportService.buildInstitutionalText(_draft());
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Texto'),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _editText({
    required String title,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Listo'),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(_kind.title),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            tooltip: 'Texto',
            onPressed: _showTextPreview,
            icon: const Icon(Icons.article_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 118),
          children: [
            _StatusPanel(
              fecha: _fechaCtrl.text,
              hora: _horaCtrl.text,
              ubicacion: _ubicacion,
              fotos: _fotos.length,
              locating: _locating,
              onLocation: _captureLocation,
              onCamera: () => _addPhoto(ImageSource.camera),
              onGallery: _addGalleryPhotos,
              onEditPlace: () =>
                  _editText(title: 'Lugar', controller: _ubicacionCtrl),
            ),
            const SizedBox(height: 12),
            _Section(title: 'Reporte', children: _reportFields()),
            const SizedBox(height: 12),
            _Section(
              title: 'Estado de fuerza',
              children: [
                _CounterRow(
                  value: _elementos,
                  onMinus: _elementos <= 1
                      ? null
                      : () => setState(() => _elementos -= 1),
                  onPlus: () => setState(() => _elementos += 1),
                ),
              ],
            ),
            if (_fotos.isNotEmpty) ...[
              const SizedBox(height: 12),
              _PhotoStrip(
                fotos: _fotos,
                onRemove: (index) => setState(() => _fotos.removeAt(index)),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          color: Colors.white,
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _saveAndShare,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text(
                'Guardar y enviar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _reportFields() {
    switch (_kind) {
      case MotociclistaReportKind.abanderamiento:
        return [
          _ChoiceGroup(
            label: 'Tipo',
            value: _tipoPreliminar,
            values: const [
              'Choque',
              'Volcadura',
              'Atropellamiento',
              'Salida de camino',
              'Motocicleta involucrada',
              'Vehículo averiado',
              'Otro',
            ],
            onChanged: (value) => setState(() => _tipoPreliminar = value),
          ),
          _ChoiceGroup(
            label: 'Lesionados',
            value: _lesionados,
            values: const ['Se desconoce', 'No', 'Sí'],
            onChanged: (value) => setState(() => _lesionados = value),
          ),
          _ChoiceGroup(
            label: 'Estado',
            value: _estado,
            values: const ['En espera de UAS', 'UAS arribó', 'Finalizado'],
            onChanged: (value) => setState(() => _estado = value),
          ),
          _OptionalNoteButton(
            hasNote: _notaCtrl.text.trim().isNotEmpty,
            onTap: () =>
                _editText(title: 'Nota', controller: _notaCtrl, maxLines: 3),
          ),
        ];
      case MotociclistaReportKind.apoyoPreventivo:
        return [
          _ChoiceGroup(
            label: 'Motivo',
            value: _apoyoMotivo,
            values: const [
              'Apoyo a la vialidad',
              'Cruce peatonal',
              'Vehículo averiado',
              'Zona escolar',
              'Evento',
            ],
            onChanged: (value) => setState(() => _apoyoMotivo = value),
          ),
          _OptionalNoteButton(
            hasNote: _notaCtrl.text.trim().isNotEmpty,
            onTap: () =>
                _editText(title: 'Nota', controller: _notaCtrl, maxLines: 3),
          ),
        ];
      case MotociclistaReportKind.cierreVialidad:
        return [
          _ChoiceGroup(
            label: 'Cierre',
            value: _tipoCierre,
            values: const ['Parcial', 'Total', 'Intermitente'],
            onChanged: (value) => setState(() => _tipoCierre = value),
          ),
          _ChoiceGroup(
            label: 'Motivo',
            value: _cierreMotivo,
            values: const [
              'Hecho de tránsito',
              'Obra',
              'Evento',
              'Manifestación',
              'Riesgo en vía',
            ],
            onChanged: (value) => setState(() => _cierreMotivo = value),
          ),
          _ChoiceGroup(
            label: 'Circulación',
            value: _estadoCirculacion,
            values: const ['Con precaución', 'Lenta', 'Detenida', 'Liberada'],
            onChanged: (value) => setState(() => _estadoCirculacion = value),
          ),
          _OptionalNoteButton(
            hasNote: _notaCtrl.text.trim().isNotEmpty,
            onTap: () =>
                _editText(title: 'Nota', controller: _notaCtrl, maxLines: 3),
          ),
        ];
      case MotociclistaReportKind.dispositivoVial:
        return [
          _ChoiceGroup(
            label: 'Motivo',
            value: _dispositivoMotivo,
            values: const [
              'Paso continuo',
              'Apoyo a la vialidad',
              'Patrullaje',
              'Zona escolar',
              'Evento',
            ],
            onChanged: (value) => setState(() => _dispositivoMotivo = value),
          ),
          _OptionalNoteButton(
            hasNote: _notaCtrl.text.trim().isNotEmpty,
            onTap: () =>
                _editText(title: 'Nota', controller: _notaCtrl, maxLines: 3),
          ),
        ];
      case MotociclistaReportKind.monitoreoSinNovedad:
        return [
          _ChoiceGroup(
            label: 'Zona',
            value: _zonaMonitoreada,
            values: const [
              'Avenidas',
              'Periférico',
              'Bancos',
              'Tiendas',
              'Oficinas',
              'Otro',
            ],
            onChanged: (value) => setState(() => _zonaMonitoreada = value),
          ),
          _ChoiceGroup(
            label: 'Km',
            value: _kilometros,
            values: const ['0', '5', '10', '15', '20'],
            onChanged: (value) => setState(() => _kilometros = value),
          ),
          _OptionalNoteButton(
            hasNote: _notaCtrl.text.trim().isNotEmpty,
            onTap: () =>
                _editText(title: 'Nota', controller: _notaCtrl, maxLines: 3),
          ),
        ];
    }
  }
}

class _StatusPanel extends StatelessWidget {
  final String fecha;
  final String hora;
  final String ubicacion;
  final int fotos;
  final bool locating;
  final VoidCallback onLocation;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onEditPlace;

  const _StatusPanel({
    required this.fecha,
    required this.hora,
    required this.ubicacion,
    required this.fotos,
    required this.locating,
    required this.onLocation,
    required this.onCamera,
    required this.onGallery,
    required this.onEditPlace,
  });

  @override
  Widget build(BuildContext context) {
    final locationText = ubicacion.trim().isEmpty ? 'Sin lugar' : ubicacion;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _TinyInfo(label: 'Fecha', value: fecha),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TinyInfo(label: 'Hora', value: hora),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _TinyInfo(label: 'Lugar', value: locationText),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: locating ? null : onLocation,
                    icon: locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text('GPS'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEditPlace,
                    icon: const Icon(Icons.place_outlined),
                    label: const Text('Lugar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onCamera,
                    icon: const Icon(Icons.photo_camera),
                    label: Text(fotos > 0 ? 'Fotos $fotos' : 'Foto'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galería'),
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

class _TinyInfo extends StatelessWidget {
  final String label;
  final String value;

  const _TinyInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ChoiceGroup extends StatelessWidget {
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _ChoiceGroup({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in values)
                ChoiceChip(
                  selected: value == item,
                  label: Text(item),
                  onSelected: (_) => onChanged(item),
                  labelStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: value == item
                        ? FontWeight.w900
                        : FontWeight.w700,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OptionalNoteButton extends StatelessWidget {
  final bool hasNote;
  final VoidCallback onTap;

  const _OptionalNoteButton({required this.hasNote, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(hasNote ? Icons.edit_note : Icons.note_add_outlined),
        label: Text(hasNote ? 'Nota agregada' : 'Nota'),
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  final int value;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  const _CounterRow({
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SquareButton(icon: Icons.remove, onPressed: onMinus),
        Expanded(
          child: Center(
            child: Text(
              '$value',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        _SquareButton(icon: Icons.add, onPressed: onPlus),
      ],
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _SquareButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 50,
      child: ElevatedButton(onPressed: onPressed, child: Icon(icon, size: 28)),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  final List<File> fotos;
  final ValueChanged<int> onRemove;

  const _PhotoStrip({required this.fotos, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Fotos',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < fotos.length; i++)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      fotos[i],
                      width: 86,
                      height: 86,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: InkWell(
                      onTap: () => onRemove(i),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(3),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
