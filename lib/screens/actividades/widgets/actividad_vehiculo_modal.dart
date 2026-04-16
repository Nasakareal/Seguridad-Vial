import 'package:flutter/material.dart';

import '../../../core/vehiculos/estados_republica.dart';
import '../../../core/vehiculos/vehiculo_taxonomia.dart';
import '../../../models/actividad.dart';
import '../../../services/vehiculo_form_service.dart';

Future<ActividadVehiculo?> showActividadVehiculoModal(BuildContext context) {
  return showModalBottomSheet<ActividadVehiculo>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ActividadVehiculoModal(),
  );
}

class _ActividadVehiculoModal extends StatefulWidget {
  const _ActividadVehiculoModal();

  @override
  State<_ActividadVehiculoModal> createState() =>
      _ActividadVehiculoModalState();
}

class _ActividadVehiculoModalState extends State<_ActividadVehiculoModal> {
  final _formKey = GlobalKey<FormState>();

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
  final _montoDanosCtrl = TextEditingController(text: '0');
  final _partesDanadasCtrl = TextEditingController();

  String? _tipoGeneral;
  String? _carroceria;
  String? _estadoPlacas;
  String? _tipoServicio = 'PARTICULAR';
  bool _antecedenteVehiculo = false;

  @override
  void dispose() {
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _lineaCtrl.dispose();
    _colorCtrl.dispose();
    _placasCtrl.dispose();
    _serieCtrl.dispose();
    _capacidadCtrl.dispose();
    _tarjetaCtrl.dispose();
    _gruaCtrl.dispose();
    _corralonCtrl.dispose();
    _aseguradoraCtrl.dispose();
    _montoDanosCtrl.dispose();
    _partesDanadasCtrl.dispose();
    super.dispose();
  }

  String _t(TextEditingController c) => c.text.trim();

