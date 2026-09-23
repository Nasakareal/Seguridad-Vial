import 'package:flutter/material.dart';

class ConduceLegalidadEditHelpSheet extends StatefulWidget {
  const ConduceLegalidadEditHelpSheet({super.key});

  @override
  State<ConduceLegalidadEditHelpSheet> createState() =>
      _ConduceLegalidadEditHelpSheetState();
}

class _ConduceLegalidadEditHelpSheetState
    extends State<ConduceLegalidadEditHelpSheet>
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
                const Icon(Icons.edit_outlined, color: Colors.deepOrange),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cómo editar un operativo',
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
              children: [_pasoAbrirMenu(), _pasoEditar(), _pasoGuardar()],
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

  Widget _pasoAbrirMenu() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;
        final resaltarMenu = progreso >= 0.20 && progreso < 0.52;
        final menuAbierto = progreso >= 0.52;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('1', 'Abre el menú del operativo'),
              const SizedBox(height: 8),
              const Text(
                'En la tarjeta del operativo, pulsa los tres puntos que aparecen del lado derecho.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              _contenedorDemo(
                titulo: 'Demostración',
                icono: Icons.more_vert,
                child: Column(
                  children: [
                    _tarjetaOperativoDemo(
                      resaltarMenu: resaltarMenu,
                      mostrarFlecha: true,
                    ),
                    const SizedBox(height: 14),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 350),
                      crossFadeState: menuAbierto
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 220,
                          decoration: BoxDecoration(
                            color: const Color(0xffeef4ff),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _menuOpcionDemo(
                                icono: Icons.edit_outlined,
                                titulo: 'Editar',
                                color: Colors.black87,
                                seleccionado: true,
                              ),
                              Divider(height: 1, color: Colors.grey.shade300),
                              _menuOpcionDemo(
                                icono: Icons.delete_outline,
                                titulo: 'Eliminar',
                                color: Colors.red,
                                seleccionado: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _aviso(
                icon: Icons.more_vert,
                titulo: 'Editar se encuentra en el menú',
                texto:
                    'No se edita entrando a la captura. Primero abre el menú de opciones del operativo.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pasoEditar() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;

        final lugarListo = progreso >= 0.16;
        final numeroListo = progreso >= 0.32;
        final coloniaLista = progreso >= 0.48;
        final coordenadasListas = progreso >= 0.66;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('2', 'Modifica la información necesaria'),
              const SizedBox(height: 8),
              const Text(
                'Después de pulsar “Editar”, se abre el formulario del operativo para corregir o actualizar sus datos.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              _contenedorDemo(
                titulo: 'Formulario de edición',
                icono: Icons.edit_note_outlined,
                child: Column(
                  children: [
                    _campoDemo(
                      titulo: 'Lugar *',
                      valor: 'Periférico Independencia',
                      mostrar: lugarListo,
                      icono: Icons.place,
                    ),
                    const SizedBox(height: 10),
                    _campoDemo(
                      titulo: 'Número',
                      valor: '5000',
                      mostrar: numeroListo,
                      icono: Icons.tag,
                      opcional: true,
                    ),
                    const SizedBox(height: 10),
                    _campoDemo(
                      titulo: 'Colonia *',
                      valor: 'Sentimientos de la Nación',
                      mostrar: coloniaLista,
                      icono: Icons.location_city_outlined,
                    ),
                    const SizedBox(height: 10),
                    _campoDemo(
                      titulo: 'Coordenadas *',
                      valor: '19.701234, -101.184321',
                      mostrar: coordenadasListas,
                      icono: Icons.pin_drop_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _aviso(
                icon: Icons.edit_outlined,
                titulo: 'Corrige sólo lo necesario',
                texto:
                    'Puedes actualizar el lugar, número, colonia u otros datos del operativo cuando sea necesario.',
              ),
              const SizedBox(height: 12),
              _avisoAdvertencia(
                icon: Icons.fact_check_outlined,
                titulo: 'Verifica antes de guardar',
                texto:
                    'Asegúrate de que la información editada corresponda al punto real del operativo.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pasoGuardar() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;

        final botonActivo = progreso >= 0.18 && progreso < 0.42;
        final guardando = progreso >= 0.42 && progreso < 0.66;
        final completado = progreso >= 0.66;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('3', 'Guarda los cambios'),
              const SizedBox(height: 8),
              const Text(
                'Cuando la información sea correcta, guarda la edición del operativo.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              _contenedorDemo(
                titulo: 'Guardar edición',
                icono: Icons.save_outlined,
                child: Column(
                  children: [
                    AnimatedScale(
                      duration: const Duration(milliseconds: 350),
                      scale: botonActivo ? 1.04 : 1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: completado
                              ? Colors.green.withValues(alpha: 0.12)
                              : botonActivo || guardando
                              ? Colors.deepOrange.withValues(alpha: 0.10)
                              : const Color(0xfffff8f6),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: completado
                                ? Colors.green
                                : botonActivo || guardando
                                ? Colors.deepOrange
                                : Colors.grey.shade400,
                            width: botonActivo ? 2 : 1,
                          ),
                          boxShadow: botonActivo
                              ? [
                                  BoxShadow(
                                    color: Colors.deepOrange.withValues(
                                      alpha: 0.20,
                                    ),
                                    blurRadius: 14,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: guardando
                                  ? const SizedBox(
                                      key: ValueKey('guardando'),
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
                                          : Colors.deepOrange,
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              guardando
                                  ? 'Guardando cambios...'
                                  : completado
                                  ? 'Operativo actualizado'
                                  : 'Guardar cambios',
                              style: TextStyle(
                                color: completado
                                    ? Colors.green.shade800
                                    : Colors.deepOrange,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 350),
                      crossFadeState: completado
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Los cambios se guardaron correctamente.',
                                style: TextStyle(
                                  color: Colors.green,
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
                icon: Icons.save_outlined,
                titulo: 'Confirma la edición',
                texto:
                    'Después de guardar, el operativo conservará los datos actualizados en el listado.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tarjetaOperativoDemo({
    required bool resaltarMenu,
    required bool mostrarFlecha,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
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
            backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.share_outlined, color: Colors.grey),
              const SizedBox(width: 8),
              AnimatedScale(
                duration: const Duration(milliseconds: 350),
                scale: resaltarMenu ? 1.14 : 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: resaltarMenu
                        ? Colors.deepOrange.withValues(alpha: 0.10)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: resaltarMenu
                          ? Colors.deepOrange
                          : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: resaltarMenu
                        ? [
                            BoxShadow(
                              color: Colors.deepOrange.withValues(alpha: 0.18),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: const Icon(Icons.more_vert, color: Colors.deepOrange),
                ),
              ),
              if (mostrarFlecha) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _menuOpcionDemo({
    required IconData icono,
    required String titulo,
    required Color color,
    required bool seleccionado,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: seleccionado ? const Color(0xFFF9FAFB) : Colors.transparent,
      child: Row(
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 14),
          Text(
            titulo,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
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
    bool opcional = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: mostrar
            ? Colors.deepOrange.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: mostrar ? Colors.deepOrange : Colors.grey.shade400,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icono,
            color: mostrar ? Colors.deepOrange : Colors.grey.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opcional ? '$titulo · opcional' : titulo,
                  style: TextStyle(
                    fontSize: 12,
                    color: mostrar ? Colors.deepOrange : Colors.grey.shade700,
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
