import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../services/velocidad_frenado_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/app_drawer.dart';
import '../login_screen.dart';

enum _AbsCondition { sinAbs, conAbs, noSeSabe }

class VelocidadHuellaFrenadoScreen extends StatefulWidget {
  const VelocidadHuellaFrenadoScreen({super.key});

  @override
  State<VelocidadHuellaFrenadoScreen> createState() =>
      _VelocidadHuellaFrenadoScreenState();
}

class _VelocidadHuellaFrenadoScreenState
    extends State<VelocidadHuellaFrenadoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _distanciaController = TextEditingController();
  final _friccionController = TextEditingController();
  final _pendienteController = TextEditingController(text: '0');

  String _surfaceId = _surfaceOptions.first.id;
  _AbsCondition _absCondition = _AbsCondition.noSeSabe;
  PendienteFrenado _pendiente = PendienteFrenado.nivel;
  VelocidadFrenadoResult? _resultado;
  String? _error;

  _SurfaceOption get _selectedSurface =>
      _surfaceOptions.firstWhere((item) => item.id == _surfaceId);

  @override
  void dispose() {
    _distanciaController.dispose();
    _friccionController.dispose();
    _pendienteController.dispose();
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

  void _onSurfaceChanged(String? value) {
    if (value == null) return;

    final option = _surfaceOptions.firstWhere((item) => item.id == value);
    setState(() {
      _surfaceId = value;
      _resultado = null;
      _error = null;
      if (option.coefficient != null) {
        _friccionController.text = _formatCompact(option.coefficient!);
      } else {
        _friccionController.clear();
      }
    });
  }

  void _calcular() {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _resultado = null;
        _error = null;
      });
      return;
    }

    final distancia = _parseDecimal(_distanciaController.text)!;
    final friccion = _parseDecimal(_friccionController.text)!;
    final pendiente = _parseDecimal(_pendienteController.text) ?? 0;

    try {
      final resultado = VelocidadFrenadoService.calcular(
        VelocidadFrenadoInput(
          distanciaMetros: distancia,
          coeficienteFriccion: friccion,
          pendientePorcentaje: pendiente,
          pendiente: _pendiente,
        ),
      );

      setState(() {
        _resultado = resultado;
        _error = null;
      });
    } on ArgumentError catch (e) {
      setState(() {
        _resultado = null;
        _error = e.message?.toString() ?? e.toString();
      });
    }
  }

  void _limpiar() {
    setState(() {
      _surfaceId = _surfaceOptions.first.id;
      _absCondition = _AbsCondition.noSeSabe;
      _pendiente = PendienteFrenado.nivel;
      _distanciaController.clear();
      _friccionController.clear();
      _pendienteController.text = '0';
      _resultado = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedSurface = _selectedSurface;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Velocidad por huella de frenado'),
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
              _InputCard(
                children: [
                  TextFormField(
                    controller: _distanciaController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Longitud de la huella de frenado',
                      suffixText: 'm',
                      prefixIcon: Icon(Icons.straighten),
                      helperText:
                          'Mide la distancia usada para disipar velocidad por frenado.',
                    ),
                    validator: (value) =>
                        _requiredPositive(value, 'Captura la longitud.'),
                    onChanged: (_) => _clearResult(),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _surfaceId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Condición de la superficie',
                      prefixIcon: Icon(Icons.terrain),
                      helperText:
                          'Elige lo observado en campo; la app asigna el valor técnico.',
                    ),
                    validator: (value) => value == 'seleccionar'
                        ? 'Selecciona la superficie.'
                        : null,
                    items: _surfaceOptions
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: _onSurfaceChanged,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _friccionController,
                    enabled:
                        selectedSurface.coefficient != null ||
                        selectedSurface.isCustom,
                    readOnly: !selectedSurface.isCustom,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: selectedSurface.isCustom
                          ? 'Valor personalizado'
                          : 'Valor técnico usado por la app',
                      prefixIcon: const Icon(Icons.speed),
                      helperText: selectedSurface.isCustom
                          ? 'Captúralo solo si un perito o medición de campo te dio el valor.'
                          : 'No tienes que capturarlo: se llena automáticamente según la superficie.',
                    ),
                    validator: (value) => _requiredPositive(
                      value,
                      selectedSurface.isCustom
                          ? 'Captura el valor personalizado.'
                          : 'Selecciona una superficie.',
                    ),
                    onChanged: (_) => _clearResult(),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<_AbsCondition>(
                    value: _absCondition,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '¿El vehículo tenía ABS?',
                      prefixIcon: Icon(Icons.car_crash),
                      helperText:
                          'Si no se sabe, deja “No se sabe”. No cambia la fórmula, cambia la lectura del resultado.',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _AbsCondition.sinAbs,
                        child: Text('No / huella continua'),
                      ),
                      DropdownMenuItem(
                        value: _AbsCondition.conAbs,
                        child: Text('Sí / marca intermitente o tenue'),
                      ),
                      DropdownMenuItem(
                        value: _AbsCondition.noSeSabe,
                        child: Text('No se sabe'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _absCondition = value;
                        _resultado = null;
                        _error = null;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pendienteController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Pendiente',
                            suffixText: '%',
                            prefixIcon: Icon(Icons.trending_up),
                          ),
                          validator: (value) => _requiredNonNegative(
                            value,
                            'Captura 0 si no hay pendiente.',
                          ),
                          onChanged: (_) => _clearResult(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<PendienteFrenado>(
                          value: _pendiente,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Sentido',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: PendienteFrenado.nivel,
                              child: Text('Nivel'),
                            ),
                            DropdownMenuItem(
                              value: PendienteFrenado.ascendente,
                              child: Text('Ascendente'),
                            ),
                            DropdownMenuItem(
                              value: PendienteFrenado.descendente,
                              child: Text('Descendente'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _pendiente = value;
                              _resultado = null;
                              _error = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                icon: const Icon(Icons.calculate),
                label: const Text('Calcular velocidad'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                onPressed: _calcular,
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
              if (_resultado != null) ...[
                const SizedBox(height: 14),
                _ResultCard(
                  resultado: _resultado!,
                  absCondition: _absCondition,
                ),
              ],
              const SizedBox(height: 14),
              const _FormulaCard(),
            ],
          ),
        ),
      ),
    );
  }

  void _clearResult() {
    if (_resultado == null && _error == null) return;
    setState(() {
      _resultado = null;
      _error = null;
    });
  }

  String? _requiredPositive(String? value, String emptyMessage) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return emptyMessage;

    final parsed = _parseDecimal(raw);
    if (parsed == null) return 'Captura un numero valido.';
    if (parsed <= 0) return 'Debe ser mayor a cero.';
    return null;
  }

  String? _requiredNonNegative(String? value, String emptyMessage) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return emptyMessage;

    final parsed = _parseDecimal(raw);
    if (parsed == null) return 'Captura un numero valido.';
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
                child: const Icon(Icons.tire_repair, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calculadora pericial',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Estima la velocidad mínima al inicio del frenado '
                      'cuando la huella termina en reposo.',
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

class _InputCard extends StatelessWidget {
  final List<Widget> children;

  const _InputCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final VelocidadFrenadoResult resultado;
  final _AbsCondition absCondition;

  const _ResultCard({required this.resultado, required this.absCondition});

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
              'Resultado estimado',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${resultado.velocidadKilometrosHora.toStringAsFixed(1)} km/h',
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
                      '${resultado.velocidadMetrosSegundo.toStringAsFixed(2)} m/s',
                ),
                _ResultChip(
                  label:
                      '${resultado.velocidadMillasHora.toStringAsFixed(1)} mph',
                ),
                _ResultChip(
                  label:
                      'Factor ${resultado.factorArrastre.toStringAsFixed(3)}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _AbsResultNotice(condition: absCondition),
          ],
        ),
      ),
    );
  }
}

