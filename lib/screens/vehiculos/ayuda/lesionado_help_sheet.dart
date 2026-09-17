import 'package:flutter/material.dart';

class LesionadoHelpSheet extends StatefulWidget {
  const LesionadoHelpSheet({super.key});

  @override
  State<LesionadoHelpSheet> createState() => _LesionadoHelpSheetState();
}

class _LesionadoHelpSheetState extends State<LesionadoHelpSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xfff8f9fd),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.personal_injury_outlined, color: Colors.blue),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cómo registrar una persona lesionada',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tituloPaso('1', 'Abre la sección de lesionados'),
                  const SizedBox(height: 8),
                  const Text(
                    'Desde el listado de vehículos del hecho, utiliza el botón “Agregar / ver lesionados” ubicado en la parte inferior de la pantalla.',
                    style: TextStyle(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 470,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xfff5f8fc),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            Container(
                              height: 54,
                              decoration: const BoxDecoration(
                                color: Color(0xff2196f3),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(22),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.arrow_back),
                                  SizedBox(width: 18),
                                  Expanded(
                                    child: Text(
                                      'Vehículos (Hecho #63536)',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ),
                                  Icon(Icons.help_outline),
                                  SizedBox(width: 16),
                                  Icon(Icons.refresh),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xfffbf5fc),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.directions_car),
                                              SizedBox(width: 10),
                                              Text(
                                                'AUDI A4',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Placas: PGD023B  •  Modelo: 2008',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Conductor: —',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          const Divider(),
                                          const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceAround,
                                            children: [
                                              Icon(Icons.edit),
                                              Icon(Icons.person_add_alt_1),
                                              Icon(Icons.photo_camera),
                                              Icon(Icons.inventory_2),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        width: 62,
                                        height: 62,
                                        decoration: BoxDecoration(
                                          color: const Color(0xffeadcff),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          color: Colors.deepPurple,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                              child: ScaleTransition(
                                scale: _pulseAnimation,
                                child: Container(
                                  height: 56,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xfffaf4fb),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: Colors.deepPurple,
                                      width: 1.6,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.deepPurple.withValues(
                                          alpha: 0.25,
                                        ),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.personal_injury,
                                        color: Colors.deepPurple,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Agregar / ver lesionados',
                                        style: TextStyle(
                                          color: Colors.deepPurple,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 78,
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (_, __) {
                              return Opacity(
                                opacity: 0.65 + (_pulseController.value * 0.35),
                                child: const Text(
                                  'Toca este botón',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _aviso(
                    icon: Icons.personal_injury_outlined,
                    titulo: 'Agregar / ver lesionados',
                    texto:
                        'Este botón abre la sección de personas lesionadas relacionadas con el hecho que estás consultando.',
                  ),
                  const SizedBox(height: 12),
                  _aviso(
                    icon: Icons.link_outlined,
                    titulo: 'Lesionados del mismo hecho',
                    texto:
                        'Las personas que registres desde esta sección quedarán relacionadas con el hecho actual.',
                  ),
                  const SizedBox(height: 12),
                  _aviso(
                    icon: Icons.groups_outlined,
                    titulo: 'Más de una persona lesionada',
                    texto:
                        'Si existe más de una persona lesionada, cada una debe registrarse por separado dentro de la sección de lesionados.',
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tituloPaso(String numero, String titulo) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: Colors.blue,
          child: Text(
            numero,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _aviso({
    required IconData icon,
    required String titulo,
    required String texto,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(texto, style: const TextStyle(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
