import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/home_resolver_service.dart';
import '../services/offline_sync_service.dart';
import 'home_agente_upec_screen.dart';
import 'home_screen.dart';
import 'home_perito_screen.dart';
import 'location_consent_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _passwordFocus = FocusNode();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Escribe tu email y contraseña');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ok = await AuthService.login(email: email, password: password);

      if (!mounted) return;

      if (ok) {
        await OfflineSyncService.initialize();
        await OfflineSyncService.flushPending();

        final askLocation = await AuthService.shouldAskLocation();
        final agenteUpecHomeAvailable =
            await HomeResolverService.isAgenteUpecHomeAvailable();
        final peritoHomeAvailable =
            await HomeResolverService.isPeritoHomeAvailable();
        final nextHome = agenteUpecHomeAvailable
            ? const HomeAgenteUpecScreen()
            : (peritoHomeAvailable
                  ? const HomePeritoScreen()
                  : const HomeScreen());

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) =>
                askLocation ? LocationConsentScreen(next: nextHome) : nextHome,
          ),
          (_) => false,
        );
      } else {
        setState(() => _error = 'Credenciales incorrectas');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Error al conectar con el servidor');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f3f6),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isVeryShort = constraints.maxHeight < 560;
            final horizontalPadding = constraints.maxWidth < 360 ? 16.0 : 24.0;
            final topPadding = isVeryShort ? 12.0 : 24.0;
            final bottomPadding =
                (isVeryShort ? 16.0 : 24.0) +
                MediaQuery.viewInsetsOf(context).bottom;
            final minHeight = constraints.maxHeight > topPadding + bottomPadding
                ? constraints.maxHeight - topPadding - bottomPadding
                : 0.0;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                topPadding,
                horizontalPadding,
                bottomPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/guardiacivil.png',
                          height: isVeryShort ? 96 : 160,
                        ),
                        SizedBox(height: isVeryShort ? 14 : 20),
                        Container(
                          padding: EdgeInsets.all(isVeryShort ? 18 : 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Autenticarse para iniciar sesión',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.email),
                                  labelText: 'Email',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => FocusScope.of(
                                  context,
                                ).requestFocus(_passwordFocus),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.lock),
                                  labelText: 'Contraseña',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _login(),
                              ),
                              const SizedBox(height: 16),
                              _loading
                                  ? const CircularProgressIndicator()
                                  : SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xff007bff,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                        icon: const Icon(Icons.login),
                                        label: const Text('Acceder'),
                                        onPressed: _login,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
