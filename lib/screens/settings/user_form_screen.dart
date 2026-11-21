import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../services/users_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/permission_guard.dart';
import '../login_screen.dart';
import 'widgets/user_password_field.dart';

class UserCreateScreen extends StatelessWidget {
  const UserCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UserFormScreen(isEditing: false);
  }
}

class UserEditScreen extends StatelessWidget {
  const UserEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UserFormScreen(isEditing: true);
  }
}

class UserFormScreen extends StatefulWidget {
  final bool isEditing;

  const UserFormScreen({super.key, required this.isEditing});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombresCtrl = TextEditingController();
  final _apellidoPaternoCtrl = TextEditingController();
  final _apellidoMaternoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _telefonoOperativoCtrl = TextEditingController();
  final _telefonoOperativoSecundarioCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();

  bool _bootstrapped = false;
  bool _loading = true;
  bool _saving = false;
  bool _busy = false;
  bool _isSuperadmin = false;
  String? _error;

  UsersMeta _meta = const UsersMeta.empty();
  Map<String, dynamic>? _user;

  int? _roleId;
  int? _unidadId;
  int? _turnoId;
  int? _patrullaId;
  int? _delegacionId;
  int? _constanciaModuloId;
  int? _destacamentoId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    _bootstrap();
  }

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _apellidoPaternoCtrl.dispose();
    _apellidoMaternoCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _telefonoOperativoCtrl.dispose();
    _telefonoOperativoSecundarioCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    super.dispose();
  }

  int? _idFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final raw = args['user_id'] ?? args['id'];
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '');
    }
    if (args is int) return args;
    return int.tryParse(args?.toString() ?? '');
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final meta = await UsersService.meta();
      final isSuperadmin = await AuthService.isSuperadmin();
      Map<String, dynamic>? user;

      if (widget.isEditing) {
        final id = _idFromArgs();
        if (id == null || id <= 0) {
          throw Exception('Falta user_id.');
        }
        user = await UsersService.show(id);
      }

      if (!mounted) return;
      _meta = meta;
      _isSuperadmin = isSuperadmin;
      if (user != null) {
        _fillFromUser(user);
      }
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'No se pudo preparar el formulario.\n${UsersService.cleanExceptionMessage(e)}';
      });
    }
  }

  void _fillFromUser(Map<String, dynamic> user) {
    _nombresCtrl.text = _text(user['nombres'], _text(user['name']));
    _apellidoPaternoCtrl.text = _text(user['apellido_paterno']);
    _apellidoMaternoCtrl.text = _text(user['apellido_materno']);
    _emailCtrl.text = _text(user['email']);
    _telefonoCtrl.text = _text(user['telefono']);
    _telefonoOperativoCtrl.text = _text(user['telefono_whatsapp_operativo']);
    _telefonoOperativoSecundarioCtrl.text = _text(
      user['telefono_whatsapp_operativo_secundario'],
    );
    _roleId = _readInt(user['role_id']) ?? _nestedId(user['role']);
    _unidadId = _readInt(user['unidad_id']) ?? _nestedId(user['unidad']);
    _turnoId = _readInt(user['turno_id']) ?? _nestedId(user['turno']);
    _patrullaId = _readInt(user['patrulla_id']) ?? _nestedId(user['patrulla']);
    _delegacionId =
        _readInt(user['delegacion_id']) ?? _nestedId(user['delegacion']);
    _constanciaModuloId =
        _readInt(user['constancia_modulo_id']) ??
        _nestedId(user['constancia_modulo']);
    _destacamentoId =
        _readInt(user['destacamento_id']) ?? _nestedId(user['destacamento']);
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

  String _text(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  int? _nestedId(dynamic raw) {
    if (raw is Map) return _readInt(raw['id']);
    return null;
  }

  UserCatalogItem? _find(List<UserCatalogItem> items, int? id) {
    if (id == null) return null;
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _onRoleChanged(int? id) {
    final role = _find(_meta.roles, id);
    setState(() {
      _roleId = id;
      final forcedUnit = role?.unidadEfectivaId;
      if (forcedUnit != null && forcedUnit > 0) {
        _unidadId = forcedUnit;
      }
      _clearInvalidAssignments();
    });
  }

  void _onUnidadChanged(int? id) {
    setState(() {
      _unidadId = id;
      _clearInvalidAssignments();
    });
  }

  void _clearInvalidAssignments() {
    if (_patrullaId != null &&
        !_filteredPatrullas().any((item) => item.id == _patrullaId)) {
      _patrullaId = null;
    }
    if (_destacamentoId != null &&
        !_filteredDestacamentos().any((item) => item.id == _destacamentoId)) {
      _destacamentoId = null;
    }
    if (_unidadId != AuthService.unidadDelegacionesId) {
      _delegacionId = null;
    }
    if (_unidadId != AuthService.unidadSiniestrosId) {
      _constanciaModuloId = null;
    }
    if (_unidadId != AuthService.unidadProteccionCarreterasId) {
      _destacamentoId = null;
    }
  }

  List<UserCatalogItem> _filteredPatrullas() {
    final unidadId = _unidadId;
    return _meta.patrullas
        .where((item) => unidadId == null || item.unidadId == unidadId)
        .toList();
  }

  List<UserCatalogItem> _filteredDestacamentos() {
    final unidadId = _unidadId;
    return _meta.destacamentos
        .where((item) => unidadId == null || item.unidadId == unidadId)
        .toList();
  }

  String? _required(String? value) {
    return (value ?? '').trim().isEmpty ? 'Campo requerido' : null;
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Campo requerido';
    if (!text.contains('@')) return 'Correo invalido';
    return null;
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    if (!widget.isEditing && text.isEmpty) return 'Campo requerido';
    if (text.isNotEmpty && text.length < 6) {
      return 'Minimo 6 caracteres';
    }
    return null;
  }

  String? _passwordConfirmValidator(String? value) {
    final text = value ?? '';
    final pass = _passwordCtrl.text;
    if (!widget.isEditing && text.isEmpty) return 'Campo requerido';
    if (pass.isNotEmpty && text != pass) {
      return 'La confirmacion no coincide';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = <String, dynamic>{
      'nombres': _nombresCtrl.text.trim(),
      'apellido_paterno': _emptyToNull(_apellidoPaternoCtrl.text),
      'apellido_materno': _emptyToNull(_apellidoMaternoCtrl.text),
      'email': _emailCtrl.text.trim(),
      'role_id': _roleId,
      'unidad_id': _unidadId,
      'turno_id': _turnoId,
      'patrulla_id': _patrullaId,
      'delegacion_id': _delegacionId,
      'constancia_modulo_id': _constanciaModuloId,
      'destacamento_id': _destacamentoId,
    };

    if (_isSuperadmin) {
      payload['telefono'] = _emptyToNull(_telefonoCtrl.text);
      payload['telefono_whatsapp_operativo'] = _emptyToNull(
        _telefonoOperativoCtrl.text,
      );
      payload['telefono_whatsapp_operativo_secundario'] = _emptyToNull(
        _telefonoOperativoSecundarioCtrl.text,
      );
    }

    final password = _passwordCtrl.text;
    if (password.isNotEmpty || !widget.isEditing) {
      payload['password'] = password;
      payload['password_confirmation'] = _passwordConfirmCtrl.text;
    }

    try {
      if (widget.isEditing) {
        final id = _readInt(_user?['id']) ?? _idFromArgs();
        if (id == null || id <= 0) {
          throw Exception('Falta user_id.');
        }
        await UsersService.update(id: id, payload: payload);
      } else {
        await UsersService.store(payload);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Usuario actualizado correctamente.'
                : 'Usuario creado correctamente.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            'No se pudo guardar.\n${UsersService.cleanExceptionMessage(e)}';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String value) {
    final text = value.trim();
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
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _dec(label),
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
    );
  }

  Widget _dropdown({
    required String label,
    required int? value,
    required List<UserCatalogItem> items,
    required ValueChanged<int?> onChanged,
    bool required = false,
    String nullLabel = 'Sin asignar',
    String Function(UserCatalogItem item)? itemLabelBuilder,
  }) {
    final ids = items.map((item) => item.id).toSet();
    final safeValue = value != null && ids.contains(value) ? value : null;

    return DropdownButtonFormField<int>(
      value: safeValue,
      isExpanded: true,
      validator: required
          ? (value) => value == null ? 'Campo requerido' : null
          : null,
      decoration: _dec(label),
      items: [
        DropdownMenuItem<int>(value: null, child: Text(nullLabel)),
        ...items.map(
          (item) => DropdownMenuItem<int>(
            value: item.id,
            child: Text(
              itemLabelBuilder?.call(item) ?? item.nombre,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: _saving ? null : onChanged,
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
    final title = widget.isEditing ? 'Editar usuario' : 'Crear usuario';
    final selectedRole = _find(_meta.roles, _roleId);
    final forcedUnitName = selectedRole?.unidadEfectivaNombre;
    final showDelegacion = _unidadId == AuthService.unidadDelegacionesId;
    final showConstanciaModulo = _unidadId == AuthService.unidadSiniestrosId;
    final showDestacamento =
        _unidadId == AuthService.unidadProteccionCarreterasId;

    return PermissionGuard(
      permission: widget.isEditing ? 'editar usuarios' : 'crear usuarios',
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.blue,
          title: Text(title),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _saving ? null : _bootstrap,
              icon: const Icon(Icons.refresh),
            ),
            const AccountMenuAction(),
          ],
        ),
        endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
        body: SafeArea(
          child: Builder(
            builder: (context) {
              if (_loading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_error != null && _meta.roles.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _bootstrap,
                      child: const Text('Reintentar'),
                    ),
                  ],
                );
              }

              return Form(
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
                    _section(
                      title: 'Datos principales',
                      children: [
                        _textField(
                          _apellidoPaternoCtrl,
                          'Apellido paterno',
                          keyboardType: TextInputType.name,
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          _apellidoMaternoCtrl,
                          'Apellido materno',
                          keyboardType: TextInputType.name,
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          _nombresCtrl,
                          'Nombre(s)',
                          validator: _required,
                          keyboardType: TextInputType.name,
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          _emailCtrl,
                          'Email',
                          validator: _emailValidator,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        if (_isSuperadmin) ...[
                          const SizedBox(height: 12),
                          _textField(
                            _telefonoCtrl,
                            'WhatsApp autorizado para respuestas de la API',
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                          const SizedBox(height: 12),
                          _textField(
                            _telefonoOperativoCtrl,
                            'WhatsApp operativo principal',
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                          const SizedBox(height: 12),
                          _textField(
                            _telefonoOperativoSecundarioCtrl,
                            'WhatsApp operativo secundario',
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    _section(
                      title: 'Acceso',
                      children: [
                        _dropdown(
                          label: 'Rol',
                          value: _roleId,
                          items: _meta.roles,
                          required: true,
                          nullLabel: 'Selecciona rol',
                          itemLabelBuilder: (role) => role.roleScopedLabel,
                          onChanged: _onRoleChanged,
                        ),
                        if ((forcedUnitName ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Este rol fija la unidad: $forcedUnitName',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        UserPasswordField(
                          controller: _passwordCtrl,
                          label: widget.isEditing
                              ? 'Nueva contraseña'
                              : 'Contraseña',
                          validator: _passwordValidator,
                        ),
                        const SizedBox(height: 12),
                        UserPasswordField(
                          controller: _passwordConfirmCtrl,
                          label: widget.isEditing
                              ? 'Confirmar nueva contraseña'
                              : 'Confirmar contraseña',
                          validator: _passwordConfirmValidator,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _section(
                      title: 'Asignacion',
                      children: [
                        _dropdown(
                          label: 'Unidad',
                          value: _unidadId,
                          items: _meta.unidades,
                          nullLabel: 'Sin unidad',
                          onChanged: (value) {
                            final forced = selectedRole?.unidadEfectivaId;
                            if (forced != null && forced > 0) {
                              _onUnidadChanged(forced);
                              return;
                            }
                            _onUnidadChanged(value);
                          },
                        ),
                        const SizedBox(height: 12),
                        _dropdown(
                          label: 'Turno',
                          value: _turnoId,
                          items: _meta.turnos,
                          onChanged: (value) =>
                              setState(() => _turnoId = value),
                        ),
                        const SizedBox(height: 12),
                        _dropdown(
                          label: 'Patrulla',
                          value: _patrullaId,
                          items: _filteredPatrullas(),
                          onChanged: (value) =>
                              setState(() => _patrullaId = value),
                        ),
                        if (showDelegacion) ...[
                          const SizedBox(height: 12),
                          _dropdown(
                            label: 'Delegacion',
                            value: _delegacionId,
                            items: _meta.delegaciones,
                            onChanged: (value) =>
                                setState(() => _delegacionId = value),
                          ),
                        ],
                        if (showConstanciaModulo) ...[
                          const SizedBox(height: 12),
                          _dropdown(
                            label: 'Modulo de examenes de manejo',
                            value: _constanciaModuloId,
                            items: _meta.constanciaModulos,
                            nullLabel: 'Sin modulo asignado',
                            onChanged: (value) =>
                                setState(() => _constanciaModuloId = value),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'El usuario solo podra capturar y consultar constancias de este modulo.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (showDestacamento) ...[
                          const SizedBox(height: 12),
                          _dropdown(
                            label: 'Destacamento',
                            value: _destacamentoId,
                            items: _filteredDestacamentos(),
                            onChanged: (value) =>
                                setState(() => _destacamentoId = value),
                          ),
                        ],
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
              );
            },
          ),
        ),
      ),
    );
  }
}