class _AbsResultNotice extends StatelessWidget {
  final _AbsCondition condition;

  const _AbsResultNotice({required this.condition});

  @override
  Widget build(BuildContext context) {
    return switch (condition) {
      _AbsCondition.sinAbs => const _MessageCard(
        color: Colors.green,
        icon: Icons.check_circle_outline,
        title: 'Huella continua sin ABS',
        body:
            'Resultado estimado con base en la huella visible. Aun así, confirma medición, superficie y pendiente.',
      ),
      _AbsCondition.conAbs => const _MessageCard(
        color: Colors.orange,
        icon: Icons.warning_amber,
        title: 'Atención: vehículo con ABS',
        body:
            'Con ABS la marca puede ser intermitente o incompleta. Si solo se midió la huella visible, el resultado puede quedar por debajo de la velocidad real.',
      ),
      _AbsCondition.noSeSabe => const _MessageCard(
        color: Colors.amber,
        icon: Icons.help_outline,
        title: 'ABS no confirmado',
        body:
            'Resultado orientativo. Si después se confirma ABS o marca intermitente, trátalo como posible mínimo y pide validación pericial.',
      ),
    };
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
          'Fórmula usada: v = sqrt(2 * g * d * f). En km/h equivale a '
          'sqrt(254 * distancia * factor). El operativo solo elige la '
          'superficie; la app asigna el factor sugerido. La pendiente '
          'ascendente suma al factor y la descendente resta. El resultado es '
          'orientativo y debe integrarse con medición de campo, condiciones '
          'reales de superficie y dictamen pericial.',
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

class _SurfaceOption {
  final String id;
  final String label;
  final double? coefficient;
  final bool isCustom;

  const _SurfaceOption({
    required this.id,
    required this.label,
    required this.coefficient,
    this.isCustom = false,
  });
}

const _surfaceOptions = <_SurfaceOption>[
  _SurfaceOption(
    id: 'seleccionar',
    label: 'Selecciona la superficie',
    coefficient: null,
  ),
  _SurfaceOption(
    id: 'asfalto_seco',
    label: 'Asfalto o concreto seco',
    coefficient: 0.75,
  ),
  _SurfaceOption(
    id: 'asfalto_mojado',
    label: 'Asfalto o concreto mojado',
    coefficient: 0.45,
  ),
  _SurfaceOption(id: 'grava', label: 'Grava compactada', coefficient: 0.4),
  _SurfaceOption(id: 'tierra', label: 'Tierra o lodo', coefficient: 0.25),
  _SurfaceOption(
    id: 'personalizado',
    label: 'Valor personalizado',
    coefficient: null,
    isCustom: true,
  ),
];

double? _parseDecimal(String value) {
  final normalized = value.trim().replaceAll(' ', '').replaceAll(',', '.');
  return double.tryParse(normalized);
}

String _formatCompact(double value) {
  final text = value.toStringAsFixed(2);
  return text.endsWith('0') ? value.toStringAsFixed(1) : text;
}
