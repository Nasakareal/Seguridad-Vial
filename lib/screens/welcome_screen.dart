import 'package:flutter/material.dart';
import '../app/routes.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _showLocationDisclosure(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text(
            'Ubicación en segundo plano',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const SingleChildScrollView(
            child: Text(
              'Esta app puede recopilar y enviar la ubicación incluso cuando está cerrada o no está en uso.\n\n'
              'Finalidad:\n'
              '• Monitoreo operativo de unidades y respuesta a incidentes en tiempo real.\n\n'
              'Tratamiento:\n'
              '• La ubicación se utiliza únicamente durante el servicio.\n'
              '• No se comparte con terceros.\n\n'
              'Nota: Los permisos se solicitarán únicamente cuando un usuario autorizado active el servicio de ubicación.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[50],
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isVeryShort = constraints.maxHeight < 560;
            final isShort = constraints.maxHeight < 680;
            final horizontalPadding = constraints.maxWidth < 360 ? 16.0 : 24.0;
            final verticalPadding = isVeryShort ? 12.0 : 24.0;
            final logoHeight = isVeryShort ? 86.0 : (isShort ? 112.0 : 150.0);
            final titleSize = isVeryShort ? 19.0 : 22.0;
            final bodySize = isVeryShort ? 14.0 : 16.0;
            final minHeight = constraints.maxHeight > verticalPadding * 2
                ? constraints.maxHeight - verticalPadding * 2
                : 0.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/guardiacivil.png',
                          height: logoHeight,
                        ),
                        SizedBox(height: isVeryShort ? 14 : 26),
                        Text(
                          'Bienvenidos a Seguridad Vial - Michoacán',
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo[900],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isVeryShort ? 10 : 14),
                        Text(
                          'La seguridad vial es una prioridad para nuestro estado. Nuestra misión es reducir accidentes de tránsito, promover conductas responsables en la vía pública y garantizar que las reglas de tránsito sean respetadas por todos los ciudadanos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: bodySize),
                        ),
                        SizedBox(height: isVeryShort ? 14 : 22),
                        InkWell(
                          onTap: () => _showLocationDisclosure(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Uso de ubicación (importante)',
                              style: TextStyle(
                                color: Colors.indigo[900],
                                fontWeight: FontWeight.w900,
                                decoration: TextDecoration.underline,
                              ),
                              textAlign: TextAlign.center,
                            ),
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
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 10, 24, 16),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text('Iniciar Sesión'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.culturaVialJoin),
                    icon: const Icon(Icons.sports_esports),
                    label: const Text(
                      'Entrar a juego vial',
                      textAlign: TextAlign.center,
                    ),
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
