import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/constancia_manejo.dart';
import '../../models/licencia_emision.dart';
import '../../services/constancias_manejo_service.dart';
import '../../services/licencias_emision_service.dart';
import '../../services/photo_picker_service.dart';
import '../../widgets/app_drawer.dart';

class LicenciasEmisionScreen extends StatefulWidget {
  const LicenciasEmisionScreen({super.key});

  @override
  State<LicenciasEmisionScreen> createState() => _LicenciasEmisionScreenState();
}

class _LicenciasEmisionScreenState extends State<LicenciasEmisionScreen> {
  final _searchCtrl = TextEditingController();
  List<LicenciaEmision> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await LicenciasEmisionService.index(
        buscar: _searchCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = LicenciasEmisionService.cleanError(error);
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final created = await Navigator.push<LicenciaEmision>(
      context,
      MaterialPageRoute(builder: (_) => const LicenciaEmisionFormScreen()),
    );
    if (created == null || !mounted) return;
    await _load();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _LicenseDetailDialog(licencia: created),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Emisión de licencias'),
        backgroundColor: const Color(0xFF7A1747),
      ),
      drawer: const AppDrawer(trackingOn: false),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF7A1747),
        foregroundColor: Colors.white,
        onPressed: _create,
        icon: const Icon(Icons.badge_outlined),
        label: const Text('Nueva licencia'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                labelText: 'Buscar por nombre, CURP, licencia o constancia',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Buscar',
                  onPressed: _load,
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 52, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 110),
            Icon(Icons.badge_outlined, size: 68, color: Color(0xFF94A3B8)),
            SizedBox(height: 14),
            Text(
              'Todavía no hay licencias emitidas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'Crea una para comenzar las pruebas.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _items[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF7A1747).withValues(alpha: .1),
                foregroundColor: const Color(0xFF7A1747),
                child: const Icon(Icons.badge_outlined),
              ),
              title: Text(
                item.nombreCompleto,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'Lic. ${item.numero} · Tipo ${item.tipoLicencia}\n'
                'Constancia ${item.constancia?.folio ?? 'Sin folio'}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => _LicenseDetailDialog(licencia: item),
              ),
            ),
          );
        },
      ),
    );
  }
}

class LicenciaEmisionFormScreen extends StatefulWidget {
  const LicenciaEmisionFormScreen({super.key});

  @override
  State<LicenciaEmisionFormScreen> createState() =>
      _LicenciaEmisionFormScreenState();
}

