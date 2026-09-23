import 'package:flutter/material.dart';

class ConduceLegalidadOperativoFormHelpSheet extends StatefulWidget {
  final String operativoNombre;

  const ConduceLegalidadOperativoFormHelpSheet({
    super.key,
    required this.operativoNombre,
  });

  @override
  State<ConduceLegalidadOperativoFormHelpSheet> createState() =>
      _ConduceLegalidadOperativoFormHelpSheetState();
}

class _ConduceLegalidadOperativoFormHelpSheetState
    extends State<ConduceLegalidadOperativoFormHelpSheet>
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
                const Icon(Icons.add_road_outlined, color: Colors.blue),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cómo activar un operativo',
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
                _pasoDatosIniciales(),
                _pasoUbicacion(),
                _pasoActivar(),
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

  Widget _pasoDatosIniciales() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;

        final operativoListo = progreso >= 0.12;
        final unidadLista = progreso >= 0.30;
        final fechaLista = progreso >= 0.50;
        final horaLista = progreso >= 0.68;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('1', 'Datos asignados automáticamente'),

              const SizedBox(height: 8),

              const Text(
                'Antes de capturar la ubicación, el sistema ya determina los datos principales del operativo. Estos campos no deben modificarse.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock_outline, color: Colors.blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Datos establecidos por el sistema',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 450),
                      opacity: operativoListo ? 1 : 0.30,
                      child: _campoFijoDemo(
                        titulo: 'Operativo',
                        valor: widget.operativoNombre,
                        icono: Icons.fact_check_outlined,
                      ),
                    ),

                    const SizedBox(height: 10),

                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 450),
                      opacity: unidadLista ? 1 : 0.30,
                      child: _campoFijoDemo(
                        titulo: 'Unidad responsable',
                        valor: 'VIALIDADES URBANAS',
                        icono: Icons.apartment,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 450),
                            opacity: fechaLista ? 1 : 0.30,
                            child: _campoFijoDemo(
                              titulo: 'Fecha',
                              valor: 'Asignada por servidor',
                              icono: Icons.calendar_month_outlined,
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 450),
                            opacity: horaLista ? 1 : 0.30,
                            child: _campoFijoDemo(
                              titulo: 'Hora',
                              valor: 'Asignada por servidor',
                              icono: Icons.schedule,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Container(
                        key: ValueKey(
                          '$operativoListo-$unidadLista-$fechaLista-$horaLista',
                        ),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          !operativoListo
                              ? 'El tipo de operativo se obtiene automáticamente.'
                              : !unidadLista
                              ? 'La unidad responsable ya está asignada.'
                              : !fechaLista
                              ? 'La fecha será establecida por el servidor.'
                              : !horaLista
                              ? 'La hora será establecida por el servidor.'
                              : 'Estos datos no requieren captura.',
                          style: const TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              _aviso(
                icon: Icons.auto_awesome_outlined,
                titulo: 'El tipo de operativo es automático',
                texto:
                    'El sistema sabe si ingresaste desde Conduce con Legalidad o Alcoholimetría. No necesitas seleccionar el tipo de operativo.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.apartment_outlined,
                titulo: 'Unidad responsable',
                texto:
                    'El personal que utilizará este módulo tendrá asignada Vialidades Urbanas. Este dato aparecerá bloqueado y no requiere selección.',
              ),

              const SizedBox(height: 12),

              _avisoAdvertencia(
                icon: Icons.schedule_outlined,
                titulo: 'Fecha y hora controladas por el servidor',
                texto:
                    'La fecha y la hora no deben modificarse manualmente. El sistema las determina para mantener consistencia en los periodos y cortes de información.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pasoUbicacion() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;

        final municipioListo = progreso >= 0.08;
        final lugarListo = progreso >= 0.22;
        final numeroListo = progreso >= 0.34;
        final coloniaLista = progreso >= 0.48;

        final pulsarUbicacion = progreso >= 0.58 && progreso < 0.70;
        final buscando = progreso >= 0.70 && progreso < 0.84;
        final coordenadasListas = progreso >= 0.84;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('2', 'Captura la ubicación'),
              const SizedBox(height: 8),
              const Text(
                'Captura los datos del lugar donde se instalará el punto y obtén las coordenadas estando físicamente en el sitio.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: Colors.blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ubicación del operativo',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _campoDemo(
                      titulo: 'Municipio *',
                      valor: 'MORELIA',
                      mostrar: municipioListo,
                      icono: Icons.location_city,
                    ),
                    const SizedBox(height: 10),
                    _campoDemo(
                      titulo: 'Lugar *',
                      valor: 'Av. Camelinas',
                      mostrar: lugarListo,
                      icono: Icons.place,
                    ),
                    const SizedBox(height: 10),
                    _campoDemo(
                      titulo: 'Número',
                      valor: '1600',
                      mostrar: numeroListo,
                      icono: Icons.tag,
                      opcional: true,
                    ),
                    const SizedBox(height: 10),
                    _campoDemo(
                      titulo: 'Colonia *',
                      valor: 'Bosques de Camelinas',
                      mostrar: coloniaLista,
                      icono: Icons.location_city_outlined,
                    ),
                    const SizedBox(height: 14),
                    AnimatedScale(
                      duration: const Duration(milliseconds: 350),
                      scale: pulsarUbicacion ? 1.035 : 1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: pulsarUbicacion || buscando
                              ? Colors.deepPurple.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: pulsarUbicacion || buscando
                                ? Colors.deepPurple
                                : Colors.grey.shade500,
                            width: pulsarUbicacion ? 2 : 1,
                          ),
                          boxShadow: pulsarUbicacion
                              ? [
                                  BoxShadow(
                                    color: Colors.deepPurple.withValues(
                                      alpha: 0.18,
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
                              duration: const Duration(milliseconds: 250),
                              child: buscando
                                  ? const SizedBox(
                                      key: ValueKey('buscando'),
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.my_location,
                                      key: ValueKey('ubicacion'),
                                      color: Colors.deepPurple,
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              buscando
                                  ? 'Obteniendo...'
                                  : 'Obtener coordenadas',
                              style: const TextStyle(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _campoDemo(
                      titulo: 'Coordenadas *',
                      valor: '19.6841234, -101.1805678',
                      mostrar: coordenadasListas,
                      icono: Icons.pin_drop_outlined,
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Container(
                        key: ValueKey('$buscando-$coordenadasListas'),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: coordenadasListas
                              ? Colors.green.withValues(alpha: 0.10)
                              : buscando
                              ? Colors.orange.withValues(alpha: 0.10)
                              : Colors.grey.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              coordenadasListas
                                  ? Icons.check_circle_outline
                                  : buscando
                                  ? Icons.location_searching
                                  : Icons.info_outline,
                              color: coordenadasListas
                                  ? Colors.green
                                  : buscando
                                  ? Colors.orange
                                  : Colors.grey.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                coordenadasListas
                                    ? 'Ubicación obtenida. Dirección detectada.'
                                    : buscando
                                    ? 'Obteniendo coordenadas y dirección...'
                                    : 'Aún no se han capturado coordenadas.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: coordenadasListas
                                      ? Colors.green.shade800
                                      : buscando
                                      ? Colors.orange.shade800
                                      : Colors.grey.shade700,
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
                icon: Icons.place_outlined,
                titulo: 'Lugar y colonia',
                texto:
                    'Captura el lugar donde se instalará el punto. El número es opcional, pero municipio, lugar y colonia deben corresponder a la ubicación real.',
              ),
              const SizedBox(height: 12),
              _aviso(
                icon: Icons.my_location,
                titulo: 'Obtén las coordenadas en el punto',
                texto:
                    'Pulsa “Obtener coordenadas” cuando te encuentres físicamente en el lugar del operativo. El sistema intentará completar también los datos de dirección disponibles.',
              ),
              const SizedBox(height: 12),
              _avisoAdvertencia(
                icon: Icons.gps_fixed,
                titulo: 'No captures una ubicación distinta',
                texto:
                    'Las coordenadas deben corresponder al sitio real donde se encuentra instalado el operativo.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pasoActivar() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;

        final resumenListo = progreso >= 0.18;
        final botonActivo = progreso >= 0.32 && progreso < 0.52;
        final guardando = progreso >= 0.52 && progreso < 0.70;
        final completado = progreso >= 0.70;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('3', 'Activa el operativo'),
              const SizedBox(height: 8),
              const Text(
                'Revisa la información y, cuando todo sea correcto, activa el operativo.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.fact_check_outlined, color: Colors.blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Revisión final',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _resumenDemo(
                      icono: Icons.fact_check_outlined,
                      titulo: 'Operativo',
                      valor: widget.operativoNombre,
                      listo: resumenListo,
                    ),
                    const SizedBox(height: 8),
                    _resumenDemo(
                      icono: Icons.location_on_outlined,
                      titulo: 'Punto',
                      valor: 'Av. Camelinas · Bosques de Camelinas',
                      listo: resumenListo,
                    ),
                    const SizedBox(height: 8),
                    _resumenDemo(
                      icono: Icons.pin_drop_outlined,
                      titulo: 'Coordenadas',
                      valor: 'Ubicación confirmada',
                      listo: resumenListo,
                    ),
                    const SizedBox(height: 18),
                    AnimatedScale(
                      duration: const Duration(milliseconds: 350),
                      scale: botonActivo ? 1.035 : 1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: completado
                              ? Colors.green.withValues(alpha: 0.12)
                              : botonActivo || guardando
                              ? Colors.deepPurple.withValues(alpha: 0.10)
                              : const Color(0xfffaf7ff),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: completado
                                ? Colors.green
                                : botonActivo || guardando
                                ? Colors.deepPurple
                                : Colors.grey.shade400,
                            width: botonActivo ? 2 : 1,
                          ),
                          boxShadow: botonActivo
                              ? [
                                  BoxShadow(
                                    color: Colors.deepPurple.withValues(
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
                                          : Icons.play_circle_outline,
                                      key: ValueKey(completado),
                                      color: completado
                                          ? Colors.green
                                          : Colors.deepPurple,
                                    ),
                            ),
                            const SizedBox(width: 10),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                guardando
                                    ? 'Guardando...'
                                    : completado
                                    ? 'Operativo activado'
                                    : 'Activar operativo',
                                key: ValueKey('$guardando-$completado'),
                                style: TextStyle(
                                  color: completado
                                      ? Colors.green.shade800
                                      : Colors.deepPurple,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 450),
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
                                'El operativo quedó activo y aparecerá en el listado.',
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
              _avisoAdvertencia(
                icon: Icons.fact_check_outlined,
                titulo: 'Revisa antes de activar',
                texto:
                    'Confirma que el municipio, lugar, colonia y coordenadas correspondan al punto correcto antes de guardar.',
              ),
              const SizedBox(height: 12),
              _aviso(
                icon: Icons.play_circle_outline,
                titulo: 'Pulsa “Activar operativo”',
                texto:
                    'Cuando todos los datos obligatorios estén completos, pulsa el botón para crear y activar el operativo.',
              ),
              const SizedBox(height: 12),
              _aviso(
                icon: Icons.list_alt_outlined,
                titulo: 'Después de activarlo',
                texto:
                    'El nuevo operativo aparecerá en el listado y podrá comenzar a recibir las capturas correspondientes.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _campoFijoDemo({
    required String titulo,
    required String valor,
    required IconData icono,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Row(
        children: [
          Icon(icono, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, size: 18, color: Colors.grey.shade500),
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
            ? Colors.deepPurple.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: mostrar ? Colors.deepPurple : Colors.grey.shade400,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icono,
            color: mostrar ? Colors.deepPurple : Colors.grey.shade600,
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
                    color: mostrar ? Colors.deepPurple : Colors.grey.shade700,
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

  Widget _selectDemo({
    required String titulo,
    required String valor,
    required bool seleccionado,
    required bool mostrarMenu,
    required List<String> opciones,
    required IconData icono,
  }) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: mostrarMenu
                ? Colors.deepPurple.withValues(alpha: 0.07)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: mostrarMenu ? Colors.deepPurple : Colors.grey.shade400,
              width: mostrarMenu ? 1.7 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icono,
                color: seleccionado ? Colors.deepPurple : Colors.grey.shade600,
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
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Text(
                        seleccionado ? valor : '-- Seleccione --',
                        key: ValueKey('$titulo-$seleccionado'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: seleccionado
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ],
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 400),
          crossFadeState: mostrarMenu
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: const Color(0xfffff8ff),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: opciones
                  .map(
                    (opcion) => Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      color: opcion == valor
                          ? Colors.deepPurple.withValues(alpha: 0.08)
                          : Colors.transparent,
                      child: Text(
                        opcion,
                        style: TextStyle(
                          fontWeight: opcion == valor
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _resumenDemo({
    required IconData icono,
    required String titulo,
    required String valor,
    required bool listo,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: listo ? 1 : 0.35,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: listo
              ? Colors.green.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: listo
                ? Colors.green.withValues(alpha: 0.35)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(icono, color: listo ? Colors.green.shade700 : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    listo ? valor : 'Pendiente',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: listo ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (listo)
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ),
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
