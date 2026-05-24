import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/settings_personal_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/permission_guard.dart';
import '../login_screen.dart';

class PersonalIncidenciaCreateScreen extends StatelessWidget {
  const PersonalIncidenciaCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PersonalIncidenciaFormScreen();
  }
}

class PersonalIncidenciaFormScreen extends StatefulWidget {
  const PersonalIncidenciaFormScreen({super.key});

  @override
  State<PersonalIncidenciaFormScreen> createState() =>
      _PersonalIncidenciaFormScreenState();
}

class _PersonalIncidenciaFormScreenState
    extends State<PersonalIncidenciaFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fechaInicioCtrl = TextEditingController();
  final _fechaFinCtrl = TextEditingController();
  final _horaInicioCtrl = TextEditingController();
  final _horaFinCtrl = TextEditingController();
  final _folioCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  bool _saving = false;
  bool _busy = false;
  String? _error;
  String _tipo = SettingsPersonalService.incidenciaTipos.first;

  @override
  void initState() {
    super.initState();
    _fechaInicioCtrl.text = _ymd(DateTime.now());
  }

  @override
  void dispose() {
    _fechaInicioCtrl.dispose();
    _fechaFinCtrl.dispose();
    _horaInicioCtrl.dispose();
    _horaFinCtrl.dispose();
    _folioCtrl.dispose();
    _motivoCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  int? _personalIdFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final raw = args['personal_id'] ?? args['id'];
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '');
    }
    if (args is int) return args;
    return int.tryParse(args?.toString() ?? '');
  }

  String _personalNameFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final text = args['personal_name']?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return 'Personal';
  }

  Future<void> _logout(BuildContext context) async {
    if (_busy) return;
    _busy = true;

    try {
      try {
        await TrackingService.stop();
      } catch (_) {}
      await AuthService.logout();
    } finally {
      _busy = false;
    }

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String? _required(String? value) {
    return (value ?? '').trim().isEmpty ? 'Campo requerido' : null;
  }

  String? _timeValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final match = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(text);
    return match ? null : 'Usa formato HH:mm';
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final parsed = DateTime.tryParse(controller.text.trim());
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      controller.text = _ymd(picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final personalId = _personalIdFromArgs();
    if (personalId == null || personalId <= 0) {
      setState(() => _error = 'Falta personal_id.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = <String, dynamic>{
      'tipo': _tipo,
      'fecha_inicio': _fechaInicioCtrl.text.trim(),
      'fecha_fin': _emptyToNull(_fechaFinCtrl),
      'hora_inicio': _emptyToNull(_horaInicioCtrl),
      'hora_fin': _emptyToNull(_horaFinCtrl),
      'folio': _emptyToNull(_folioCtrl),
      'motivo': _emptyToNull(_motivoCtrl),
      'observaciones': _emptyToNull(_observacionesCtrl),
    };

    try {
      await SettingsPersonalService.storeIncidencia(
        personalId: personalId,
        payload: payload,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incidencia registrada correctamente.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            'No se pudo guardar.\n${SettingsPersonalService.cleanExceptionMessage(e)}';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    FormFieldValidator<String>? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _dec(label),
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }

  Widget _dateField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: _dec(label).copyWith(
        suffixIcon: IconButton(
          tooltip: 'Seleccionar fecha',
          icon: const Icon(Icons.calendar_month),
          onPressed: _saving ? null : () => _pickDate(controller),
        ),
      ),
      validator: label == 'Fecha inicio' ? _required : null,
      onTap: _saving ? null : () => _pickDate(controller),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final personalName = _personalNameFromArgs();

    return PermissionGuard(
      permission: 'editar personal',
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.blue,
          title: const Text('Agregar incidencia'),
          actions: [const AccountMenuAction()],
        ),
        endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: .22),
                      ),
                    ),
                    child: Text(_error!),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    personalName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _section(
                  title: 'Incidencia',
                  children: [
                    DropdownButtonFormField<String>(
                      value: _tipo,
                      isExpanded: true,
                      decoration: _dec('Tipo'),
                      items: SettingsPersonalService.incidenciaTipos
                          .map(
                            (tipo) => DropdownMenuItem<String>(
                              value: tipo,
                              child: Text(tipo),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(
                              () => _tipo =
                                  value ??
                                  SettingsPersonalService.incidenciaTipos.first,
                            ),
                    ),
                    const SizedBox(height: 12),
                    _dateField(_fechaInicioCtrl, 'Fecha inicio'),
                    const SizedBox(height: 12),
                    _dateField(_fechaFinCtrl, 'Fecha fin'),
                    const SizedBox(height: 12),
                    _textField(
                      _horaInicioCtrl,
                      'Hora inicio',
                      validator: _timeValidator,
                      keyboardType: TextInputType.datetime,
                    ),
                    const SizedBox(height: 12),
                    _textField(
                      _horaFinCtrl,
                      'Hora fin',
                      validator: _timeValidator,
                      keyboardType: TextInputType.datetime,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _section(
                  title: 'Detalle',
                  children: [
                    _textField(_folioCtrl, 'Folio'),
                    const SizedBox(height: 12),
                    _textField(_motivoCtrl, 'Motivo', maxLines: 2),
                    const SizedBox(height: 12),
                    _textField(
                      _observacionesCtrl,
                      'Observaciones',
                      maxLines: 3,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Guardando' : 'Guardar'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _ymd(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