class _LicenciaEmisionFormScreenState extends State<LicenciaEmisionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _curpCtrl = TextEditingController();
  final _paternoCtrl = TextEditingController();
  final _maternoCtrl = TextEditingController();
  final _nombresCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _restriccionesCtrl = TextEditingController(text: 'NINGUNA');
  final _oficinaCtrl = TextEditingController(text: 'POLICÍA Y TRÁNSITO');
  final _vehiculosCtrl = TextEditingController(
    text:
        'VEHÍCULOS DE USO PRIVADO DE MÁS DE DOS EJES Y, EN GENERAL, DE TIPO PESADO',
  );

  ConstanciaManejo? _constancia;
  File? _foto;
  DateTime? _nacimiento;
  DateTime _expedicion = DateTime.now();
  DateTime _vencimiento = DateTime.now().add(const Duration(days: 365 * 4));
  DateTime? _antiguedad;
  String _tipo = 'B';
  String _genero = 'H';
  String _sangre = 'O+';
  bool _donador = true;
  bool _saving = false;

  @override
  void dispose() {
    _curpCtrl.dispose();
    _paternoCtrl.dispose();
    _maternoCtrl.dispose();
    _nombresCtrl.dispose();
    _numeroCtrl.dispose();
    _restriccionesCtrl.dispose();
    _oficinaCtrl.dispose();
    _vehiculosCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectConstancia() async {
    final selected = await showDialog<ConstanciaManejo>(
      context: context,
      builder: (_) => const _ConstanciaPickerDialog(),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _constancia = selected;
      _curpCtrl.text = selected.curp ?? '';
      _tipo = _normalizeLicenseType(selected.tipoLicencia);
    });
  }

  Future<void> _takePhoto(ImageSource source) async {
    final file = await PhotoPickerService.pickAndCropImage(
      context,
      _picker,
      source: source,
      cropLandscape: false,
      maxWidth: 1200,
      maxHeight: 1600,
    );
    if (file == null || !mounted) return;
    setState(() => _foto = file);
  }

  Future<void> _pickDate(_DateField field) async {
    final initial = switch (field) {
      _DateField.birth => _nacimiento ?? DateTime(1990),
      _DateField.issue => _expedicion,
      _DateField.expiry => _vencimiento,
      _DateField.seniority => _antiguedad ?? DateTime(2022),
    };
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: field == _DateField.expiry
          ? DateTime.now().add(const Duration(days: 365 * 15))
          : DateTime.now(),
    );
    if (value == null || !mounted) return;
    setState(() {
      switch (field) {
        case _DateField.birth:
          _nacimiento = value;
        case _DateField.issue:
          _expedicion = value;
        case _DateField.expiry:
          _vencimiento = value;
        case _DateField.seniority:
          _antiguedad = value;
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_constancia == null) {
      _snack('Selecciona la constancia vinculada.');
      return;
    }
    if (_nacimiento == null) {
      _snack('Selecciona la fecha de nacimiento.');
      return;
    }
    if (_foto == null) {
      _snack('Toma o selecciona la fotografía del titular.');
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await LicenciasEmisionService.create(
        constanciaId: _constancia!.id,
        foto: _foto!,
        fields: <String, String>{
          'numero': _numeroCtrl.text.trim(),
          'curp': _curpCtrl.text.trim().toUpperCase(),
          'apellido_paterno': _paternoCtrl.text.trim(),
          'apellido_materno': _maternoCtrl.text.trim(),
          'nombres': _nombresCtrl.text.trim(),
          'fecha_nacimiento': _apiDate(_nacimiento!),
          'fecha_expedicion': _apiDate(_expedicion),
          'fecha_vencimiento': _apiDate(_vencimiento),
          'fecha_antiguedad': _antiguedad == null ? '' : _apiDate(_antiguedad!),
          'tipo_licencia': _tipo,
          'genero': _genero,
          'tipo_sangre': _sangre,
          'donador_organos': _donador ? '1' : '0',
          'restricciones': _restriccionesCtrl.text.trim(),
          'oficina_emisora': _oficinaCtrl.text.trim(),
          'vehiculos_autorizados': _vehiculosCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.pop(context, created);
    } catch (error) {
      if (!mounted) return;
      _snack(LicenciasEmisionService.cleanError(error));
      setState(() => _saving = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final draft = _LicenseDraft(
      numero: _numeroCtrl.text.trim().isEmpty
          ? 'SE ASIGNARÁ AL GUARDAR'
          : _numeroCtrl.text,
      curp: _curpCtrl.text,
      paterno: _paternoCtrl.text,
      materno: _maternoCtrl.text,
      nombres: _nombresCtrl.text,
      nacimiento: _nacimiento,
      expedicion: _expedicion,
      vencimiento: _vencimiento,
      antiguedad: _antiguedad,
      tipo: _tipo,
      genero: _genero,
      sangre: _sangre,
      donador: _donador,
      restricciones: _restriccionesCtrl.text,
      oficina: _oficinaCtrl.text,
      vehiculos: _vehiculosCtrl.text,
      foto: _foto,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Nueva licencia'),
        backgroundColor: const Color(0xFF7A1747),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7A1747),
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Emitiendo…' : 'Emitir licencia de prueba'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
          children: [
            _FormSection(
              title: '1. Expediente vinculado',
              icon: Icons.account_tree_outlined,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(
                    _constancia == null
                        ? 'Seleccionar constancia aprobada'
                        : 'Constancia ${_constancia!.folio}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    _constancia == null
                        ? 'Debe provenir de un examen aprobado.'
                        : '${_constancia!.nombreSolicitante ?? ''} · ${_constancia!.resultado ?? ''}',
                  ),
                  trailing: OutlinedButton(
                    onPressed: _selectConstancia,
                    child: Text(_constancia == null ? 'Buscar' : 'Cambiar'),
                  ),
                ),
              ],
            ),
            _FormSection(
              title: '2. Datos del titular',
              icon: Icons.person_outline,
              children: [
                _field(
                  _curpCtrl,
                  'CURP *',
                  capitalization: TextCapitalization.characters,
                  maxLength: 18,
                ),
                _field(_paternoCtrl, 'Apellido paterno *'),
                _field(_maternoCtrl, 'Apellido materno'),
                _field(_nombresCtrl, 'Nombre(s) *'),
                _dateTile(
                  'Fecha de nacimiento *',
                  _nacimiento,
                  () => _pickDate(_DateField.birth),
                ),
                DropdownButtonFormField<String>(
                  value: _genero,
                  decoration: const InputDecoration(
                    labelText: 'Género *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'H', child: Text('H')),
                    DropdownMenuItem(value: 'M', child: Text('M')),
                    DropdownMenuItem(
                      value: 'X',
                      child: Text('X / No especificado'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _genero = value ?? 'H'),
                ),
              ],
            ),
            _FormSection(
              title: '3. Fotografía',
              icon: Icons.photo_camera_outlined,
              children: [
                Center(
                  child: Container(
                    width: 150,
                    height: 190,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: _foto == null
                        ? const Icon(
                            Icons.person,
                            size: 90,
                            color: Color(0xFF94A3B8),
                          )
                        : Image.file(_foto!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _takePhoto(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Tomar foto'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _takePhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galería'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            _FormSection(
              title: '4. Datos de la licencia',
              icon: Icons.badge_outlined,
              children: [
                _field(
                  _numeroCtrl,
                  'Número (opcional; se genera automáticamente)',
                ),
                DropdownButtonFormField<String>(
                  value: _tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de licencia *',
                    border: OutlineInputBorder(),
                  ),
                  items: const ['A', 'B', 'C', 'D', 'E', 'CHOFER']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _tipo = value ?? 'B'),
                ),
                const SizedBox(height: 12),
                _dateTile(
                  'Fecha de expedición *',
                  _expedicion,
                  () => _pickDate(_DateField.issue),
                ),
                _dateTile(
                  'Fecha de vencimiento *',
                  _vencimiento,
                  () => _pickDate(_DateField.expiry),
                ),
                _dateTile(
                  'Fecha de antigüedad',
                  _antiguedad,
                  () => _pickDate(_DateField.seniority),
                ),
                DropdownButtonFormField<String>(
                  value: _sangre,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de sangre *',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      const ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _sangre = value ?? 'O+'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Donador de órganos'),
                  value: _donador,
                  onChanged: (value) => setState(() => _donador = value),
                ),
                _field(_restriccionesCtrl, 'Restricciones *'),
                _field(_oficinaCtrl, 'Oficina emisora *'),
                _field(_vehiculosCtrl, 'Vehículos autorizados *', maxLines: 3),
              ],
            ),
            _FormSection(
              title: '5. Vista previa dinámica',
              icon: Icons.preview_outlined,
              children: [
                const Text(
                  'Los diseños son una primera maqueta para pruebas. Sellos, textos legales, tipografía y medidas finales deberán validarse antes de producción.',
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _LicenseCardPreview(draft: draft),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    int? maxLength,
    TextCapitalization capitalization = TextCapitalization.words,
  }) {
    final required = label.contains('*');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        textCapitalization: capitalization,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (value) => (value ?? '').trim().isEmpty ? 'Requerido' : null
            : null,
      ),
    );
  }

  Widget _dateTile(String label, DateTime? value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0xFF94A3B8)),
        ),
        title: Text(label),
        subtitle: Text(value == null ? 'Seleccionar' : _displayDate(value)),
        trailing: const Icon(Icons.calendar_month_outlined),
        onTap: onTap,
      ),
    );
  }
}

class _ConstanciaPickerDialog extends StatefulWidget {
  const _ConstanciaPickerDialog();

  @override
  State<_ConstanciaPickerDialog> createState() =>
      _ConstanciaPickerDialogState();
}

class _ConstanciaPickerDialogState extends State<_ConstanciaPickerDialog> {
  final _searchCtrl = TextEditingController();
  List<ConstanciaManejo> _items = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ConstanciasManejoService.index(
        buscar: _searchCtrl.text,
        estatus: 'ACTIVA',
        perPage: 50,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items.where((item) => item.examenAprobado).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = ConstanciasManejoService.cleanExceptionMessage(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Constancia aprobada'),
          leading: const CloseButton(),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _searchCtrl,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  labelText: 'Folio, nombre o CURP',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: _search,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!, textAlign: TextAlign.center))
                  : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay constancias activas con examen aprobado.',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, index) {
                        final item = _items[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.description_outlined),
                          ),
                          title: Text(
                            item.folio,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '${item.nombreSolicitante ?? ''}\n'
                            '${item.curp ?? 'Sin CURP'} · Examen ${item.resultado ?? ''}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LicenseDetailDialog extends StatelessWidget {
  final LicenciaEmision licencia;

  const _LicenseDetailDialog({required this.licencia});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Licencia ${licencia.numero}'),
          backgroundColor: const Color(0xFF7A1747),
          leading: const CloseButton(),
        ),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _LicenseCardPreview.fromLicense(licencia),
            const SizedBox(height: 16),
            const Text(
              'Historial vinculado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _HistoryStep(
              icon: Icons.quiz_outlined,
              title: 'Examen de manejo',
              value: licencia.examen == null
                  ? 'Sin vínculo'
                  : '${licencia.examen!.folio} · ${licencia.examen!.estatus}'
                        '${licencia.examen!.calificacion == null ? '' : ' · ${licencia.examen!.calificacion}'}',
            ),
            _HistoryStep(
              icon: Icons.description_outlined,
              title: 'Constancia',
              value: licencia.constancia == null
                  ? 'Sin vínculo'
                  : '${licencia.constancia!.folio} · ${licencia.constancia!.estatus}',
            ),
            _HistoryStep(
              icon: Icons.badge_outlined,
              title: 'Licencia emitida',
              value: '${licencia.numero} · ${licencia.estatus}',
              last: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _LicenseCardPreview extends StatelessWidget {
  final _LicenseDraft draft;
  final LicenciaEmision? license;

  const _LicenseCardPreview({required this.draft}) : license = null;

  _LicenseCardPreview.fromLicense(LicenciaEmision value)
    : license = value,
      draft = _LicenseDraft.fromLicense(value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'FRENTE',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        const SizedBox(height: 6),
        _CardFrame(
          child: _LicenseFront(draft: draft, license: license),
        ),
        const SizedBox(height: 14),
        const Text(
          'REVERSO',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        const SizedBox(height: 6),
        _CardFrame(
          child: _LicenseBack(draft: draft, license: license),
        ),
      ],
    );
  }
}

class _CardFrame extends StatelessWidget {
  final Widget child;

  const _CardFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.586,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(width: 856, height: 540, child: child),
          ),
        ),
      ),
    );
  }
}

