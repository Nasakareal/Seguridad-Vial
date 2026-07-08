import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/app_drawer.dart';
import '../login_screen.dart';

class RndFaltasAdministrativasScreen extends StatefulWidget {
  const RndFaltasAdministrativasScreen({super.key});

  @override
  State<RndFaltasAdministrativasScreen> createState() =>
      _RndFaltasAdministrativasScreenState();
}

class _RndFaltasAdministrativasScreenState
    extends State<RndFaltasAdministrativasScreen> {
  final _formKey = GlobalKey<FormState>();
  final _elementoCtrl = TextEditingController();
  final _cargoOtroCtrl = TextEditingController();
  final _adscripcionCtrl = TextEditingController();
  final _lugarCalleCtrl = TextEditingController();
  final _lugarReferenciaCtrl = TextEditingController();
  final _localidadOtroCtrl = TextEditingController();
  final _municipioOtroCtrl = TextEditingController();
  final _detenidoNombreCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController(text: 'Sin alias referido');
  final _edadCtrl = TextEditingController();
  final _unidadNumeroCtrl = TextEditingController();
  final _rutaDetalleCtrl = TextEditingController();

  DateTime _fechaHora = DateTime.now();
  String _cargo = 'Policía Estatal';
  String _tiempo = _tiempoOptions.first.value;
  String _forma = _formaOptions.first.value;
  String _motivo = _motivoOptions.first.value;
  String _municipio = 'Morelia';
  String _localidad = 'Morelia';
  String _nacionalidad = 'Mexicana';
  String _lesiones = _lesionesOptions.first.value;
  String _delincuenciaOrganizada = _delincuenciaOptions.first.value;
  String _complexion = _complexionOptions.first.value;
  String _tipoUnidad = 'Patrulla';
  String _destino = _destinoJusticiaCivica;
  String _ruta = _rutaOptions.first.value;

  bool _defaultsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserDefaults());
  }

  @override
  void dispose() {
    _elementoCtrl.dispose();
    _cargoOtroCtrl.dispose();
    _adscripcionCtrl.dispose();
    _lugarCalleCtrl.dispose();
    _lugarReferenciaCtrl.dispose();
    _localidadOtroCtrl.dispose();
    _municipioOtroCtrl.dispose();
    _detenidoNombreCtrl.dispose();
    _aliasCtrl.dispose();
    _edadCtrl.dispose();
    _unidadNumeroCtrl.dispose();
    _rutaDetalleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserDefaults() async {
    if (_defaultsLoaded) return;
    _defaultsLoaded = true;

    final payload = await AuthService.getCurrentUserPayload(refresh: false);
    final nombre =
        _readString(payload, const ['name', 'nombre', 'full_name']) ??
        await AuthService.getUserName(refreshIfMissing: false);
    final adscripcion =
        _readNestedString(payload?['unidad'], const ['nombre', 'name']) ??
        _readString(payload, const [
          'unidad_nombre',
          'unidadName',
          'adscripcion',
          'adscripción',
          'area',
        ]);

    if (!mounted) return;
    setState(() {
      if ((nombre ?? '').trim().isNotEmpty) {
        _elementoCtrl.text = nombre!.trim();
      }
      if ((adscripcion ?? '').trim().isNotEmpty) {
        _adscripcionCtrl.text = adscripcion!.trim();
      }
    });
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await TrackingService.stop();
    } catch (_) {}

    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _pickFechaHora() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _fechaHora,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaHora),
    );
    if (time == null || !mounted) return;

    setState(() {
      _fechaHora = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String _buildMensaje({bool allowPending = false}) {
    String pending(String value) {
      final text = value.trim();
      if (text.isNotEmpty) return text;
      return allowPending ? 'PENDIENTE' : '';
    }

    final cargo = _cargo == 'Otro' ? pending(_cargoOtroCtrl.text) : _cargo;
    final municipio = _municipio == 'Otro'
        ? pending(_municipioOtroCtrl.text)
        : _municipio;
    final localidad = _localidad == 'Otra'
        ? pending(_localidadOtroCtrl.text)
        : _localidad;
    final rutaDetalle = _rutaDetalleCtrl.text.trim();
    final rutaTexto = rutaDetalle.isEmpty
        ? 'Del lugar de detención a $_destino, por $_ruta.'
        : 'Del lugar de detención a $_destino, por $_ruta. Detalle: $rutaDetalle.';

    return [
      '🚨 DATOS PARA RND DE FALTAS ADMINISTRATIVAS 🚨',
      '',
      '👮 ELEMENTOS',
      'Nombre: ${pending(_elementoCtrl.text)}',
      'Cargo: $cargo',
      'Adscripción: ${pending(_adscripcionCtrl.text)}',
      '',
      '📋 DETENCIÓN',
      'Fecha/hora: ${_formatDateTime(_fechaHora)}',
      'Tiempo: $_tiempo',
      'Forma: $_forma',
      'Motivo de detención: $_motivo',
      '',
      '📍 LUGAR',
      'Municipio: $municipio',
      'Localidad: $localidad',
      'Calle/número: ${pending(_lugarCalleCtrl.text)}',
      'Referencia: ${pending(_lugarReferenciaCtrl.text)}',
      '',
      '🧍 DETENIDO',
      'Nombre: ${pending(_detenidoNombreCtrl.text)}',
      'Alias: ${pending(_aliasCtrl.text)}',
      'Nacionalidad: $_nacionalidad',
      'Edad: ${pending(_edadCtrl.text)} años',
      'Lesiones visibles: $_lesiones',
      'Delincuencia organizada: $_delincuenciaOrganizada',
      'Complexión: $_complexion',
      '',
      '🚔 TRASLADO',
      'Ruta: $rutaTexto',
      'Unidad: $_tipoUnidad ${pending(_unidadNumeroCtrl.text)}',
    ].join('\n');
  }

  Future<void> _copyMessage() async {
    if (!_validate()) return;
    await Clipboard.setData(ClipboardData(text: _buildMensaje()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mensaje RND copiado.')));
  }

  Future<void> _shareMessage() async {
    if (!_validate()) return;
    final message = _buildMensaje();
    final uri = Uri.parse(
      'https://wa.me/$_barandillasWhatsappNumber?text=${Uri.encodeComponent(message)}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) return;

    await Share.share(message);
  }

  bool _validate() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa los campos marcados.')),
      );
    }
    return ok;
  }

  void _clear() {
    setState(() {
      _fechaHora = DateTime.now();
      _cargo = 'Policía Estatal';
      _tiempo = _tiempoOptions.first.value;
      _forma = _formaOptions.first.value;
      _motivo = _motivoOptions.first.value;
      _municipio = 'Morelia';
      _localidad = 'Morelia';
      _nacionalidad = 'Mexicana';
      _lesiones = _lesionesOptions.first.value;
      _delincuenciaOrganizada = _delincuenciaOptions.first.value;
      _complexion = _complexionOptions.first.value;
      _tipoUnidad = 'Patrulla';
      _destino = _destinoJusticiaCivica;
      _ruta = _rutaOptions.first.value;
      _cargoOtroCtrl.clear();
      _lugarCalleCtrl.clear();
      _lugarReferenciaCtrl.clear();
      _localidadOtroCtrl.clear();
      _municipioOtroCtrl.clear();
      _detenidoNombreCtrl.clear();
      _aliasCtrl.text = 'Sin alias referido';
      _edadCtrl.clear();
      _unidadNumeroCtrl.clear();
      _rutaDetalleCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagePreview = _buildMensaje(allowPending: true);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Solicitar RND'),
        actions: const [AccountMenuAction()],
      ),
      drawer: const AppDrawer(trackingOn: false),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copyMessage,
                icon: const Icon(Icons.copy),
                label: const Text('Copiar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _shareMessage,
                icon: const Icon(Icons.share),
                label: const Text('WhatsApp'),
              ),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            _Header(onClear: _clear),
            const SizedBox(height: 12),
            _Section(
              icon: Icons.local_police_outlined,
              title: 'Elementos',
              children: [
                _text(_elementoCtrl, 'Nombre del elemento *', Icons.person),
                _dropdown(
                  label: 'Cargo *',
                  icon: Icons.badge_outlined,
                  value: _cargo,
                  options: _cargoOptions,
                  onChanged: (value) => setState(() => _cargo = value),
                ),
                if (_cargo == 'Otro')
                  _text(_cargoOtroCtrl, 'Cargo / nombramiento *', Icons.edit),
                _text(
                  _adscripcionCtrl,
                  'Adscripción *',
                  Icons.apartment_outlined,
                ),
              ],
            ),
            _Section(
              icon: Icons.assignment_late_outlined,
              title: 'Detención',
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: const Text('Fecha y hora'),
                  subtitle: Text(_formatDateTime(_fechaHora)),
                  trailing: OutlinedButton(
                    onPressed: _pickFechaHora,
                    child: const Text('Cambiar'),
                  ),
                ),
                _choice(
                  title: 'Tiempo',
                  value: _tiempo,
                  options: _tiempoOptions,
                  onChanged: (value) => setState(() => _tiempo = value),
                ),
                _choice(
                  title: 'Forma',
                  value: _forma,
                  options: _formaOptions,
                  onChanged: (value) => setState(() => _forma = value),
                ),
                _dropdown(
                  label: 'Motivo de detención *',
                  icon: Icons.gavel_outlined,
                  value: _motivo,
                  options: _motivoOptions,
                  onChanged: (value) => setState(() => _motivo = value),
                ),
              ],
            ),
            _Section(
              icon: Icons.place_outlined,
              title: 'Lugar',
              children: [
                _dropdown(
                  label: 'Municipio *',
                  icon: Icons.location_city,
                  value: _municipio,
                  options: _municipioOptions,
                  onChanged: (value) => setState(() => _municipio = value),
                ),
                if (_municipio == 'Otro')
                  _text(_municipioOtroCtrl, 'Municipio *', Icons.edit_location),
                _dropdown(
                  label: 'Localidad *',
                  icon: Icons.map_outlined,
                  value: _localidad,
                  options: _localidadOptions,
                  onChanged: (value) => setState(() => _localidad = value),
                ),
                if (_localidad == 'Otra')
                  _text(_localidadOtroCtrl, 'Localidad *', Icons.edit_location),
                _text(
                  _lugarCalleCtrl,
                  'Calle y número *',
                  Icons.signpost_outlined,
                ),
                _text(
                  _lugarReferenciaCtrl,
                  'Referencia *',
                  Icons.near_me_outlined,
                ),
              ],
            ),
            _Section(
              icon: Icons.person_pin_outlined,
              title: 'Detenido',
              children: [
                _text(
                  _detenidoNombreCtrl,
                  'Nombre del detenido *',
                  Icons.person,
                ),
                _text(_aliasCtrl, 'Alias', Icons.record_voice_over_outlined),
                _dropdown(
                  label: 'Nacionalidad *',
                  icon: Icons.flag_circle_outlined,
                  value: _nacionalidad,
                  options: _nacionalidadOptions,
                  onChanged: (value) => setState(() => _nacionalidad = value),
                ),
                _text(
                  _edadCtrl,
                  'Edad aproximada *',
                  Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _ageValidator,
                ),
                _choice(
                  title: 'Lesiones visibles',
                  value: _lesiones,
                  options: _lesionesOptions,
                  onChanged: (value) => setState(() => _lesiones = value),
                ),
                _choice(
                  title: 'Delincuencia organizada',
                  value: _delincuenciaOrganizada,
                  options: _delincuenciaOptions,
                  onChanged: (value) =>
                      setState(() => _delincuenciaOrganizada = value),
                ),
                _dropdown(
                  label: 'Complexión *',
                  icon: Icons.accessibility_new,
                  value: _complexion,
                  options: _complexionOptions,
                  onChanged: (value) => setState(() => _complexion = value),
                ),
              ],
            ),
            _Section(
              icon: Icons.local_taxi_outlined,
              title: 'Traslado',
              children: [
                _dropdown(
                  label: 'Destino *',
                  icon: Icons.location_on_outlined,
                  value: _destino,
                  options: _destinoOptions,
                  onChanged: (value) => setState(() => _destino = value),
                ),
                _choice(
                  title: 'Ruta',
                  value: _ruta,
                  options: _rutaOptions,
                  onChanged: (value) => setState(() => _ruta = value),
                ),
                _text(
                  _rutaDetalleCtrl,
                  'Detalle de ruta (opcional)',
                  Icons.alt_route,
                  required: false,
                ),
                _dropdown(
                  label: 'Tipo de unidad *',
                  icon: Icons.directions_car_outlined,
                  value: _tipoUnidad,
                  options: _tipoUnidadOptions,
                  onChanged: (value) => setState(() => _tipoUnidad = value),
                ),
                _text(
                  _unidadNumeroCtrl,
                  'Número económico / unidad *',
                  Icons.confirmation_number_outlined,
                ),
              ],
            ),
            _Section(
              icon: Icons.message_outlined,
              title: 'Mensaje listo',
              children: [
                SelectableText(
                  messagePreview,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    height: 1.35,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _text(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        validator:
            validator ??
            (required
                ? (value) => (value ?? '').trim().isEmpty ? 'Requerido' : null
                : null),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<_Option> options,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        items: options
            .map(
              (item) => DropdownMenuItem<String>(
                value: item.value,
                child: Text(item.label),
              ),
            )
            .toList(),
        onChanged: (next) {
          if (next == null) return;
          onChanged(next);
        },
      ),
    );
  }

  Widget _choice({
    required String title,
    required String value,
    required List<_Option> options,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(option.label),
                  selected: value == option.value,
                  onSelected: (_) => onChanged(option.value),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String? _ageValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Requerido';
    final age = int.tryParse(text);
    if (age == null) return 'Número inválido';
    if (age < 12 || age > 110) return 'Revisa la edad';
    return null;
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClear;

  const _Header({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.fact_check_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solicitud RND',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Llena con selectores y copia el mensaje. No depende del backend.',
                  style: TextStyle(color: Colors.white70, height: 1.35),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Limpiar',
            onPressed: onClear,
            color: Colors.white,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Option {
  final String value;
  final String label;

  const _Option(this.value, this.label);
}

const _barandillasWhatsappNumber = '5214433163728';
const _destinoJusticiaCivica =
    'Dirección de Justicia Cívica y Mediación Administrativa';

const _cargoOptions = <_Option>[
  _Option('Policía Estatal', 'Policía Estatal'),
  _Option('Agente de Tránsito', 'Agente de Tránsito'),
  _Option('Policía Vial', 'Policía Vial'),
  _Option('Primer respondiente', 'Primer respondiente'),
  _Option('Responsable de turno', 'Responsable de turno'),
  _Option('Otro', 'Otro / según nombramiento'),
];

const _tiempoOptions = <_Option>[
  _Option('En flagrancia', 'En flagrancia'),
  _Option('Durante recorrido preventivo', 'Recorrido preventivo'),
  _Option('Posterior a reporte ciudadano', 'Reporte ciudadano'),
  _Option('Por señalamiento directo', 'Señalamiento directo'),
];

const _formaOptions = <_Option>[
  _Option('Sin uso de fuerza', 'Sin uso de fuerza'),
  _Option('Con comandos verbales', 'Comandos verbales'),
  _Option('Con control físico mínimo', 'Control físico mínimo'),
  _Option('Con apoyo de otra unidad', 'Apoyo de unidad'),
];

const _motivoOptions = <_Option>[
  _Option('Infracción', 'Infracción'),
  _Option(
    'Revisión de antecedentes en C5i; posible mandamiento u orden de aprehensión',
    'Antecedentes C5i',
  ),
  _Option(
    'Persona asegurada por probable falta administrativa; se elaborará ticket correspondiente en el sistema',
    'Probable falta administrativa',
  ),
  _Option(
    'Persona trasladada por alteración al orden público',
    'Alteración al orden',
  ),
  _Option(
    'Persona trasladada por riesgo o agresión a terceros',
    'Riesgo/agresión',
  ),
  _Option(
    'Persona trasladada por consumo aparente de alcohol o intoxicación en vía pública',
    'Alcohol/intoxicación',
  ),
  _Option(
    'Persona trasladada por obstrucción a la función policial',
    'Obstrucción autoridad',
  ),
  _Option(
    'Persona trasladada por solicitud de apoyo ciudadano',
    'Apoyo ciudadano',
  ),
];

const _municipioOptions = <_Option>[
  _Option('Morelia', 'Morelia'),
  _Option('Tarímbaro', 'Tarímbaro'),
  _Option('Charo', 'Charo'),
  _Option('Álvaro Obregón', 'Álvaro Obregón'),
  _Option('Otro', 'Otro'),
];

const _localidadOptions = <_Option>[
  _Option('Morelia', 'Morelia'),
  _Option('Atapaneo', 'Atapaneo'),
  _Option('Capula', 'Capula'),
  _Option('Cuto de la Esperanza', 'Cuto de la Esperanza'),
  _Option('Jesús del Monte', 'Jesús del Monte'),
  _Option('San Miguel del Monte', 'San Miguel del Monte'),
  _Option('Tenencia Morelos', 'Tenencia Morelos'),
  _Option('Tiripetío', 'Tiripetío'),
  _Option('Otra', 'Otra'),
];

const _nacionalidadOptions = <_Option>[
  _Option('Mexicana', 'Mexicana'),
  _Option('Estadounidense', 'Estadounidense'),
  _Option('Guatemalteca', 'Guatemalteca'),
  _Option('Hondureña', 'Hondureña'),
  _Option('Venezolana', 'Venezolana'),
  _Option('No proporcionada', 'No proporcionada'),
];

const _lesionesOptions = <_Option>[
  _Option('No se observan lesiones visibles', 'Sin lesiones visibles'),
  _Option('Refiere dolor, sin lesión visible', 'Refiere dolor'),
  _Option('Excoriación visible', 'Excoriación'),
  _Option('Contusión visible', 'Contusión'),
  _Option('Sangrado visible', 'Sangrado'),
  _Option('Requiere valoración médica', 'Valoración médica'),
];

const _delincuenciaOptions = <_Option>[
  _Option(
    'Al preguntarle, niega pertenecer o colaborar con delincuencia organizada',
    'Niega pertenecer',
  ),
  _Option(
    'Al preguntarle, manifiesta pertenecer o colaborar con delincuencia organizada',
    'Dice que sí pertenece',
  ),
  _Option('Se le preguntó y no quiso responder', 'No quiso responder'),
  _Option(
    'No fue posible preguntarle por seguridad, salud o condiciones del traslado',
    'No fue posible preguntar',
  ),
];

const _complexionOptions = <_Option>[
  _Option('Delgada', 'Delgada'),
  _Option('Media', 'Media'),
  _Option('Robusta', 'Robusta'),
  _Option('Atlética', 'Atlética'),
  _Option('Obesa', 'Obesa'),
  _Option('No determinada', 'No determinada'),
];

const _destinoOptions = <_Option>[
  _Option(_destinoJusticiaCivica, 'Justicia Cívica'),
  _Option(
    'Área médica previa y Dirección de Justicia Cívica y Mediación Administrativa',
    'Área médica + Justicia Cívica',
  ),
];

const _rutaOptions = <_Option>[
  _Option('ruta directa y segura', 'Directa y segura'),
  _Option('vialidades principales', 'Vialidades principales'),
  _Option('ruta con menor tráfico', 'Menor tráfico'),
  _Option('ruta con apoyo de otra unidad', 'Con apoyo'),
];

const _tipoUnidadOptions = <_Option>[
  _Option('Patrulla', 'Patrulla'),
  _Option('Motopatrulla', 'Motopatrulla'),
  _Option('Unidad oficial', 'Unidad oficial'),
  _Option('Unidad de apoyo', 'Unidad de apoyo'),
];

String _formatDateTime(DateTime value) {
  final d = value.day.toString().padLeft(2, '0');
  final m = value.month.toString().padLeft(2, '0');
  final y = value.year.toString();
  final h = value.hour.toString().padLeft(2, '0');
  final min = value.minute.toString().padLeft(2, '0');
  return '$d/$m/$y $h:$min horas';
}

String? _readString(Map<String, dynamic>? raw, List<String> keys) {
  if (raw == null) return null;
  for (final key in keys) {
    final value = raw[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return null;
}

String? _readNestedString(dynamic raw, List<String> keys) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  return _readString(map, keys);
}