  String? _nullIfEmpty(String value) {
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

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

  String? _optionalLongText(String? value, String label) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (text.length > 10000) return '$label: máximo 10000 caracteres';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final placasClean = VehiculoFormService.normalizePlacas(_t(_placasCtrl));
    final estadoClean = VehiculoFormService.normalizeEstadoPlacas(
      _estadoPlacas,
    );
    final serieClean = VehiculoFormService.normalizeSerie(_t(_serieCtrl));
    final capacidad = int.tryParse(_t(_capacidadCtrl)) ?? 0;
    final montoDanos = double.tryParse(_t(_montoDanosCtrl));

    Navigator.pop(
      context,
      ActividadVehiculo(
        marca: _t(_marcaCtrl),
        modelo: _nullIfEmpty(_t(_modeloCtrl)),
        tipoGeneral: _tipoGeneral,
        tipo: _carroceria ?? '',
        linea: _t(_lineaCtrl),
        color: _t(_colorCtrl),
        placas: placasClean.isEmpty ? null : placasClean,
        estadoPlacas: placasClean.isEmpty ? null : estadoClean,
        serie: serieClean,
        capacidadPersonas: capacidad,
        tipoServicio: _tipoServicio ?? 'PARTICULAR',
        tarjetaCirculacionNombre: _nullIfEmpty(_t(_tarjetaCtrl)),
        grua: _nullIfEmpty(_t(_gruaCtrl)),
        corralon: _nullIfEmpty(_t(_corralonCtrl)),
        aseguradora: _nullIfEmpty(_t(_aseguradoraCtrl)),
        antecedenteVehiculo: _antecedenteVehiculo,
        montoDanos: montoDanos ?? 0,
        partesDanadas: _nullIfEmpty(_t(_partesDanadasCtrl)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final carrocerias = VehiculoTaxonomia.carroceriasDeTipoGeneral(
      _tipoGeneral,
    );
    final tienePlacas = _t(_placasCtrl).isNotEmpty;

    if (!tienePlacas && _estadoPlacas != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _estadoPlacas = null);
      });
    }

    return FractionallySizedBox(
      heightFactor: .92,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agregar vehículo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text('Solo datos del vehículo.'),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _marcaCtrl,
                decoration: _dec('Marca *', icon: Icons.local_offer),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => VehiculoFormService.validateRequiredText(
                  v,
                  max: 50,
                  label: 'Marca',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _tipoGeneral,
                decoration: _dec(
                  'Tipo de vehículo *',
                  icon: Icons.directions_car,
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('-- Seleccione --'),
                  ),
                  ...VehiculoTaxonomia.tiposGenerales.map((item) {
                    return DropdownMenuItem<String>(
                      value: item['value'],
                      child: Text(item['label'] ?? ''),
                    );
                  }),
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
                validator: (value) {
                  if ((_tipoGeneral ?? '').trim().isEmpty) return null;
                  return _requiredSelect(value);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _lineaCtrl,
                decoration: _dec('Línea *', icon: Icons.text_fields),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => VehiculoFormService.validateRequiredText(
                  v,
                  max: 50,
                  label: 'Línea',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _modeloCtrl,
                decoration: _dec('Modelo', icon: Icons.calendar_month),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => VehiculoFormService.validateOptionalText(
                  v,
                  max: 10,
                  label: 'Modelo',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _colorCtrl,
                decoration: _dec('Color *', icon: Icons.color_lens),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => VehiculoFormService.validateRequiredText(
                  v,
                  max: 30,
                  label: 'Color',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _placasCtrl,
                decoration: _dec('Placas', icon: Icons.credit_card),
                textCapitalization: TextCapitalization.characters,
                validator: VehiculoFormService.validatePlacas,
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
                    ...EstadosRepublica.estados.map((item) {
                      return DropdownMenuItem<String>(
                        value: item['value'],
                        child: Text(item['label'] ?? ''),
                      );
                    }),
                  ],
                  onChanged: (value) => setState(() => _estadoPlacas = value),
                  validator: (value) {
                    if (!tienePlacas) return null;
                    return _requiredSelect(value);
                  },
                ),
              ],
              const SizedBox(height: 10),
              TextFormField(
                controller: _serieCtrl,
                decoration: _dec('Serie', icon: Icons.confirmation_number),
                textCapitalization: TextCapitalization.characters,
                validator: VehiculoFormService.validateSerie,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _capacidadCtrl,
                keyboardType: TextInputType.number,
                decoration: _dec('Capacidad de personas *', icon: Icons.people),
                validator: VehiculoFormService.validateCapacidad,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _tipoServicio,
                decoration: _dec(
                  'Tipo de servicio *',
                  icon: Icons.miscellaneous_services,
                ),
                items: const [
                  DropdownMenuItem<String>(
                    value: 'PARTICULAR',
                    child: Text('Particular'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'OFICIAL',
                    child: Text('Oficial'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'PUBLICO',
                    child: Text('Público'),
                  ),
                ],
                onChanged: (value) => setState(() => _tipoServicio = value),
                validator: _requiredSelect,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _tarjetaCtrl,
                decoration: _dec('Tarjeta de circulación', icon: Icons.badge),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => VehiculoFormService.validateOptionalText(
                  v,
                  max: 60,
                  label: 'Tarjeta de circulación',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _gruaCtrl,
                decoration: _dec('Grúa', icon: Icons.local_shipping),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => VehiculoFormService.validateOptionalText(
                  v,
                  max: 255,
                  label: 'Grúa',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _corralonCtrl,
                decoration: _dec('Corralón', icon: Icons.warehouse),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => VehiculoFormService.validateOptionalText(
                  v,
                  max: 255,
                  label: 'Corralón',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _aseguradoraCtrl,
                decoration: _dec('Aseguradora', icon: Icons.security),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => VehiculoFormService.validateOptionalText(
                  v,
                  max: 100,
                  label: 'Aseguradora',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _montoDanosCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _dec('Monto de daños', icon: Icons.attach_money),
                validator: (v) =>
                    VehiculoFormService.validateMonto(v, required: false),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _partesDanadasCtrl,
                maxLines: 3,
                decoration: _dec('Partes dañadas', icon: Icons.car_crash),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => _optionalLongText(v, 'Partes dañadas'),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Antecedente del vehículo'),
                value: _antecedenteVehiculo,
                onChanged: (value) =>
                    setState(() => _antecedenteVehiculo = value),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.add),
                label: const Text('Agregar vehículo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActividadVehiculoCard extends StatelessWidget {
  final ActividadVehiculo vehiculo;
  final VoidCallback? onRemove;

  const ActividadVehiculoCard({
    super.key,
    required this.vehiculo,
    this.onRemove,
  });

  String _text(String? value, [String fallback = '—']) {
    final clean = (value ?? '').trim();
    return clean.isEmpty ? fallback : clean;
  }

  @override
  Widget build(BuildContext context) {
    final title = [
      vehiculo.marca,
      vehiculo.linea,
    ].where((item) => item.trim().isNotEmpty).join(' ');
    final placas = _text(vehiculo.placas, 'SIN PLACAS');
    final monto = vehiculo.montoDanos == null
        ? '—'
        : '\$${vehiculo.montoDanos!.toStringAsFixed(2)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.trim().isEmpty ? 'Vehículo' : title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vehiculo.modelo == null
                          ? 'Modelo no especificado'
                          : 'Modelo ${vehiculo.modelo}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Quitar',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(Icons.credit_card, placas),
              _chip(Icons.directions_car, _text(vehiculo.tipo, 'Tipo N/D')),
              _chip(Icons.color_lens, _text(vehiculo.color, 'Color N/D')),
              _chip(Icons.people, vehiculo.capacidadPersonas.toString()),
              _chip(Icons.miscellaneous_services, _text(vehiculo.tipoServicio)),
            ],
          ),
          const SizedBox(height: 10),
          _mini('Serie', _text(vehiculo.serie)),
          _mini('Grúa', _text(vehiculo.grua)),
          _mini('Corralón', _text(vehiculo.corralon)),
          _mini('Aseguradora', _text(vehiculo.aseguradora)),
          _mini('Daños', monto),
          if ((vehiculo.partesDanadas ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Partes dañadas',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(vehiculo.partesDanadas!.trim()),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              label: Text(
                vehiculo.antecedenteVehiculo
                    ? 'Antecedente: SÍ'
                    : 'Antecedente: NO',
              ),
              backgroundColor: vehiculo.antecedenteVehiculo
                  ? Colors.red.withValues(alpha: .12)
                  : Colors.green.withValues(alpha: .12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _mini(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
