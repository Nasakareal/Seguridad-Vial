import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/vehiculos/estados_republica.dart';
import '../../../core/vehiculos/vehiculo_taxonomia.dart';
import '../../../models/actividad.dart';
import '../../../models/dispositivo_relacionados.dart';
import '../../../services/vehiculo_form_service.dart';

class DispositivoRelacionadoResult {
  final DispositivoVehiculoRelacionado? vehiculo;
  final DispositivoPersonaRelacionada? persona;

  const DispositivoRelacionadoResult.vehiculo(this.vehiculo) : persona = null;
  const DispositivoRelacionadoResult.persona(this.persona) : vehiculo = null;
}

Future<DispositivoRelacionadoResult?> showDispositivoRelacionadoModal(
  BuildContext context,
) {
  return showModalBottomSheet<DispositivoRelacionadoResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _DispositivoRelacionadoModal(),
  );
}

class _DispositivoRelacionadoModal extends StatefulWidget {
  const _DispositivoRelacionadoModal();

  @override
  State<_DispositivoRelacionadoModal> createState() =>
      _DispositivoRelacionadoModalState();
}

class _DispositivoRelacionadoModalState
    extends State<_DispositivoRelacionadoModal> {
  final _vehiculoFormKey = GlobalKey<FormState>();
  final _personaFormKey = GlobalKey<FormState>();

  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _lineaCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _placasCtrl = TextEditingController();
  final _serieCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController(text: '0');
  final _tarjetaCtrl = TextEditingController();
  final _gruaCtrl = TextEditingController();
  final _corralonCtrl = TextEditingController();
  final _aseguradoraCtrl = TextEditingController();
  final _vehiculoObservacionesCtrl = TextEditingController();

  final _personaNombreCtrl = TextEditingController();
  final _personaCurpCtrl = TextEditingController();
  final _personaTelefonoCtrl = TextEditingController();
  final _personaDomicilioCtrl = TextEditingController();
  final _personaOcupacionCtrl = TextEditingController();
  final _personaEdadCtrl = TextEditingController();
  final _personaTipoLicenciaCtrl = TextEditingController();
  final _personaEstadoLicenciaCtrl = TextEditingController();
  final _personaNumeroLicenciaCtrl = TextEditingController();
  final _personaObservacionesCtrl = TextEditingController();

  String? _tipoGeneral;
  String? _carroceria;
  String? _estadoPlacas;
  String _tipoServicio = 'PARTICULAR';
  String _vehiculoRol = 'IMPACTADO';
  bool _antecedenteVehiculo = false;

  String _personaTipo = 'IMPACTADA';
  String? _personaSexo;
  DateTime? _personaVigenciaLicencia;
  bool _personaPermanente = false;
  bool _personaCinturon = false;
  bool _personaAntecedentes = false;
  bool _personaCertificadoLesiones = false;
  bool _personaCertificadoAlcoholemia = false;
  bool _personaAlientoEtilico = false;

  @override
  void dispose() {
    for (final controller in [
      _marcaCtrl,
      _modeloCtrl,
      _lineaCtrl,
      _colorCtrl,
      _placasCtrl,
      _serieCtrl,
      _capacidadCtrl,
      _tarjetaCtrl,
      _gruaCtrl,
      _corralonCtrl,
      _aseguradoraCtrl,
      _vehiculoObservacionesCtrl,
      _personaNombreCtrl,
      _personaCurpCtrl,
      _personaTelefonoCtrl,
      _personaDomicilioCtrl,
      _personaOcupacionCtrl,
      _personaEdadCtrl,
      _personaTipoLicenciaCtrl,
      _personaEstadoLicenciaCtrl,
      _personaNumeroLicenciaCtrl,
      _personaObservacionesCtrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _t(TextEditingController c) => c.text.trim();

  String? _nullIfEmpty(String value) {
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  String _upper(String value) => value.trim().toUpperCase();

  InputDecoration _dec(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  String? _requiredSelect(String? value) {
    return (value ?? '').trim().isEmpty ? 'Requerido' : null;
  }

  String _fmtYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _tipoServicioFromQr(String? value) {
    final clean = (value ?? '').trim().toUpperCase();
    if (clean.contains('PUBLIC')) return 'PUBLICO';
    if (clean.contains('OFICIAL')) return 'OFICIAL';
    return 'PARTICULAR';
  }

  bool _isTipoGeneralDisponible(String? value) {
    final current = (value ?? '').trim();
    if (current.isEmpty) return false;
    return VehiculoTaxonomia.tiposGenerales.any(
      (item) => item['value'] == current,
    );
  }

  bool _isCarroceriaDisponible(String? tipoGeneral, String? value) {
    final current = (value ?? '').trim();
    if (current.isEmpty) return false;
    return VehiculoTaxonomia.carroceriasDeTipoGeneral(
      tipoGeneral,
    ).contains(current);
  }

  Future<void> _scanTarjetaCirculacion() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const _TarjetaCirculacionScannerScreen(),
      ),
    );
    final text = raw?.trim() ?? '';
    if (text.isEmpty || !mounted) return;

    final parsed = VehiculoFormService.parseTarjetaCirculacionQr(text);
    final applied = _applyTarjetaCirculacionData(parsed);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          applied > 0
              ? 'Se llenaron $applied campos desde el QR.'
              : 'No se identificaron campos del vehículo en este QR.',
        ),
      ),
    );
  }

  int _applyTarjetaCirculacionData(VehiculoQrData parsed) {
    var applied = 0;

    bool setText(TextEditingController controller, String? value) {
      final cleaned = (value ?? '').trim();
      if (cleaned.isEmpty || controller.text.trim() == cleaned) return false;
      controller.text = cleaned;
      return true;
    }

    setState(() {
      if (setText(_marcaCtrl, parsed.marca)) applied += 1;
      if (setText(_lineaCtrl, parsed.linea)) applied += 1;
      if (setText(_modeloCtrl, parsed.modelo)) applied += 1;
      if (setText(_colorCtrl, parsed.color)) applied += 1;
      if (setText(_placasCtrl, parsed.placas)) applied += 1;
      if (setText(_serieCtrl, parsed.serie)) applied += 1;
      if (setText(_tarjetaCtrl, parsed.tarjetaCirculacionNombre)) {
        applied += 1;
      }

      final servicio = _tipoServicioFromQr(parsed.tipoServicio);
      if (_tipoServicio != servicio) {
        _tipoServicio = servicio;
        applied += 1;
      }

      final estado = parsed.estadoPlacas;
      if ((estado ?? '').trim().isNotEmpty && _estadoPlacas != estado) {
        _estadoPlacas = estado;
        applied += 1;
      }

      final tipoGeneral = parsed.tipoGeneral;
      if (_isTipoGeneralDisponible(tipoGeneral) &&
          _tipoGeneral != tipoGeneral) {
        _tipoGeneral = tipoGeneral;
        _carroceria = null;
        applied += 1;
      }

      final tipoCarroceria = parsed.tipoCarroceria;
      if (_isCarroceriaDisponible(_tipoGeneral, tipoCarroceria) &&
          _carroceria != tipoCarroceria) {
        _carroceria = tipoCarroceria;
        applied += 1;
      }
    });

    return applied;
  }

  void _submitVehiculo() {
    if (!_vehiculoFormKey.currentState!.validate()) return;

    final validation = VehiculoFormService.validateVehiculoBeforeSubmit(
      marca: _t(_marcaCtrl),
      linea: _t(_lineaCtrl),
      color: _t(_colorCtrl),
      tipoServicio: _tipoServicio,
      partesDanadas: '',
      tipoGeneral: _tipoGeneral,
      tipoCarroceria: _carroceria,
      placas: _t(_placasCtrl),
      estadoPlacas: _estadoPlacas,
      serie: _t(_serieCtrl),
      capacidad: _t(_capacidadCtrl),
      montoDanos: '',
      modelo: _t(_modeloCtrl),
      tarjetaCirculacionNombre: _t(_tarjetaCtrl),
      aseguradora: _t(_aseguradoraCtrl),
      requireMontoDanos: false,
      requirePartesDanadas: false,
    );

    if (validation != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validation)));
      return;
    }

    final vehiculo = ActividadVehiculo(
      marca: _upper(_t(_marcaCtrl)),
      modelo: _nullIfEmpty(_upper(_t(_modeloCtrl))),
      tipoGeneral: _tipoGeneral,
      tipo: _carroceria ?? '',
      linea: _upper(_t(_lineaCtrl)),
      color: _upper(_t(_colorCtrl)),
      placas: _nullIfEmpty(
        VehiculoFormService.normalizePlacas(_t(_placasCtrl)),
      ),
      estadoPlacas: _nullIfEmpty(
        VehiculoFormService.normalizeEstadoPlacas(_estadoPlacas) ?? '',
      ),
      serie: VehiculoFormService.normalizeSerie(_t(_serieCtrl)),
      capacidadPersonas: int.tryParse(_t(_capacidadCtrl)) ?? 0,
      tipoServicio: _tipoServicio,
      tarjetaCirculacionNombre: _nullIfEmpty(_upper(_t(_tarjetaCtrl))),
      grua: _nullIfEmpty(_upper(_t(_gruaCtrl))),
      corralon: _nullIfEmpty(_upper(_t(_corralonCtrl))),
      aseguradora: _nullIfEmpty(_upper(_t(_aseguradoraCtrl))),
      antecedenteVehiculo: _antecedenteVehiculo,
      montoDanos: null,
      partesDanadas: null,
    );

    Navigator.pop(
      context,
      DispositivoRelacionadoResult.vehiculo(
        DispositivoVehiculoRelacionado(
          vehiculo: vehiculo,
          rol: _vehiculoRol,
          observaciones: _nullIfEmpty(_upper(_t(_vehiculoObservacionesCtrl))),
        ),
      ),
    );
  }

  Future<void> _pickVigenciaLicencia() async {
    final initial = _personaVigenciaLicencia ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _personaVigenciaLicencia = picked);
  }

  void _submitPersona() {
    if (!_personaFormKey.currentState!.validate()) return;

    final validation = VehiculoFormService.validateConductorBeforeSubmit(
      nombre: _t(_personaNombreCtrl),
      telefono: _t(_personaTelefonoCtrl),
      domicilio: _t(_personaDomicilioCtrl),
      sexo: _personaSexo,
      ocupacion: _t(_personaOcupacionCtrl),
      edad: _t(_personaEdadCtrl),
      tipoLicencia: _t(_personaTipoLicenciaCtrl),
      estadoLicencia: _t(_personaEstadoLicenciaCtrl),
      numeroLicencia: _t(_personaNumeroLicenciaCtrl),
    );

    if (validation != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validation)));
      return;
    }

    Navigator.pop(
      context,
      DispositivoRelacionadoResult.persona(
        DispositivoPersonaRelacionada(
          nombre: _upper(_t(_personaNombreCtrl)),
          tipoParticipacion: _personaTipo,
          curp: _nullIfEmpty(_upper(_t(_personaCurpCtrl))),
          telefono: _nullIfEmpty(_t(_personaTelefonoCtrl)),
          domicilio: _nullIfEmpty(_upper(_t(_personaDomicilioCtrl))),
          sexo: _personaSexo,
          ocupacion: _nullIfEmpty(_upper(_t(_personaOcupacionCtrl))),
          edad: int.tryParse(_t(_personaEdadCtrl)),
          tipoLicencia: _nullIfEmpty(_upper(_t(_personaTipoLicenciaCtrl))),
          estadoLicencia: _nullIfEmpty(_upper(_t(_personaEstadoLicenciaCtrl))),
          vigenciaLicencia: _personaPermanente
              ? null
              : _personaVigenciaLicencia,
          numeroLicencia: _nullIfEmpty(_upper(_t(_personaNumeroLicenciaCtrl))),
          permanente: _personaPermanente,
          cinturon: _personaCinturon,
          antecedentes: _personaAntecedentes,
          certificadoLesiones: _personaCertificadoLesiones,
          certificadoAlcoholemia: _personaCertificadoAlcoholemia,
          alientoEtilico: _personaAlientoEtilico,
          observaciones: _nullIfEmpty(_upper(_t(_personaObservacionesCtrl))),
        ),
      ),
    );
  }

  Widget _vehicleForm() {
    final carrocerias = VehiculoTaxonomia.carroceriasDeTipoGeneral(
      _tipoGeneral,
    );
    final tienePlacas = _t(_placasCtrl).isNotEmpty;

    return Form(
      key: _vehiculoFormKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          ElevatedButton.icon(
            onPressed: _scanTarjetaCirculacion,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Escanear tarjeta de circulación'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _vehiculoRol,
            decoration: _dec('Rol', icon: Icons.flag),
            items: const [
              DropdownMenuItem(value: 'IMPACTADO', child: Text('Impactado')),
              DropdownMenuItem(
                value: 'INSPECCIONADO',
                child: Text('Inspeccionado'),
              ),
              DropdownMenuItem(value: 'APOYO', child: Text('Apoyo')),
              DropdownMenuItem(value: 'RECUPERADO', child: Text('Recuperado')),
              DropdownMenuItem(value: 'OTRO', child: Text('Otro')),
            ],
            onChanged: (value) =>
                setState(() => _vehiculoRol = value ?? 'IMPACTADO'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _marcaCtrl,
            decoration: _dec('Marca *', icon: Icons.local_offer),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _tipoGeneral,
            decoration: _dec('Tipo de vehículo *', icon: Icons.directions_car),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('-- Seleccione --'),
              ),
              ...VehiculoTaxonomia.tiposGenerales.map(
                (item) => DropdownMenuItem<String>(
                  value: item['value'],
                  child: Text(item['label'] ?? ''),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _tipoGeneral = value;
                _carroceria = null;
              });
            },
            validator: _requiredSelect,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _carroceria,
            decoration: _dec('Carrocería *', icon: Icons.merge_type),
            items: carrocerias.isEmpty
                ? const [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('-- Seleccione un tipo primero --'),
                    ),
                  ]
                : [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('-- Seleccione --'),
                    ),
                    ...carrocerias.map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    ),
                  ],
            onChanged: carrocerias.isEmpty
                ? null
                : (value) => setState(() => _carroceria = value),
            validator: _requiredSelect,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _lineaCtrl,
            decoration: _dec('Línea *', icon: Icons.text_fields),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _modeloCtrl,
            decoration: _dec('Modelo', icon: Icons.calendar_month),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _colorCtrl,
            decoration: _dec('Color *', icon: Icons.color_lens),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _placasCtrl,
            decoration: _dec('Placas', icon: Icons.credit_card),
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
          if (tienePlacas) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _estadoPlacas,
              decoration: _dec('Estado de placas *', icon: Icons.map),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('-- Seleccione --'),
                ),
                ...EstadosRepublica.estados.map(
                  (item) => DropdownMenuItem<String>(
                    value: item['value'],
                    child: Text(item['label'] ?? ''),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _estadoPlacas = value),
              validator: _requiredSelect,
            ),
          ],
          const SizedBox(height: 10),
          TextFormField(
            controller: _serieCtrl,
            decoration: _dec('Serie/NIV', icon: Icons.confirmation_number),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _capacidadCtrl,
            keyboardType: TextInputType.number,
            decoration: _dec('Capacidad de personas *', icon: Icons.people),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _tipoServicio,
            decoration: _dec(
              'Tipo de servicio *',
              icon: Icons.miscellaneous_services,
            ),
            items: const [
              DropdownMenuItem(value: 'PARTICULAR', child: Text('Particular')),
              DropdownMenuItem(value: 'OFICIAL', child: Text('Oficial')),
              DropdownMenuItem(value: 'PUBLICO', child: Text('Público')),
            ],
            onChanged: (value) =>
                setState(() => _tipoServicio = value ?? 'PARTICULAR'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _tarjetaCtrl,
            decoration: _dec('Nombre en tarjeta', icon: Icons.badge),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _gruaCtrl,
            decoration: _dec('Grúa', icon: Icons.local_shipping),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _corralonCtrl,
            decoration: _dec('Corralón', icon: Icons.warehouse),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _aseguradoraCtrl,
            decoration: _dec('Aseguradora', icon: Icons.security),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _vehiculoObservacionesCtrl,
            minLines: 2,
            maxLines: 3,
            decoration: _dec('Observaciones', icon: Icons.notes),
            textCapitalization: TextCapitalization.characters,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Antecedente del vehículo'),
            value: _antecedenteVehiculo,
            onChanged: (value) => setState(() {
              _antecedenteVehiculo = value;
            }),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _submitVehiculo,
            icon: const Icon(Icons.add),
            label: const Text('Agregar vehículo'),
          ),
        ],
      ),
    );
  }

  Widget _personForm() {
    return Form(
      key: _personaFormKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          TextFormField(
            controller: _personaNombreCtrl,
            decoration: _dec('Nombre *', icon: Icons.person),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _personaTipo,
            decoration: _dec('Participación', icon: Icons.flag),
            items: const [
              DropdownMenuItem(value: 'IMPACTADA', child: Text('Impactada')),
              DropdownMenuItem(
                value: 'INSPECCIONADA',
                child: Text('Inspeccionada'),
              ),
              DropdownMenuItem(value: 'CONDUCTOR', child: Text('Conductor')),
              DropdownMenuItem(
                value: 'ACOMPANANTE',
                child: Text('Acompañante'),
              ),
              DropdownMenuItem(value: 'PEATON', child: Text('Peatón')),
              DropdownMenuItem(value: 'TESTIGO', child: Text('Testigo')),
              DropdownMenuItem(value: 'OTRO', child: Text('Otro')),
            ],
            onChanged: (value) =>
                setState(() => _personaTipo = value ?? 'IMPACTADA'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _personaCurpCtrl,
            decoration: _dec('CURP', icon: Icons.badge),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _personaTelefonoCtrl,
            keyboardType: TextInputType.phone,
            decoration: _dec('Teléfono', icon: Icons.phone),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _personaDomicilioCtrl,
            decoration: _dec('Domicilio', icon: Icons.home),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _personaSexo,
            decoration: _dec('Sexo', icon: Icons.wc),
            items: const [
              DropdownMenuItem(value: null, child: Text('-- Seleccione --')),
              DropdownMenuItem(value: 'MASCULINO', child: Text('Masculino')),
              DropdownMenuItem(value: 'FEMENINO', child: Text('Femenino')),
              DropdownMenuItem(value: 'OTRO', child: Text('Otro')),
            ],
            onChanged: (value) => setState(() => _personaSexo = value),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _personaOcupacionCtrl,
            decoration: _dec('Ocupación', icon: Icons.work),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _personaEdadCtrl,
            keyboardType: TextInputType.number,
            decoration: _dec('Edad', icon: Icons.cake),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _personaTipoLicenciaCtrl,
            decoration: _dec('Tipo de licencia', icon: Icons.credit_card),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _personaEstadoLicenciaCtrl,
            decoration: _dec('Estado licencia', icon: Icons.map),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _personaNumeroLicenciaCtrl,
            decoration: _dec('Número licencia', icon: Icons.numbers),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('Vigencia licencia'),
            subtitle: Text(
              _personaPermanente
                  ? 'Permanente'
                  : (_personaVigenciaLicencia == null
                        ? 'Sin fecha'
                        : _fmtYmd(_personaVigenciaLicencia!)),
            ),
            trailing: OutlinedButton(
              onPressed: _personaPermanente ? null : _pickVigenciaLicencia,
              child: const Text('Elegir'),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Licencia permanente'),
            value: _personaPermanente,
            onChanged: (value) => setState(() {
              _personaPermanente = value;
              if (value) _personaVigenciaLicencia = null;
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cinturón'),
            value: _personaCinturon,
            onChanged: (value) => setState(() => _personaCinturon = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Antecedentes'),
            value: _personaAntecedentes,
            onChanged: (value) => setState(() => _personaAntecedentes = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Certificado de lesiones'),
            value: _personaCertificadoLesiones,
            onChanged: (value) =>
                setState(() => _personaCertificadoLesiones = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Certificado de alcoholemia'),
            value: _personaCertificadoAlcoholemia,
            onChanged: (value) =>
                setState(() => _personaCertificadoAlcoholemia = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aliento etílico'),
            value: _personaAlientoEtilico,
            onChanged: (value) =>
                setState(() => _personaAlientoEtilico = value),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _personaObservacionesCtrl,
            minLines: 3,
            maxLines: 4,
            decoration: _dec('Observaciones', icon: Icons.notes),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _submitPersona,
            icon: const Icon(Icons.add),
            label: const Text('Agregar persona'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: .92,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Agregar relacionado',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.directions_car), text: 'Vehículo'),
                Tab(icon: Icon(Icons.person), text: 'Persona'),
              ],
            ),
            Expanded(
              child: TabBarView(children: [_vehicleForm(), _personForm()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaCirculacionScannerScreen extends StatefulWidget {
  const _TarjetaCirculacionScannerScreen();

  @override
  State<_TarjetaCirculacionScannerScreen> createState() =>
      _TarjetaCirculacionScannerScreenState();
}

class _TarjetaCirculacionScannerScreenState
    extends State<_TarjetaCirculacionScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );
  bool _handled = false;

  void _handleDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim() ?? '';
      if (raw.isEmpty) continue;
      _handled = true;
      Navigator.pop(context, raw);
      return;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear tarjeta')),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _handleDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black.withValues(alpha: .65),
              child: const Text(
                'Apunta al QR de la tarjeta de circulación.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
