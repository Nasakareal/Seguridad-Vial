import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../services/velocidad_deformacion_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/app_drawer.dart';
import '../login_screen.dart';

class VelocidadDeformacionLaminasScreen extends StatefulWidget {
  const VelocidadDeformacionLaminasScreen({super.key});

  @override
  State<VelocidadDeformacionLaminasScreen> createState() =>
      _VelocidadDeformacionLaminasScreenState();
}

class _VelocidadDeformacionLaminasScreenState
    extends State<VelocidadDeformacionLaminasScreen> {
  final _formKey = GlobalKey<FormState>();
  final _masaController = TextEditingController();
  final _anchoController = TextEditingController();
  final _aController = TextEditingController();
  final _bController = TextEditingController();
  final _gController = TextEditingController();
  final _deformacionControllers = List<TextEditingController>.generate(
    6,
    (_) => TextEditingController(),
  );

  VelocidadDeformacionResult? _resultado;
  _RangoOperativoResult? _rangoResultado;
  String? _error;

  String _vehiculoId = _vehicleOptions.first.id;
  String _zonaId = _zoneOptions.first.id;
  String _severidadId = _severityOptions.first.id;
  String _anchoId = _widthOptions.first.id;

  @override
  void dispose() {
    _masaController.dispose();
    _anchoController.dispose();
    _aController.dispose();
    _bController.dispose();
    _gController.dispose();
    for (final controller in _deformacionControllers) {
      controller.dispose();
    }
    super.dispose();
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

  void _calcularRapido() {
    final vehiculo = _vehicleOptions.firstWhere(
      (option) => option.id == _vehiculoId,
    );
    final zona = _zoneOptions.firstWhere((option) => option.id == _zonaId);
    final severidad = _severityOptions.firstWhere(
      (option) => option.id == _severidadId,
    );
    final ancho = _widthOptions.firstWhere((option) => option.id == _anchoId);

    try {
      final min = VelocidadDeformacionService.calcular(
        VelocidadDeformacionInput(
          masaKg: vehiculo.masaKg,
          anchoDanoMetros: ancho.anchoMetros,
          coeficienteAKnPorMetro:
              vehiculo.coeficienteAKnPorMetro * zona.factorRigidez,
          coeficienteBKnPorMetro2:
              vehiculo.coeficienteBKnPorMetro2 * zona.factorRigidez,
          coeficienteGKjPorMetro: 0,
          deformacionesCm: List<double>.filled(6, severidad.minCm),
        ),
      );
      final max = VelocidadDeformacionService.calcular(
        VelocidadDeformacionInput(
          masaKg: vehiculo.masaKg,
          anchoDanoMetros: ancho.anchoMetros,
          coeficienteAKnPorMetro:
              vehiculo.coeficienteAKnPorMetro * zona.factorRigidez,
          coeficienteBKnPorMetro2:
              vehiculo.coeficienteBKnPorMetro2 * zona.factorRigidez,
          coeficienteGKjPorMetro: 0,
          deformacionesCm: List<double>.filled(6, severidad.maxCm),
        ),
      );

      setState(() {
        _rangoResultado = _RangoOperativoResult(
          minKmh: min.velocidadEquivalenteKmh,
          maxKmh: max.velocidadEquivalenteKmh,
          minEnergiaKj: min.energiaKj,
          maxEnergiaKj: max.energiaKj,
          resumen:
              '${vehiculo.label}, ${zona.label.toLowerCase()}, ${severidad.label.toLowerCase()}',
        );
        _resultado = null;
        _error = null;
      });
    } on ArgumentError catch (e) {
      setState(() {
        _rangoResultado = null;
        _resultado = null;
        _error = e.message?.toString() ?? e.toString();
      });
    }
  }

  void _calcular() {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _resultado = null;
        _rangoResultado = null;
        _error = null;
      });
      return;
    }

    final deformaciones = _deformacionControllers
        .map((controller) => _parseDecimal(controller.text) ?? 0)
        .toList(growable: false);

    try {
      final resultado = VelocidadDeformacionService.calcular(
        VelocidadDeformacionInput(
          masaKg: _parseDecimal(_masaController.text)!,
          anchoDanoMetros: _parseDecimal(_anchoController.text)! / 100,
          coeficienteAKnPorMetro: _parseDecimal(_aController.text)!,
          coeficienteBKnPorMetro2: _parseDecimal(_bController.text)!,
          coeficienteGKjPorMetro: _parseDecimal(_gController.text),
          deformacionesCm: deformaciones,
        ),
      );

      setState(() {
        _resultado = resultado;
        _rangoResultado = null;
        _error = null;
      });
    } on ArgumentError catch (e) {
      setState(() {
        _resultado = null;
        _rangoResultado = null;
        _error = e.message?.toString() ?? e.toString();
      });
    }
  }

  void _limpiar() {
    setState(() {
      _vehiculoId = _vehicleOptions.first.id;
      _zonaId = _zoneOptions.first.id;
      _severidadId = _severityOptions.first.id;
      _anchoId = _widthOptions.first.id;
      _masaController.clear();
      _anchoController.clear();
      _aController.clear();
      _bController.clear();
      _gController.clear();
      for (final controller in _deformacionControllers) {
        controller.clear();
      }
      _resultado = null;
      _rangoResultado = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Velocidad por deformación'),
        actions: const [AccountMenuAction()],
      ),
      drawer: const AppDrawer(trackingOn: false),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _HeaderCard(onClear: _limpiar),
              const SizedBox(height: 14),
              const _WarningCard(),
              const SizedBox(height: 14),
              _InputCard(
                title: 'Modo operativo',
                children: [
                  const Text(
                    'No capturen coeficientes. Solo elijan lo que se observa en campo; la app dará un rango aproximado.',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _simpleSelect(
                    label: 'Tipo de vehículo',
                    icon: Icons.directions_car,
                    value: _vehiculoId,
                    options: _vehicleOptions,
                    onChanged: (value) {
                      setState(() {
                        _vehiculoId = value;
                        _resultado = null;
                        _rangoResultado = null;
                        _error = null;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  _simpleSelect(
                    label: 'Parte golpeada',
                    icon: Icons.car_crash,
                    value: _zonaId,
                    options: _zoneOptions,
                    onChanged: (value) {
                      setState(() {
                        _zonaId = value;
                        _resultado = null;
                        _rangoResultado = null;
                        _error = null;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  _simpleSelect(
                    label: 'Qué tanto se hundió',
                    icon: Icons.compress,
                    value: _severidadId,
                    options: _severityOptions,
                    onChanged: (value) {
                      setState(() {
                        _severidadId = value;
                        _resultado = null;
                        _rangoResultado = null;
                        _error = null;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  _simpleSelect(
                    label: 'Qué tanto ancho se dañó',
                    icon: Icons.width_normal,
                    value: _anchoId,
                    options: _widthOptions,
                    onChanged: (value) {
                      setState(() {
                        _anchoId = value;
                        _resultado = null;
                        _rangoResultado = null;
                        _error = null;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.calculate),
                    label: const Text('Calcular rango orientativo'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onPressed: _calcularRapido,
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _MessageCard(
                  color: Colors.red,
                  icon: Icons.error_outline,
                  title: 'No se puede calcular',
                  body: _error!,
                ),
              ],
              if (_rangoResultado != null) ...[
                const SizedBox(height: 14),
                _RangeResultCard(resultado: _rangoResultado!),
              ],
              const SizedBox(height: 14),
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  leading: const Icon(Icons.engineering),
                  title: const Text(
                    'Modo pericial avanzado',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text('Solo si tienes A/B/G y C1 a C6'),
                  children: [
                    TextFormField(
                      controller: _masaController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Masa del vehículo',
                        suffixText: 'kg',
                        prefixIcon: Icon(Icons.scale),
                      ),
                      validator: (value) =>
                          _requiredPositive(value, 'Captura la masa.'),
                      onChanged: (_) => _clearResult(),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _anchoController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Ancho directo dañado',
                        suffixText: 'cm',
                        prefixIcon: Icon(Icons.width_normal),
                        helperText:
                            'Captura centímetros: mide de extremo a extremo la zona de daño directo donde se tomaron C1 a C6.',
                      ),
                      validator: (value) =>
                          _requiredPositive(value, 'Captura el ancho dañado.'),
                      onChanged: (_) => _clearResult(),
                    ),
                    const SizedBox(height: 14),
                    const _MessageCard(
                      color: Colors.indigo,
                      icon: Icons.info_outline,
                      title: 'Qué va en A, B y G',
                      body:
                          'A: rigidez base del vehículo o zona golpeada, en kN/m. B: aumento de rigidez conforme avanza el aplastamiento, en kN/m2. G: umbral de daño, en kJ/m; si no lo tienes, déjalo vacío y la app lo calcula con A2/(2B).',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _aController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Coeficiente A',
                              suffixText: 'kN/m',
                              helperText:
                                  'Dato de tabla pericial, manual técnico o perito.',
                            ),
                            validator: (value) =>
                                _requiredNonNegative(value, 'Captura A.'),
                            onChanged: (_) => _clearResult(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _bController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Coeficiente B',
                              suffixText: 'kN/m2',
                              helperText:
                                  'Dato de rigidez progresiva de la misma tabla o fuente.',
                            ),
                            validator: (value) =>
                                _requiredPositive(value, 'Captura B.'),
                            onChanged: (_) => _clearResult(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _gController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Coeficiente G',
                        suffixText: 'kJ/m',
                        prefixIcon: Icon(Icons.functions),
                        helperText:
                            'Umbral de daño. Si no lo tienes, déjalo vacío; la app calcula A2/(2B).',
                      ),
                      validator: (value) => _optionalNonNegative(value),
                      onChanged: (_) => _clearResult(),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'C1 a C6 en centímetros. Si un punto no tuvo deformación, usa 0.',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (var i = 0; i < _deformacionControllers.length; i += 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _crushField(i)),
                            const SizedBox(width: 12),
                            Expanded(child: _crushField(i + 1)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 2),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.calculate),
                      label: const Text('Calcular exacto con datos periciales'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: _calcular,
                    ),
                    if (_resultado != null) ...[
                      const SizedBox(height: 14),
                      _ResultCard(resultado: _resultado!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _FormulaCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _simpleSelect({
    required String label,
    required IconData icon,
    required String value,
    required List<_SimpleOption> options,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      items: options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option.id,
              child: Text(option.label),
            ),
          )
          .toList(),
      onChanged: (selected) {
        if (selected == null) return;
        onChanged(selected);
      },
    );
  }

  Widget _crushField(int index) {
    return TextFormField(
      controller: _deformacionControllers[index],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: 'C${index + 1}', suffixText: 'cm'),
      validator: (value) =>
          _requiredNonNegative(value, 'Captura C${index + 1}.'),
      onChanged: (_) => _clearResult(),
    );
  }

  void _clearResult() {
    if (_resultado == null && _rangoResultado == null && _error == null) return;
    setState(() {
      _resultado = null;
      _rangoResultado = null;
      _error = null;
    });
  }

  String? _requiredPositive(String? value, String emptyMessage) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return emptyMessage;

    final parsed = _parseDecimal(raw);
    if (parsed == null) return 'Captura un número válido.';
    if (parsed <= 0) return 'Debe ser mayor a cero.';
    return null;
  }

  String? _requiredNonNegative(String? value, String emptyMessage) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return emptyMessage;

    final parsed = _parseDecimal(raw);
    if (parsed == null) return 'Captura un número válido.';
    if (parsed < 0) return 'No puede ser negativo.';
    return null;
  }

  String? _optionalNonNegative(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;

    final parsed = _parseDecimal(raw);
    if (parsed == null) return 'Captura un número válido.';
    if (parsed < 0) return 'No puede ser negativo.';
    return null;
  }
}

class _HeaderCard extends StatelessWidget {
  final VoidCallback onClear;

  const _HeaderCard({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.car_repair, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calculadora de deformación',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Convierte energía de aplastamiento en velocidad equivalente de barrera.',
                      style: TextStyle(
                        color: Color(0xFFDCE3F0),
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.refresh),
            label: const Text('Limpiar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: .35)),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard();

  @override
  Widget build(BuildContext context) {
    return const _MessageCard(
      color: Colors.orange,
      icon: Icons.warning_amber,
      title: 'No basta con ver la lámina',
      body:
          'Esta herramienta da un rango aproximado para orientar. Para un dictamen formal se deben confirmar mediciones, masas, ángulos y datos técnicos del vehículo.',
    );
  }
}

class _InputCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InputCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final VelocidadDeformacionResult resultado;

  const _ResultCard({required this.resultado});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resultado orientativo',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${resultado.velocidadEquivalenteKmh.toStringAsFixed(1)} km/h',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ResultChip(
                  label:
                      '${resultado.velocidadEquivalenteMs.toStringAsFixed(2)} m/s',
                ),
                _ResultChip(
                  label:
                      '${resultado.velocidadEquivalenteMph.toStringAsFixed(1)} mph',
                ),
                _ResultChip(
                  label:
                      '${resultado.energiaKj.toStringAsFixed(1)} kJ absorbidos',
                ),
                _ResultChip(
                  label:
                      'G ${resultado.coeficienteGUsadoKjPorMetro.toStringAsFixed(2)} kJ/m',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeResultCard extends StatelessWidget {
  final _RangoOperativoResult resultado;

  const _RangeResultCard({required this.resultado});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rango orientativo',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              resultado.resumen,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${resultado.minKmh.toStringAsFixed(0)} - ${resultado.maxKmh.toStringAsFixed(0)} km/h',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ResultChip(
                  label:
                      '${resultado.minEnergiaKj.toStringAsFixed(0)} - ${resultado.maxEnergiaKj.toStringAsFixed(0)} kJ',
                ),
                const _ResultChip(label: 'EES/EBS aproximado'),
                const _ResultChip(label: 'No es velocidad final de dictamen'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  final String label;

  const _ResultChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FormulaCard extends StatelessWidget {
  const _FormulaCard();

  @override
  Widget build(BuildContext context) {
    return const _MessageCard(
      color: Colors.indigo,
      icon: Icons.info_outline,
      title: 'Criterio de cálculo',
      body:
          'El modo operativo usa valores genéricos por tipo de vehículo y daño para producir un rango. El modo avanzado usa A/B/G y C1-C6. En ambos casos el resultado es EES/EBS aproximado; para velocidad real del hecho se requiere reconstrucción completa.',
    );
  }
}

class _MessageCard extends StatelessWidget {
  final MaterialColor color;
  final IconData icon;
  final String title;
  final String body;

  const _MessageCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: color.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color.shade900,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleOption {
  final String id;
  final String label;

  const _SimpleOption({required this.id, required this.label});
}

class _VehicleOption extends _SimpleOption {
  final double masaKg;
  final double coeficienteAKnPorMetro;
  final double coeficienteBKnPorMetro2;

  const _VehicleOption({
    required super.id,
    required super.label,
    required this.masaKg,
    required this.coeficienteAKnPorMetro,
    required this.coeficienteBKnPorMetro2,
  });
}

class _ZoneOption extends _SimpleOption {
  final double factorRigidez;

  const _ZoneOption({
    required super.id,
    required super.label,
    required this.factorRigidez,
  });
}

class _SeverityOption extends _SimpleOption {
  final double minCm;
  final double maxCm;

  const _SeverityOption({
    required super.id,
    required super.label,
    required this.minCm,
    required this.maxCm,
  });
}

class _WidthOption extends _SimpleOption {
  final double anchoMetros;

  const _WidthOption({
    required super.id,
    required super.label,
    required this.anchoMetros,
  });
}

class _RangoOperativoResult {
  final double minKmh;
  final double maxKmh;
  final double minEnergiaKj;
  final double maxEnergiaKj;
  final String resumen;

  const _RangoOperativoResult({
    required this.minKmh,
    required this.maxKmh,
    required this.minEnergiaKj,
    required this.maxEnergiaKj,
    required this.resumen,
  });
}

const _vehicleOptions = <_VehicleOption>[
  _VehicleOption(
    id: 'auto',
    label: 'Automóvil o sedán',
    masaKg: 1400,
    coeficienteAKnPorMetro: 280,
    coeficienteBKnPorMetro2: 1300,
  ),
  _VehicleOption(
    id: 'suv_pickup',
    label: 'Camioneta, SUV o pickup',
    masaKg: 2000,
    coeficienteAKnPorMetro: 380,
    coeficienteBKnPorMetro2: 1900,
  ),
  _VehicleOption(
    id: 'camioneta_carga',
    label: 'Camioneta de carga ligera',
    masaKg: 3200,
    coeficienteAKnPorMetro: 520,
    coeficienteBKnPorMetro2: 2600,
  ),
];

const _zoneOptions = <_ZoneOption>[
  _ZoneOption(
    id: 'frente_trasera',
    label: 'Frente o parte trasera',
    factorRigidez: 1,
  ),
  _ZoneOption(id: 'lateral', label: 'Costado/lateral', factorRigidez: 0.65),
];

const _severityOptions = <_SeverityOption>[
  _SeverityOption(id: 'leve', label: 'Poco hundido', minCm: 5, maxCm: 15),
  _SeverityOption(
    id: 'medio',
    label: 'Hundimiento medio',
    minCm: 15,
    maxCm: 30,
  ),
  _SeverityOption(id: 'fuerte', label: 'Muy hundido', minCm: 30, maxCm: 50),
  _SeverityOption(
    id: 'severo',
    label: 'Hundimiento severo',
    minCm: 50,
    maxCm: 80,
  ),
];

const _widthOptions = <_WidthOption>[
  _WidthOption(
    id: 'poco',
    label: 'Solo una esquina o parte pequeña',
    anchoMetros: 0.8,
  ),
  _WidthOption(
    id: 'medio',
    label: 'Aproximadamente media parte',
    anchoMetros: 1.3,
  ),
  _WidthOption(
    id: 'amplio',
    label: 'Casi todo el frente/costado',
    anchoMetros: 1.8,
  ),
];

double? _parseDecimal(String value) {
  final normalized = value.trim().replaceAll(' ', '').replaceAll(',', '.');
  return double.tryParse(normalized);
}
