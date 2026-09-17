import 'package:flutter/material.dart';

class FormularioConductorHelpSheet extends StatefulWidget {
  const FormularioConductorHelpSheet({super.key});

  @override
  State<FormularioConductorHelpSheet> createState() =>
      _FormularioConductorHelpSheetState();
}

class _FormularioConductorHelpSheetState
    extends State<FormularioConductorHelpSheet>
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
      duration: const Duration(seconds: 14),
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
                const Icon(Icons.person_outline, color: Colors.blue),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cómo llenar el formulario del conductor',
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
              },
              children: [
                _pasoEscanearLicencia(),
                _pasoDatosPersonales(),
                _pasoLicenciaYCondiciones(),
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

  Widget _pasoEscanearLicencia() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;

        final mostrarCamara = progreso >= 0.16;
        final qrDetectado = progreso >= 0.42;
        final mostrarFormulario = progreso >= 0.56;

        final nombreListo = progreso >= 0.64;
        final numeroListo = progreso >= 0.72;
        final tipoListo = progreso >= 0.80;
        final vigenciaLista = progreso >= 0.88;
        final permanenteLista = progreso >= 0.95;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('1', 'Escanear licencia de conducir'),
              const SizedBox(height: 8),
              const Text(
                'Si el conductor presenta una licencia con código QR, puedes escanearla para llenar automáticamente los datos que la aplicación logre reconocer.',
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
                        Icon(Icons.qr_code_scanner, color: Colors.blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Demostración',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    AnimatedScale(
                      duration: const Duration(milliseconds: 400),
                      scale: mostrarCamara ? 1 : 1.04,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xfffaf7ff),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: progreso < 0.16
                                ? Colors.deepPurple
                                : Colors.grey.shade500,
                            width: progreso < 0.16 ? 2 : 1,
                          ),
                          boxShadow: progreso < 0.16
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
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_scanner,
                              color: Colors.deepPurple,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Escanear licencia de conducir',
                              style: TextStyle(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 500),
                      crossFadeState: mostrarCamara
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: _camaraLicenciaDemo(
                        progreso: progreso,
                        qrDetectado: qrDetectado,
                      ),
                    ),

                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 500),
                      crossFadeState: mostrarFormulario
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.auto_awesome, color: Colors.green),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Licencia reconocida. Se llenan los datos disponibles.',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            _campoDemo(
                              titulo: 'Nombre del conductor',
                              valor: 'JUAN PÉREZ ITURBIDE',
                              mostrar: nombreListo,
                              icono: Icons.person_outline,
                            ),

                            const SizedBox(height: 8),

                            _campoDemo(
                              titulo: 'Número de licencia',
                              valor: 'MICH123456789',
                              mostrar: numeroListo,
                              icono: Icons.badge_outlined,
                            ),

                            const SizedBox(height: 8),

                            _campoDemo(
                              titulo: 'Tipo de licencia',
                              valor: 'AUTOMOVILISTA',
                              mostrar: tipoListo,
                              icono: Icons.credit_card_outlined,
                            ),

                            const SizedBox(height: 8),

                            _campoDemo(
                              titulo: 'Vigencia',
                              valor: '2029-09-15',
                              mostrar: vigenciaLista,
                              icono: Icons.event_outlined,
                            ),

                            const SizedBox(height: 8),

                            AnimatedContainer(
                              duration: const Duration(milliseconds: 450),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: permanenteLista
                                    ? Colors.deepPurple.withValues(alpha: 0.05)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: permanenteLista
                                      ? Colors.deepPurple
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.all_inclusive,
                                    color: permanenteLista
                                        ? Colors.deepPurple
                                        : Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Licencia permanente',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: permanenteLista
                                        ? const Icon(
                                            Icons.toggle_on,
                                            key: ValueKey('permanente-on'),
                                            color: Colors.deepPurple,
                                            size: 42,
                                          )
                                        : const Icon(
                                            Icons.toggle_off,
                                            key: ValueKey('permanente-off'),
                                            color: Colors.grey,
                                            size: 42,
                                          ),
                                  ),
                                ],
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
                icon: Icons.touch_app_outlined,
                titulo: 'Pulsa “Escanear licencia de conducir”',
                texto:
                    'La aplicación abrirá la cámara del teléfono para buscar el código QR de la licencia.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.qr_code_2,
                titulo: 'Coloca el QR dentro del recuadro',
                texto:
                    'Mantén el código completo dentro del cuadro y procura que se encuentre bien enfocado. No es necesario acercar demasiado el teléfono.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.center_focus_strong,
                titulo: 'Si la cámara no enfoca',
                texto:
                    'Puedes tocar directamente sobre el código QR para intentar enfocar esa zona.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.camera_alt_outlined,
                titulo: 'También puedes tomar una fotografía',
                texto:
                    'Si el QR no puede leerse en vivo, utiliza el botón de cámara del lector y toma una fotografía nítida donde aparezca completo.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.auto_awesome,
                titulo: 'Autocompletado',
                texto:
                    'Cuando el QR contiene información reconocible, la aplicación puede llenar automáticamente el nombre, número de licencia, tipo de licencia y la vigencia o condición permanente.',
              ),

              const SizedBox(height: 12),

              _avisoAdvertencia(
                icon: Icons.fact_check_outlined,
                titulo: 'Verifica siempre los datos',
                texto:
                    'El escaneo facilita la captura, pero antes de continuar debes comprobar que los datos obtenidos correspondan realmente a la licencia y al conductor.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pasoDatosPersonales() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;

        final nombreListo = progreso >= 0.14;
        final telefonoListo = progreso >= 0.28;
        final domicilioListo = progreso >= 0.42;
        final sexoListo = progreso >= 0.56;
        final ocupacionLista = progreso >= 0.70;
        final edadLista = progreso >= 0.84;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('2', 'Datos personales del conductor'),
              const SizedBox(height: 8),

              const Text(
                'Si algún dato no fue obtenido mediante el escaneo de la licencia, completa manualmente la información del conductor.',
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
                        Icon(Icons.person_outline, color: Colors.blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ejemplo de captura',
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
                      titulo: 'Nombre del conductor',
                      valor: 'JUAN PÉREZ ITURBIDE',
                      mostrar: nombreListo,
                      icono: Icons.person,
                    ),

                    const SizedBox(height: 9),

                    _campoDemo(
                      titulo: 'Teléfono',
                      valor: '4434765057',
                      mostrar: telefonoListo,
                      icono: Icons.phone,
                    ),

                    const SizedBox(height: 9),

                    _campoDemo(
                      titulo: 'Domicilio',
                      valor: 'MORELIA, MICHOACÁN',
                      mostrar: domicilioListo,
                      icono: Icons.home_outlined,
                    ),

                    const SizedBox(height: 9),

                    AnimatedContainer(
                      duration: const Duration(milliseconds: 450),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: sexoListo
                            ? Colors.deepPurple.withValues(alpha: 0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sexoListo
                              ? Colors.deepPurple
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            color: sexoListo
                                ? Colors.deepPurple
                                : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sexo',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 2),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  child: Text(
                                    sexoListo
                                        ? 'MASCULINO'
                                        : '-- Seleccione --',
                                    key: ValueKey(sexoListo),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: sexoListo
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

                    const SizedBox(height: 9),

                    _campoDemo(
                      titulo: 'Ocupación',
                      valor: 'EMPLEADO',
                      mostrar: ocupacionLista,
                      icono: Icons.work_outline,
                    ),

                    const SizedBox(height: 9),

                    _campoDemo(
                      titulo: 'Edad',
                      valor: '32',
                      mostrar: edadLista,
                      icono: Icons.numbers,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              _aviso(
                icon: Icons.person_outline,
                titulo: 'Nombre del conductor',
                texto:
                    'Captura el nombre de la persona que realmente conducía el vehículo al momento del hecho.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.phone_outlined,
                titulo: 'Teléfono',
                texto:
                    'Captura el número telefónico del conductor. Puedes escribir los 10 dígitos directamente; la aplicación también puede normalizar números pegados con +52.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.home_outlined,
                titulo: 'Domicilio',
                texto:
                    'Captura el domicilio del conductor cuando cuentes con la información.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.badge_outlined,
                titulo: 'Sexo, ocupación y edad',
                texto:
                    'Selecciona el sexo y completa la ocupación y edad con los datos reales de la persona.',
              ),

              const SizedBox(height: 12),

              _avisoAdvertencia(
                icon: Icons.no_accounts_outlined,
                titulo: '¿No existe conductor que registrar?',
                texto:
                    'Si el vehículo estaba estacionado o abandonado y no existe un conductor que capturar, no escribas ESTACIONADO, ABANDONADO, SIN CONDUCTOR, N/A ni textos similares en el nombre. Sal de esta captura utilizando la flecha de regreso ubicada en la esquina superior izquierda.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pasoLicenciaYCondiciones() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;

        final vigenciaLista = progreso >= 0.14;
        final tipoListo = progreso >= 0.27;
        final estadoListo = progreso >= 0.40;
        final numeroListo = progreso >= 0.53;

        final cinturonListo = progreso >= 0.64;
        final antecedentesListos = progreso >= 0.74;
        final lesionesListas = progreso >= 0.84;
        final alcoholemiaLista = progreso >= 0.91;
        final alientoListo = progreso >= 0.97;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('3', 'Licencia y condiciones del conductor'),

              const SizedBox(height: 8),

              const Text(
                'Completa la información de la licencia y registra las condiciones observadas o verificadas durante la atención.',
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
                        Icon(Icons.credit_card_outlined, color: Colors.blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ejemplo de llenado',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    AnimatedContainer(
                      duration: const Duration(milliseconds: 450),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Licencia permanente',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(
                            Icons.toggle_off,
                            color: Colors.grey,
                            size: 42,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 9),

                    _campoDemo(
                      titulo: 'Vigencia licencia',
                      valor: '2029-09-15',
                      mostrar: vigenciaLista,
                      icono: Icons.event_outlined,
                    ),

                    const SizedBox(height: 9),

                    _campoDemo(
                      titulo: 'Tipo de licencia',
                      valor: 'AUTOMOVILISTA',
                      mostrar: tipoListo,
                      icono: Icons.credit_card_outlined,
                    ),

                    const SizedBox(height: 9),

                    _campoDemo(
                      titulo: 'Estado de licencia',
                      valor: 'MICHOACÁN',
                      mostrar: estadoListo,
                      icono: Icons.map_outlined,
                    ),

                    const SizedBox(height: 9),

                    _campoDemo(
                      titulo: 'Número de licencia',
                      valor: 'MICH123456789',
                      mostrar: numeroListo,
                      icono: Icons.numbers,
                    ),

                    const SizedBox(height: 14),

                    _switchDemo(
                      titulo: 'Cinturón',
                      activo: cinturonListo,
                      icono: Icons.airline_seat_recline_normal,
                    ),

                    const SizedBox(height: 9),

                    _switchDemo(
                      titulo: 'Antecedente conductor',
                      activo: antecedentesListos,
                      icono: Icons.manage_search_outlined,
                      advertencia: true,
                    ),

                    const SizedBox(height: 9),

                    _switchDemo(
                      titulo: 'Certificado lesiones',
                      activo: lesionesListas,
                      icono: Icons.medical_information_outlined,
                    ),

                    const SizedBox(height: 9),

                    _switchDemo(
                      titulo: 'Certificado alcoholemia',
                      activo: alcoholemiaLista,
                      icono: Icons.science_outlined,
                    ),

                    const SizedBox(height: 9),

                    _switchDemo(
                      titulo: 'Aliento etílico',
                      activo: alientoListo,
                      icono: Icons.local_bar_outlined,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              _aviso(
                icon: Icons.all_inclusive,
                titulo: 'Licencia permanente o vigencia',
                texto:
                    'Si la licencia es permanente activa ese control. Cuando no lo sea, registra la fecha de vigencia correspondiente.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.credit_card_outlined,
                titulo: 'Datos de la licencia',
                texto:
                    'Captura el tipo de licencia, el estado que la expidió y su número cuando cuentes con esos datos.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.airline_seat_recline_normal,
                titulo: 'Cinturón',
                texto:
                    'Activa el control cuando corresponda registrar que el conductor utilizaba cinturón de seguridad.',
              ),

              const SizedBox(height: 12),

              _avisoAdvertencia(
                icon: Icons.manage_search_outlined,
                titulo: 'Antecedentes del conductor',
                texto:
                    'Activa este control únicamente después de haber realizado la consulta correspondiente al conductor que estás registrando.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.medical_information_outlined,
                titulo: 'Certificados',
                texto:
                    'Marca Certificado lesiones y Certificado alcoholemia únicamente cuando esos certificados correspondan a la atención realizada.',
              ),

              const SizedBox(height: 12),

              _avisoAdvertencia(
                icon: Icons.local_bar_outlined,
                titulo: 'Aliento etílico',
                texto:
                    'Activa esta opción únicamente cuando corresponda registrar la presencia de aliento etílico en el conductor.',
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Al terminar, revisa que la información corresponda al conductor correcto antes de pulsar “Guardar conductor”.',
                        style: TextStyle(
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _camaraLicenciaDemo({
    required double progreso,
    required bool qrDetectado,
  }) {
    final posicionLinea = ((progreso * 5) % 1);

    return Container(
      width: double.infinity,
      height: 330,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey.shade800,
                    Colors.grey.shade600,
                    Colors.grey.shade800,
                  ],
                ),
              ),
            ),
          ),

          const Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Icon(Icons.arrow_back, color: Colors.white),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Escanear licencia',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.flashlight_on, color: Colors.white, size: 21),
                SizedBox(width: 12),
                Icon(Icons.center_focus_strong, color: Colors.white, size: 21),
                SizedBox(width: 12),
                Icon(Icons.camera_alt_outlined, color: Colors.white, size: 21),
              ],
            ),
          ),

          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: qrDetectado
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: qrDetectado ? Colors.greenAccent : Colors.white,
                  width: qrDetectado ? 3 : 2,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 500),
                      scale: qrDetectado ? 1.08 : 0.90,
                      child: Icon(
                        Icons.qr_code_2,
                        size: 120,
                        color: qrDetectado ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),

                  if (!qrDetectado)
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 18 + (145 * posicionLinea),
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.withValues(alpha: 0.65),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                qrDetectado
                    ? 'QR de licencia reconocido'
                    : 'Coloca el QR completo dentro del cuadro',
                key: ValueKey(qrDetectado),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: qrDetectado ? Colors.greenAccent : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
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
      duration: const Duration(milliseconds: 450),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: mostrar
            ? Colors.deepPurple.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: mostrar
              ? Colors.deepPurple.withValues(alpha: 0.65)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icono,
            color: mostrar ? Colors.deepPurple : Colors.grey.shade500,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Column(
                key: ValueKey('$titulo-$mostrar'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 12,
                      color: mostrar ? Colors.deepPurple : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mostrar ? valor : '—',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: mostrar ? FontWeight.w700 : FontWeight.normal,
                      color: mostrar ? Colors.black87 : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (mostrar)
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  Widget _switchDemo({
    required String titulo,
    required bool activo,
    required IconData icono,
    bool advertencia = false,
  }) {
    final color = advertencia ? Colors.deepOrange : Colors.deepPurple;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: activo ? color.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: activo ? color.withValues(alpha: 0.70) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(icono, color: activo ? color : Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                color: activo ? color : Colors.black87,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: activo
                ? Icon(
                    Icons.toggle_on,
                    key: ValueKey('$titulo-on'),
                    color: color,
                    size: 42,
                  )
                : Icon(
                    Icons.toggle_off,
                    key: ValueKey('$titulo-off'),
                    color: Colors.grey,
                    size: 42,
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
