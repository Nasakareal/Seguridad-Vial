import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../login_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  bool _busy = false;
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    if (_passwordCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La confirmación no coincide.')),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      await AuthService.changePassword(
        currentPassword: _currentCtrl.text.trim(),
        newPassword: _passwordCtrl.text.trim(),
        confirmPassword: _confirmCtrl.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Cambiar contraseña'),
        actions: const [AccountMenuAction()],
      ),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Actualiza tus credenciales',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Usa una contraseña fácil de recordar para ti, pero difícil de adivinar para otros.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _PasswordField(
                          controller: _currentCtrl,
                          label: 'Contraseña actual',
                          hintText: 'Escribe tu contraseña actual',
                          obscureText: _hideCurrent,
                          onToggleVisibility: () {
                            setState(() => _hideCurrent = !_hideCurrent);
                          },
                        ),
                        const SizedBox(height: 12),
                        _PasswordField(
                          controller: _passwordCtrl,
                          label: 'Nueva contraseña',
                          hintText: 'Minimo 6 caracteres',
                          obscureText: _hideNew,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return 'Escribe la nueva contraseña.';
                            }
                            if (text.length < 6) {
                              return 'Debe tener al menos 6 caracteres.';
                            }
                            return null;
                          },
                          onToggleVisibility: () {
                            setState(() => _hideNew = !_hideNew);
                          },
                        ),
                        const SizedBox(height: 12),
                        _PasswordField(
                          controller: _confirmCtrl,
                          label: 'Confirmar contraseña',
                          hintText: 'Repite la nueva contraseña',
                          obscureText: _hideConfirm,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return 'Confirma la nueva contraseña.';
                            }
                            if (text != _passwordCtrl.text.trim()) {
                              return 'La confirmación no coincide.';
                            }
                            return null;
                          },
                          onToggleVisibility: () {
                            setState(() => _hideConfirm = !_hideConfirm);
                          },
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _busy ? null : _submit,
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.lock_reset),
                            label: Text(
                              _busy
                                  ? 'Actualizando...'
                                  : 'Actualizar contraseña',
                            ),
                          ),
                        ),
                      ],
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

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool obscureText;
  final String? Function(String?)? validator;
  final VoidCallback onToggleVisibility;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.obscureText,
    required this.onToggleVisibility,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator:
          validator ??
          (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) {
              return 'Este campo es obligatorio.';
            }
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        suffixIcon: IconButton(
          tooltip: obscureText ? 'Mostrar' : 'Ocultar',
          onPressed: onToggleVisibility,
          icon: Icon(
            obscureText ? Icons.visibility_outlined : Icons.visibility_off,
          ),
        ),
      ),
    );
  }
}
