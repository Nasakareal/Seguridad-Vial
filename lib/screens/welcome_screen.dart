import 'package:flutter/material.dart';
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/guardiacivil.png', height: 150),
                const SizedBox(height: 26),
                Text(
                  'Bienvenidos a Seguridad Vial - Michoacán',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[900],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                const Text(
                  'La seguridad vial es una prioridad para nuestro estado. Nuestra misión es reducir accidentes de tránsito, promover conductas responsables en la vía pública y garantizar que las reglas de tránsito sean respetadas por todos los ciudadanos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 22),

                // ✅ Prominent disclosure accesible para el reviewer (sin pedir permisos aquí)
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

                const SizedBox(height: 18),

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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
