import 'package:flutter/material.dart';

import 'conduce_legalidad_action_help_sheet.dart';

class ConduceLegalidadAlimentarHelpSheet extends StatefulWidget {
  const ConduceLegalidadAlimentarHelpSheet({super.key});

  @override
  State<ConduceLegalidadAlimentarHelpSheet> createState() =>
      _ConduceLegalidadAlimentarHelpSheetState();
}

class _ConduceLegalidadAlimentarHelpSheetState
    extends State<ConduceLegalidadAlimentarHelpSheet>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _demoController;

  int _pagina = 0;

  static const int _totalPaginas = 3;

  @override
  void initState() {
    super.initState();
    _demoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _demoController.dispose();
    super.dispose();
  }

  void _siguiente() {
    if (_pagina >= _totalPaginas - 1) {
      Navigator.of(context).pop();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _anterior() {
    if (_pagina == 0) return;

    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.90,
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
                const Icon(
                  Icons.playlist_add_outlined,
                  color: Color(0xFF6D28D9),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cómo alimentar un operativo',
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
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _pagina = index);
                _demoController.forward(from: 0);
              },
              children: [
                _pasoEntrarOperativo(),
                _pasoNuevaCaptura(),
                _pasoGuardarCaptura(),
              ],
            ),
          ),
          _indicadores(),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              children: [
                if (_pagina > 0)
                  TextButton.icon(
                    onPressed: _anterior,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Anterior'),
                  )
                else
                  const SizedBox(width: 100),
                const Spacer(),
                FilledButton(
                  onPressed: _siguiente,
                  child: Text(
                    _pagina == _totalPaginas - 1 ? 'Entendido' : 'Siguiente',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pasoEntrarOperativo() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;
        final resaltarEntrada = progreso >= 0.18 && progreso < 0.56;
        final mensajeVisible = progreso >= 0.56;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('1', 'Entra al operativo'),
              const SizedBox(height: 8),
              const Text(
                'Para alimentar un operativo, toca la tarjeta del operativo o la flecha del lado derecho.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              _contenedorDemo(
                titulo: 'Demostración',
                icono: Icons.chevron_right,
                child: Column(
                  children: [
                    AnimatedScale(
                      duration: const Duration(milliseconds: 350),
                      scale: resaltarEntrada ? 1.01 : 1,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: resaltarEntrada
                              ? const Color(0xFFF5F3FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: resaltarEntrada
                                ? const Color(0xFF7C3AED)
                                : Colors.grey.shade200,
                            width: resaltarEntrada ? 2 : 1,
                          ),
                          boxShadow: resaltarEntrada
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF7C3AED,
                                    ).withValues(alpha: 0.15),
                                    blurRadius: 14,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(
                                0xFF2563EB,
                              ).withValues(alpha: 0.12),
                              child: const Icon(
                                Icons.fact_check_outlined,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Periférico Independencia 5000',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '2026-09-21  |  MORELIA  |  Sentimientos de la Nación  |  0 capturas  |  ACTIVO',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.35,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.share_outlined,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.more_vert, color: Colors.grey),
                            const SizedBox(width: 8),
                            AnimatedScale(
                              duration: const Duration(milliseconds: 350),
                              scale: resaltarEntrada ? 1.18 : 1,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: resaltarEntrada
                                      ? const Color(
                                          0xFF7C3AED,
                                        ).withValues(alpha: 0.10)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: resaltarEntrada
                                        ? const Color(0xFF7C3AED)
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 350),
                      crossFadeState: mensajeVisible
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF7C3AED,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFF7C3AED,
                            ).withValues(alpha: 0.20),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              color: Color(0xFF7C3AED),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Puedes tocar la tarjeta o la flecha para entrar al operativo.',
                                style: TextStyle(
                                  color: Color(0xFF6D28D9),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _aviso(
                icon: Icons.arrow_forward_outlined,
                titulo: 'Entrada al operativo',
                texto:
                    'La alimentación comienza entrando al detalle del operativo activo.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pasoNuevaCaptura() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('2', 'Pulsa Agregar captura'),
              const SizedBox(height: 8),
              const Text(
                'Dentro del operativo, el botón morado está abajo a la derecha. Ese es el botón para crear otra alimentación.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              _contenedorDemo(
                titulo: 'Dentro del operativo',
                icono: Icons.fact_check_outlined,
                child: const ConduceLegalidadAddCapturePreview(),
              ),
              const SizedBox(height: 18),
              _aviso(
                icon: Icons.add_circle_outline,
                titulo: 'Botón inferior derecho',
                texto:
                    'Pulsa “Agregar captura”. No uses los iconos de la tarjeta: esos pertenecen a una alimentación ya guardada.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pasoGuardarCaptura() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;

        final datosListos = progreso >= 0.18;
        final guardando = progreso >= 0.46 && progreso < 0.68;
        final completado = progreso >= 0.68;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('3', 'Guarda la captura'),
              const SizedBox(height: 8),
              const Text(
                'Completa la información solicitada en la captura y guárdala para que quede registrada en el operativo.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              _contenedorDemo(
                titulo: 'Registro de captura',
                icono: Icons.save_outlined,
                child: Column(
                  children: [
                    _campoDemo(
                      titulo: 'Vehículo',
                      valor: datosListos ? 'Motocicleta' : '',
                      mostrar: datosListos,
                      icono: Icons.directions_car_outlined,
                    ),
                    const SizedBox(height: 10),
                    _campoDemo(
                      titulo: 'Fundamento',
                      valor: datosListos ? 'Documentación / revisión' : '',
                      mostrar: datosListos,
                      icono: Icons.gavel_outlined,
                    ),
                    const SizedBox(height: 10),
                    _campoDemo(
                      titulo: 'Observaciones',
                      valor: datosListos ? 'Captura completada' : '',
                      mostrar: datosListos,
                      icono: Icons.notes_outlined,
                    ),
                    const SizedBox(height: 16),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: completado
                            ? Colors.green.withValues(alpha: 0.12)
                            : const Color(
                                0xFF7C3AED,
                              ).withValues(alpha: guardando ? 0.12 : 0.10),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: completado
                              ? Colors.green
                              : const Color(0xFF7C3AED),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: guardando
                                ? const SizedBox(
                                    key: ValueKey('cargando'),
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    completado
                                        ? Icons.check_circle_outline
                                        : Icons.save_outlined,
                                    key: ValueKey(completado),
                                    color: completado
                                        ? Colors.green
                                        : const Color(0xFF6D28D9),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            guardando
                                ? 'Guardando captura...'
                                : completado
                                ? 'Captura registrada'
                                : 'Guardar captura',
                            style: TextStyle(
                              color: completado
                                  ? Colors.green.shade800
                                  : const Color(0xFF6D28D9),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _avisoAdvertencia(
                icon: Icons.fact_check_outlined,
                titulo: 'Verifica antes de guardar',
                texto:
                    'Asegúrate de que la información capturada corresponda a la revisión realizada.',
              ),
              const SizedBox(height: 12),
              _aviso(
                icon: Icons.check_circle_outline,
                titulo: 'Captura lista',
                texto:
                    'Después de guardar, la captura quedará registrada dentro del operativo.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _contenedorDemo({
    required String titulo,
    required IconData icono,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: Colors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _campoDemo({
    required String titulo,
    required String valor,
    required bool mostrar,
    required IconData icono,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: mostrar
            ? const Color(0xFF7C3AED).withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: mostrar ? const Color(0xFF7C3AED) : Colors.grey.shade400,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icono,
            color: mostrar ? const Color(0xFF6D28D9) : Colors.grey.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 12,
                    color: mostrar
                        ? const Color(0xFF6D28D9)
                        : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Text(
                    mostrar ? valor : '',
                    key: ValueKey('$titulo-$mostrar'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (mostrar)
            const Icon(Icons.check_circle, size: 20, color: Colors.green),
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

  Widget _avisoAdvertencia({
    required IconData icon,
    required String titulo,
    required String texto,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange.shade800),
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

  Widget _indicadores() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalPaginas, (index) {
        final activo = index == _pagina;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: activo ? 26 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: activo ? Colors.deepPurple : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}