class _LicenseFront extends StatelessWidget {
  final _LicenseDraft draft;
  final LicenciaEmision? license;

  const _LicenseFront({required this.draft, required this.license});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _CardPattern()),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 34,
          child: Container(
            color: const Color(0xFF7A1747),
            alignment: Alignment.center,
            child: const Text(
              'PLAN MICHOACÁN POR LA PAZ Y LA JUSTICIA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                letterSpacing: 5,
              ),
            ),
          ),
        ),
        const Positioned(
          top: 50,
          left: 170,
          right: 40,
          child: Text(
            'ESTADOS UNIDOS MEXICANOS\nSECRETARÍA DE SEGURIDAD PÚBLICA',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7A1747),
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
        ),
        Positioned(
          left: 34,
          top: 124,
          width: 210,
          height: 270,
          child: _PhotoBox(draft: draft, license: license),
        ),
        Positioned(
          left: 272,
          top: 125,
          width: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _frontField('CURP', draft.curp),
              _frontField('APELLIDO PATERNO', draft.paterno),
              _frontField('APELLIDO MATERNO', draft.materno),
              _frontField('NOMBRE(S)', draft.nombres),
              _frontField(
                'FECHA DE NACIMIENTO',
                _displayDate(draft.nacimiento),
              ),
              _frontField(
                'FECHA DE EXPEDICIÓN',
                _displayDate(draft.expedicion),
              ),
              _frontField(
                'FECHA DE VENCIMIENTO',
                _displayDate(draft.vencimiento),
              ),
            ],
          ),
        ),
        Positioned(
          right: 35,
          bottom: 74,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'NÚMERO',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              Text(
                draft.numero,
                style: const TextStyle(
                  color: Color(0xFF7A1747),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 58,
          child: Container(
            color: const Color(0xFF7A1747),
            alignment: Alignment.center,
            child: Text(
              'LICENCIA DE MANEJO TIPO ${draft.tipo}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _frontField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, letterSpacing: 2)),
          Text(
            value.trim().isEmpty ? '—' : value.toUpperCase(),
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _LicenseBack extends StatelessWidget {
  final _LicenseDraft draft;
  final LicenciaEmision? license;

  const _LicenseBack({required this.draft, required this.license});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _CardPattern()),
        Positioned(
          left: 24,
          top: 70,
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _backField('OFICINA EMISORA', draft.oficina),
              _backField('FECHA DE ANTIGÜEDAD', _displayDate(draft.antiguedad)),
              _backField('GÉNERO', draft.genero),
              _backField('TIPO DE SANGRE', draft.sangre),
              _backField('DONADOR DE ÓRGANOS', draft.donador ? 'SÍ' : 'NO'),
              _backField('RESTRICCIONES', draft.restricciones),
              const SizedBox(height: 8),
              const Text(
                'ESTA LICENCIA AUTORIZA A CONDUCIR',
                style: TextStyle(fontSize: 15, letterSpacing: 2),
              ),
              Text(
                draft.vehiculos.trim().isEmpty
                    ? '—'
                    : draft.vehiculos.toUpperCase(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 30,
          top: 95,
          width: 255,
          height: 255,
          child: _QrBox(base64Value: license?.qrBase64),
        ),
        const Positioned(
          right: 38,
          bottom: 75,
          width: 230,
          child: Column(
            children: [
              Icon(Icons.draw_outlined, size: 62, color: Color(0xFF0F172A)),
              Text(
                'FIRMA DE LA AUTORIDAD EMISORA',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _backField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, letterSpacing: 2)),
          Text(
            value.trim().isEmpty ? '—' : value.toUpperCase(),
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoBox extends StatelessWidget {
  final _LicenseDraft draft;
  final LicenciaEmision? license;

  const _PhotoBox({required this.draft, required this.license});

  @override
  Widget build(BuildContext context) {
    final url = license?.fotoUrl?.trim() ?? '';
    if (draft.foto != null) return Image.file(draft.foto!, fit: BoxFit.cover);
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFE2E8F0),
    child: const Icon(Icons.person, size: 145, color: Color(0xFF94A3B8)),
  );
}

class _QrBox extends StatelessWidget {
  final String? base64Value;

  const _QrBox({required this.base64Value});

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeBase64(base64Value);
    if (bytes != null) return Image.memory(bytes, fit: BoxFit.contain);
    return Container(
      color: Colors.white,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2, size: 170),
          Text('QR AL GUARDAR', style: TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _CardPattern extends StatelessWidget {
  const _CardPattern();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: CustomPaint(painter: _PatternPainter()),
    );
  }
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF0F1F3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    for (double x = -80; x < size.width + 80; x += 95) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + 45, 45)
        ..lineTo(x, 90)
        ..lineTo(x + 45, 135)
        ..lineTo(x, 180)
        ..lineTo(x + 45, 225)
        ..lineTo(x, 270)
        ..lineTo(x + 45, 315)
        ..lineTo(x, 360)
        ..lineTo(x + 45, 405)
        ..lineTo(x, 450)
        ..lineTo(x + 45, 495)
        ..lineTo(x, 540);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _FormSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF7A1747)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _HistoryStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool last;

  const _HistoryStep({
    required this.icon,
    required this.title,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF7A1747),
              foregroundColor: Colors.white,
              child: Icon(icon),
            ),
            if (!last)
              Container(width: 3, height: 46, color: const Color(0xFFD8B4C5)),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LicenseDraft {
  final String numero;
  final String curp;
  final String paterno;
  final String materno;
  final String nombres;
  final DateTime? nacimiento;
  final DateTime? expedicion;
  final DateTime? vencimiento;
  final DateTime? antiguedad;
  final String tipo;
  final String genero;
  final String sangre;
  final bool donador;
  final String restricciones;
  final String oficina;
  final String vehiculos;
  final File? foto;

  const _LicenseDraft({
    required this.numero,
    required this.curp,
    required this.paterno,
    required this.materno,
    required this.nombres,
    required this.nacimiento,
    required this.expedicion,
    required this.vencimiento,
    required this.antiguedad,
    required this.tipo,
    required this.genero,
    required this.sangre,
    required this.donador,
    required this.restricciones,
    required this.oficina,
    required this.vehiculos,
    required this.foto,
  });

  factory _LicenseDraft.fromLicense(LicenciaEmision value) => _LicenseDraft(
    numero: value.numero,
    curp: value.curp,
    paterno: value.apellidoPaterno,
    materno: value.apellidoMaterno,
    nombres: value.nombres,
    nacimiento: DateTime.tryParse(value.fechaNacimiento),
    expedicion: DateTime.tryParse(value.fechaExpedicion),
    vencimiento: DateTime.tryParse(value.fechaVencimiento),
    antiguedad: DateTime.tryParse(value.fechaAntiguedad ?? ''),
    tipo: value.tipoLicencia,
    genero: value.genero,
    sangre: value.tipoSangre,
    donador: value.donadorOrganos,
    restricciones: value.restricciones,
    oficina: value.oficinaEmisora,
    vehiculos: value.vehiculosAutorizados,
    foto: null,
  );
}

enum _DateField { birth, issue, expiry, seniority }

String _normalizeLicenseType(String? raw) {
  final value = (raw ?? '').trim().toUpperCase();
  for (final option in const ['A', 'B', 'C', 'D', 'E', 'CHOFER']) {
    if (value == option || value.contains('TIPO $option')) return option;
  }
  return 'B';
}

String _apiDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _displayDate(DateTime? value) {
  if (value == null) return '—';
  const months = [
    'ENE',
    'FEB',
    'MAR',
    'ABR',
    'MAY',
    'JUN',
    'JUL',
    'AGO',
    'SEP',
    'OCT',
    'NOV',
    'DIC',
  ];
  return '${value.day.toString().padLeft(2, '0')} | ${months[value.month - 1]} | ${value.year}';
}

Uint8List? _decodeBase64(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return null;
  try {
    return base64Decode(value.contains(',') ? value.split(',').last : value);
  } catch (_) {
    return null;
  }
}
