import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';

class RegistroCiudadanoScreen extends StatefulWidget {
  const RegistroCiudadanoScreen({super.key});

  @override
  State<RegistroCiudadanoScreen> createState() =>
      _RegistroCiudadanoScreenState();
}

class _RegistroCiudadanoScreenState extends State<RegistroCiudadanoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _accepted = false;
  bool _loading = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_accepted) {
      setState(() => _error = 'Acepta el aviso de privacidad para continuar.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await AuthService.registerCitizen(
      name: _name.text,
      email: _email.text,
      password: _password.text,
      passwordConfirmation: _confirmation.text,
    );
    if (!mounted) return;
    if (!result.success) {
      if (result.accountAlreadyExists) {
        final login = await _loginWithRetry();
        if (!mounted) return;
        if (login.success) {
          _openCitizenHome();
          return;
        }
        setState(() {
          _loading = false;
          _error = login.message == 'Credenciales incorrectas.'
              ? 'Ya existe una cuenta con este correo, pero la contraseña no coincide. '
                    'Revisa mayúsculas y minúsculas e intenta iniciar sesión.'
              : 'Ya existe una cuenta con este correo. ${login.message ?? 'No pudimos abrir la sesión.'}';
        });
        return;
      }
      setState(() {
        _loading = false;
        _error = result.message;
      });
      return;
    }

    final login = await _loginWithRetry();
    if (!mounted) return;
    setState(() => _loading = false);
    if (!login.success) {
      setState(() {
        _error =
            'La cuenta sí fue creada, pero no pudimos confirmar la sesión: '
            '${login.message ?? 'intenta nuevamente.'} '
            'Tus datos permanecen en pantalla; vuelve a tocar “Crear mi cuenta”.';
      });
      return;
    }
    _openCitizenHome();
  }

  Future<AuthLoginResult> _loginWithRetry() async {
    AuthLoginResult result = const AuthLoginResult.failure(
      'No fue posible confirmar la sesión.',
    );
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
      }
      result = await AuthService.loginDetailed(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (result.success || result.singleDeviceConflict) return result;
    }
    return result;
  }

  void _openCitizenHome() {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.michoacanAlVolante,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(title: const Text('Crear cuenta personal')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: const BorderSide(color: Color(0xFFDCE5F2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.directions_car_filled_rounded,
                          size: 54,
                          color: Color(0xFF155EEF),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Michoacán al Volante',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF102A43),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Guarda tu avance, practica para el examen y mejora con cada misión.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF52667A)),
                        ),
                        const SizedBox(height: 24),
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE9E9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Color(0xFF9B1C1C)),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            labelText: 'Nombre completo',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => (value ?? '').trim().length < 3
                              ? 'Escribe tu nombre completo'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final email = (value ?? '').trim();
                            return RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                ).hasMatch(email)
                                ? null
                                : 'Escribe un correo válido';
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _hidePassword,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            helperText: 'Mínimo 8 caracteres',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: _hidePassword ? 'Mostrar' : 'Ocultar',
                              onPressed: () => setState(
                                () => _hidePassword = !_hidePassword,
                              ),
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => (value ?? '').length < 8
                              ? 'Usa al menos 8 caracteres'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmation,
                          obscureText: _hidePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: const InputDecoration(
                            labelText: 'Confirmar contraseña',
                            prefixIcon: Icon(Icons.lock_reset_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value != _password.text
                              ? 'Las contraseñas no coinciden'
                              : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _accepted,
                          onChanged: _loading
                              ? null
                              : (value) =>
                                    setState(() => _accepted = value ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'Acepto que mis datos se usen para crear mi cuenta y guardar mi progreso educativo.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.person_add_alt_1),
                          label: Text(
                            _loading ? 'Creando cuenta...' : 'Crear mi cuenta',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.pushReplacementNamed(
                                  context,
                                  AppRoutes.login,
                                ),
                          child: const Text('Ya tengo una cuenta'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
