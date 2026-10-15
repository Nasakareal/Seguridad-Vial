import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/grua_corralon_service.dart';
import '../login_screen.dart';

class GruaCorralonScreen extends StatefulWidget {
  const GruaCorralonScreen({super.key});

  @override
  State<GruaCorralonScreen> createState() => _GruaCorralonScreenState();
}

class _GruaCorralonScreenState extends State<GruaCorralonScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
  String? _gruaNombre;
  String _estado = 'pendientes';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await GruaCorralonService.fetch(
        estado: _estado,
        search: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _gruaNombre = result.gruaNombre;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _openEntrega(Map<String, dynamic> item) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => GruaEntregaScreen(item: item)),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff1f4f7),
      appBar: AppBar(
        title: const Text('Mis servicios en corralón'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((_gruaNombre ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _gruaNombre!,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _load(),
                    decoration: InputDecoration(
                      hintText: 'Buscar placa, NIV o inventario',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'pendientes',
                        icon: Icon(Icons.local_parking),
                        label: Text('En corralón'),
                      ),
                      ButtonSegment(
                        value: 'entregados',
                        icon: Icon(Icons.check_circle_outline),
                        label: Text('Entregados'),
                      ),
                    ],
                    selected: {_estado},
                    onSelectionChanged: (selected) {
                      setState(() => _estado = selected.first);
                      _load();
                    },
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * .2),
            const Icon(Icons.local_shipping_outlined, size: 64),
            const SizedBox(height: 12),
            Text(
              _estado == 'pendientes'
                  ? 'No tienes vehículos pendientes en corralón.'
                  : 'Todavía no hay entregas registradas.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (context, index) => _VehicleCard(
          item: _items[index],
          pending: _estado == 'pendientes',
          onDeliver: () => _openEntrega(_items[index]),
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool pending;
  final VoidCallback onDeliver;

  const _VehicleCard({
    required this.item,
    required this.pending,
    required this.onDeliver,
  });

  String _text(String key, [String fallback = 'N/A']) {
    final value = item[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    final liberacion = item['liberacion'] is Map
        ? Map<String, dynamic>.from(item['liberacion'] as Map)
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_text('marca', '')} ${_text('linea', '')}'.trim(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(pending ? 'EN CORRALÓN' : 'ENTREGADO'),
                  backgroundColor: pending
                      ? Colors.orange.shade100
                      : Colors.green.shade100,
                ),
              ],
            ),
            const Divider(),
            _row('Placas', _text('placas', 'Sin placas')),
            _row('NIV', _text('serie')),
            _row('Color / modelo', '${_text('color')} / ${_text('modelo')}'),
            _row('Inventario', _text('numero_inventario_grua')),
            if (pending) _row('Corralón', _text('corralon')),
            if (liberacion != null) ...[
              _row(
                'Recibió',
                liberacion['persona_recibe']?.toString() ?? 'N/A',
              ),
              _row(
                'Folio SIERSE',
                liberacion['sierse_folio']?.toString() ?? 'N/A',
              ),
              _row(
                'Fecha de entrega',
                liberacion['fecha_entrega']?.toString() ?? 'N/A',
              ),
            ],
            if (pending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onDeliver,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Registrar entrega'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}

class GruaEntregaScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const GruaEntregaScreen({super.key, required this.item});

  @override
  State<GruaEntregaScreen> createState() => _GruaEntregaScreenState();
}

class _GruaEntregaScreenState extends State<GruaEntregaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _persona = TextEditingController();
  final _identificacion = TextEditingController();
  final _telefono = TextEditingController();
  final _sierse = TextEditingController();
  final _observaciones = TextEditingController();
  String _condicion = 'CONFORME_INVENTARIO';
  XFile? _foto;
  bool _confirmado = false;
  bool _saving = false;

  @override
  void dispose() {
    _persona.dispose();
    _identificacion.dispose();
    _telefono.dispose();
    _sierse.dispose();
    _observaciones.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (file != null && mounted) setState(() => _foto = file);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_foto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toma o selecciona la foto de entrega.')),
      );
      return;
    }
    if (!_confirmado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirma la entrega del vehículo.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await GruaCorralonService.entregar(
        vehiculoId: int.parse(widget.item['id'].toString()),
        personaRecibe: _persona.text,
        identificacionRecibe: _identificacion.text,
        telefono: _telefono.text,
        sierseFolio: _sierse.text,
        condicionEntrega: _condicion,
        observaciones: _observaciones.text,
        fotoEntrega: _foto!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrega registrada correctamente.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final placas = widget.item['placas']?.toString() ?? 'Sin placas';
    return Scaffold(
      appBar: AppBar(title: Text('Entrega · $placas')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Datos de liberación',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            _field(_persona, 'Persona que recibe'),
            _field(
              _identificacion,
              'Tipo y folio de identificación',
              hint: 'Ej. INE 1234567890',
            ),
            _field(_telefono, 'Teléfono', required: false),
            _field(_sierse, 'Folio de memoria SIERSE'),
            DropdownButtonFormField<String>(
              value: _condicion,
              decoration: const InputDecoration(
                labelText: 'Condición al entregar',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'CONFORME_INVENTARIO',
                  child: Text('Conforme al inventario'),
                ),
                DropdownMenuItem(
                  value: 'CON_OBSERVACIONES',
                  child: Text('Con daños, faltantes u observaciones'),
                ),
              ],
              onChanged: (value) => setState(() => _condicion = value!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _observaciones,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observaciones',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Foto del vehículo al entregarlo *',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Tomar foto'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galería'),
                ),
              ],
            ),
            if (_foto != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(_foto!.name),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmado,
              onChanged: (value) =>
                  setState(() => _confirmado = value ?? false),
              title: const Text(
                'Confirmo que el vehículo fue entregado y la persona manifestó conformidad con la memoria descriptiva.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Guardando…' : 'Confirmar entrega'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool required = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (value) => (value ?? '').trim().isEmpty ? 'Campo obligatorio' : null
          : null,
    ),
  );
}
