import 'package:flutter/material.dart';

class FormularioVehiculoHelpSheet extends StatefulWidget {
  const FormularioVehiculoHelpSheet({super.key});

  @override
  State<FormularioVehiculoHelpSheet> createState() =>
      _FormularioVehiculoHelpSheetState();
}

class _FormularioVehiculoHelpSheetState
    extends State<FormularioVehiculoHelpSheet>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();

  late final AnimationController _demoController;

  int _pagina = 0;

  static const int _totalPaginas = 4;

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
                const Icon(Icons.directions_car_outlined, color: Colors.blue),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cómo llenar el formulario del vehículo',
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
                _pasoEscanearTarjeta(),
                _pasoCapturaManualBasica(),
                _pasoDatosCirculacion(),
                _pasoTrasladoDanosAntecedentes(),
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

  Widget _pasoEscanearTarjeta() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;

        final mostrarCamara = progreso >= 0.18;
        final qrDetectado = progreso >= 0.42;
        final mostrarFormulario = progreso >= 0.58;

        final tipoListo = progreso >= 0.64;
        final marcaLista = progreso >= 0.70;
        final lineaLista = progreso >= 0.76;
        final modeloListo = progreso >= 0.82;
        final placasListas = progreso >= 0.88;
        final serieLista = progreso >= 0.94;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('1', 'Escanear tarjeta de circulación'),
              const SizedBox(height: 8),
              const Text(
                'Si tienes la tarjeta de circulación, puedes utilizar su código QR para llenar automáticamente varios datos del vehículo.',
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
                            color: progreso < 0.18
                                ? Colors.deepPurple
                                : Colors.grey.shade500,
                            width: progreso < 0.18 ? 2 : 1,
                          ),
                          boxShadow: progreso < 0.18
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
                              'Escanear tarjeta de circulación',
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
                      secondChild: _camaraDemo(
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
                                      'QR reconocido. Se llenan los datos disponibles.',
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
                              titulo: 'Tipo de vehículo *',
                              valor: 'MOTOCICLETA',
                              mostrar: tipoListo,
                              icono: Icons.directions_car_outlined,
                            ),
                            const SizedBox(height: 8),
                            _campoDemo(
                              titulo: 'Marca *',
                              valor: 'KTM',
                              mostrar: marcaLista,
                              icono: Icons.sell_outlined,
                            ),
                            const SizedBox(height: 8),
                            _campoDemo(
                              titulo: 'Línea *',
                              valor: 'ADVENTURE 250',
                              mostrar: lineaLista,
                              icono: Icons.text_fields,
                            ),
                            const SizedBox(height: 8),
                            _campoDemo(
                              titulo: 'Modelo',
                              valor: '2021',
                              mostrar: modeloListo,
                              icono: Icons.calendar_month_outlined,
                            ),
                            const SizedBox(height: 8),
                            _campoDemo(
                              titulo: 'Placas',
                              valor: '99PKF8',
                              mostrar: placasListas,
                              icono: Icons.credit_card_outlined,
                            ),
                            const SizedBox(height: 8),
                            _campoDemo(
                              titulo: 'No. Serie',
                              valor: 'VBKJGD401MC037269',
                              mostrar: serieLista,
                              icono: Icons.confirmation_number_outlined,
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
                titulo: 'Pulsa “Escanear tarjeta de circulación”',
                texto:
                    'La aplicación abrirá la cámara del teléfono para buscar el código QR de la tarjeta de circulación.',
              ),
              const SizedBox(height: 12),
              _aviso(
                icon: Icons.qr_code_2,
                titulo: 'Apunta al código QR',
                texto:
                    'Coloca el QR de la tarjeta dentro del recuadro de la cámara y mantenlo visible hasta que sea reconocido.',
              ),
              const SizedBox(height: 12),
              _aviso(
                icon: Icons.auto_awesome,
                titulo: 'Autocompletado',
                texto:
                    'Cuando el QR contiene información reconocible, la aplicación llena automáticamente los campos que pueda identificar.',
              ),
              const SizedBox(height: 12),
              _avisoAdvertencia(
                icon: Icons.fact_check_outlined,
                titulo: 'Revisa siempre la información',
                texto:
                    'El escaneo facilita la captura, pero debes verificar que los datos autocompletados coincidan con el vehículo y con la tarjeta de circulación antes de guardar.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pasoCapturaManualBasica() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;

        final tipoListo = progreso >= 0.18;
        final carroceriaLista = progreso >= 0.36;
        final marcaLista = progreso >= 0.54;
        final lineaLista = progreso >= 0.72;
        final modeloListo = progreso >= 0.88;

        final abrirTipo = progreso >= 0.06 && progreso < 0.18;
        final abrirCarroceria = progreso >= 0.24 && progreso < 0.36;
        final abrirMarca = progreso >= 0.42 && progreso < 0.54;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('2', 'Captura manual del vehículo'),
              const SizedBox(height: 8),

              const Text(
                'Si no utilizaste el código QR, o si algún dato no fue reconocido, puedes completar manualmente la información del vehículo.',
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
                        Icon(Icons.edit_note_outlined, color: Colors.blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ejemplo de llenado manual',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _selectManualDemo(
                      titulo: 'Tipo de Vehículo *',
                      valor: 'Automóvil',
                      seleccionado: tipoListo,
                      mostrarMenu: abrirTipo,
                      opciones: const [
                        'Automóvil',
                        'Camioneta',
                        'Camión',
                        'Motocicleta',
                        'Bicicleta',
                        'Remolque',
                        'Maquinaria',
                        'Tren',
                        'Semoviente',
                      ],
                      icono: Icons.directions_car_outlined,
                    ),

                    const SizedBox(height: 10),

                    _selectManualDemo(
                      titulo: 'Carrocería *',
                      valor: 'Sedán',
                      seleccionado: carroceriaLista,
                      mostrarMenu: abrirCarroceria,
                      opciones: const [
                        'Sedán',
                        'Hatchback',
                        'Coupé',
                        'SUV',
                        'Convertible',
                      ],
                      icono: Icons.merge_type,
                      deshabilitado: !tipoListo,
                    ),

                    const SizedBox(height: 10),

                    _selectManualDemo(
                      titulo: 'Marca *',
                      valor: 'AUDI',
                      seleccionado: marcaLista,
                      mostrarMenu: abrirMarca,
                      opciones: const [
                        'ABARTH',
                        'ACURA',
                        'ALFA ROMEO',
                        'AION',
                        'ARCFOX',
                        'AITO',
                        'AUDI',
                        'AVATR',
                        'BAIC',
                        'BENTLEY',
                        'BMW',
                      ],
                      icono: Icons.sell_outlined,
                      deshabilitado: !carroceriaLista,
                    ),

                    const SizedBox(height: 10),

                    _campoManualDemo(
                      titulo: 'Línea *',
                      valor: 'A4',
                      mostrar: lineaLista,
                      icono: Icons.text_fields,
                    ),

                    const SizedBox(height: 10),

                    _campoManualDemo(
                      titulo: 'Modelo (opcional)',
                      valor: '2021',
                      mostrar: modeloListo,
                      icono: Icons.calendar_month_outlined,
                    ),

                    const SizedBox(height: 14),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Container(
                        key: ValueKey(
                          '$tipoListo-$carroceriaLista-$marcaLista-$lineaLista-$modeloListo',
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
                          !tipoListo
                              ? 'Primero selecciona el tipo de vehículo.'
                              : !carroceriaLista
                              ? 'Ahora selecciona la carrocería.'
                              : !marcaLista
                              ? 'Las marcas disponibles se ajustan al vehículo seleccionado.'
                              : !lineaLista
                              ? 'La línea se escribe manualmente.'
                              : !modeloListo
                              ? 'El modelo corresponde al año del vehículo.'
                              : 'Primeros datos completados.',
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
                icon: Icons.directions_car_outlined,
                titulo: 'Tipo de vehículo',
                texto:
                    'Selecciona primero el tipo general que corresponda: automóvil, camioneta, camión, motocicleta, bicicleta, remolque, maquinaria, tren o semoviente.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.merge_type,
                titulo: 'Carrocería',
                texto:
                    'Las opciones de carrocería dependen del Tipo de Vehículo seleccionado. Por ejemplo, al elegir Automóvil aparecerán únicamente las carrocerías correspondientes a un automóvil.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.sell_outlined,
                titulo: 'Marca',
                texto:
                    'La lista de marcas también se ajusta de acuerdo con el tipo de vehículo y la carrocería seleccionados. Selecciona la marca que corresponda al vehículo atendido.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.text_fields,
                titulo: 'Línea',
                texto:
                    'La línea se captura manualmente. Escribe la denominación comercial del vehículo, por ejemplo A4, Jetta, Versa, Adventure 250 o la que corresponda.',
              ),

              const SizedBox(height: 12),

              _avisoAdvertencia(
                icon: Icons.calendar_month_outlined,
                titulo: 'Modelo',
                texto:
                    'Modelo se refiere al año del vehículo. Es un dato opcional: si no conoces el año correcto, es mejor dejar el campo vacío que capturar un dato inventado.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pasoDatosCirculacion() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;

        final abrirColor = progreso >= 0.04 && progreso < 0.14;
        final colorListo = progreso >= 0.14;

        final placasListas = progreso >= 0.28;

        final abrirEstado = progreso >= 0.34 && progreso < 0.43;
        final estadoListo = progreso >= 0.43;

        final abrirServicio = progreso >= 0.49 && progreso < 0.59;
        final servicioFederal = progreso >= 0.59;

        final serieLista = progreso >= 0.70;
        final capacidadLista = progreso >= 0.82;
        final nombreLista = progreso >= 0.92;

        final mostrarEstadoPlacas = placasListas && !servicioFederal;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('3', 'Datos de circulación e identificación'),

              const SizedBox(height: 8),

              const Text(
                'Continúa con los datos de identificación y circulación del vehículo. Los campos opcionales deben dejarse vacíos cuando no cuentes con información real.',
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
                        Icon(Icons.badge_outlined, color: Colors.blue),
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

                    _selectManualDemo(
                      titulo: 'Color *',
                      valor: 'Blanco',
                      seleccionado: colorListo,
                      mostrarMenu: abrirColor,
                      opciones: const [
                        'Blanco',
                        'Blanco perla',
                        'Negro',
                        'Gris',
                        'Gris Oxford',
                        'Plata',
                        'Rojo',
                        'Vino',
                        'Azul',
                        'Azul marino',
                        'Verde',
                        'Verde oscuro',
                        'Arena',
                      ],
                      icono: Icons.palette_outlined,
                    ),

                    const SizedBox(height: 10),

                    _campoManualDemo(
                      titulo: 'Placas (opcional)',
                      valor: 'PFP123A',
                      mostrar: placasListas,
                      icono: Icons.credit_card_outlined,
                    ),

                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 450),
                      crossFadeState: placasListas
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _campoManualDemo(
                          titulo:
                              'Permiso para circular: estado o asociación (opcional)',
                          valor: '',
                          mostrar: false,
                          icono: Icons.description_outlined,
                        ),
                      ),
                    ),

                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 450),
                      crossFadeState: mostrarEstadoPlacas
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _selectManualDemo(
                          titulo: 'Estado de placas *',
                          valor: 'MICHOACÁN',
                          seleccionado: estadoListo,
                          mostrarMenu: abrirEstado,
                          opciones: const [
                            'MICHOACÁN',
                            'JALISCO',
                            'GUANAJUATO',
                            'QUERÉTARO',
                            'ESTADO DE MÉXICO',
                            'CIUDAD DE MÉXICO',
                          ],
                          icono: Icons.map_outlined,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    _selectManualDemo(
                      titulo: 'Tipo de servicio de placa *',
                      valor: servicioFederal
                          ? 'SERVICIO PÚBLICO FEDERAL'
                          : 'PARTICULAR',
                      seleccionado: true,
                      mostrarMenu: abrirServicio,
                      opciones: const [
                        'PARTICULAR',
                        'SERVICIO PÚBLICO ESTATAL',
                        'SERVICIO PÚBLICO FEDERAL',
                        'OFICIAL',
                      ],
                      icono: Icons.miscellaneous_services,
                    ),

                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 450),
                      crossFadeState: servicioFederal
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.visibility_off_outlined,
                                color: Colors.deepPurple,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Al seleccionar Servicio Público Federal, Estado de placas deja de mostrarse.',
                                  style: TextStyle(
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    _campoManualDemo(
                      titulo: 'No. Serie / NIV (opcional)',
                      valor: '3VW2K7AJ5EM388742',
                      mostrar: serieLista,
                      icono: Icons.confirmation_number_outlined,
                    ),

                    const SizedBox(height: 10),

                    _campoManualDemo(
                      titulo: 'Capacidad de personas *',
                      valor: '5',
                      mostrar: capacidadLista,
                      icono: Icons.people_outline,
                    ),

                    const SizedBox(height: 10),

                    _campoManualDemo(
                      titulo: 'Nombre tarjeta circulación (opcional)',
                      valor: 'JUAN PÉREZ ITURBIDE',
                      mostrar: nombreLista,
                      icono: Icons.badge_outlined,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              _aviso(
                icon: Icons.palette_outlined,
                titulo: 'Color',
                texto:
                    'Selecciona el color que corresponda al vehículo dentro del catálogo disponible.',
              ),

              const SizedBox(height: 12),

              _avisoAdvertencia(
                icon: Icons.credit_card_outlined,
                titulo: 'Placas',
                texto:
                    'Es un campo opcional. Si el vehículo no cuenta con placas, déjalo vacío. No escribas S/P, SIN PLACAS, N/A, NO TIENE ni ningún otro texto para sustituir el dato.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.map_outlined,
                titulo: 'Estado de placas',
                texto:
                    'Cuando capturas una placa, se habilita el campo para seleccionar el estado al que pertenece. Selecciona la entidad que realmente corresponda a esas placas.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.miscellaneous_services,
                titulo: 'Tipo de servicio de placa',
                texto:
                    'Selecciona entre Particular, Servicio Público Estatal, Servicio Público Federal u Oficial. Si seleccionas Servicio Público Federal, el campo Estado de placas se oculta.',
              ),

              const SizedBox(height: 12),

              _avisoAdvertencia(
                icon: Icons.confirmation_number_outlined,
                titulo: 'NIV / número de serie',
                texto:
                    'Es opcional. Si lo capturas debe contener exactamente 17 caracteres. Si no cuentas con el dato completo, deja el campo vacío. No escribas NO VISIBLE, SIN DATO, N/A u otros textos sustitutos.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.people_outline,
                titulo: 'Capacidad de personas',
                texto:
                    'Captura la cantidad de personas que pueden viajar dentro del vehículo, es decir, el número de plazas o asientos disponibles.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.badge_outlined,
                titulo: 'Nombre en tarjeta de circulación',
                texto:
                    'Si cuentas con la tarjeta, captura el nombre que aparezca registrado en ella. Es un campo opcional.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pasoTrasladoDanosAntecedentes() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;

        final abrirGrua = progreso >= 0.04 && progreso < 0.14;
        final gruaLista = progreso >= 0.14;

        final corralonListo = progreso >= 0.25;

        final abrirAseguradora = progreso >= 0.31 && progreso < 0.42;
        final aseguradoraLista = progreso >= 0.42;

        final montoListo = progreso >= 0.55;
        final partesListas = progreso >= 0.68;

        final antecedentesRevisados = progreso >= 0.80;
        final reporteRoboListo = progreso >= 0.92;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('4', 'Traslado, daños y antecedentes'),

              const SizedBox(height: 8),

              const Text(
                'Completa la información relacionada con el traslado del vehículo, los daños observados y la revisión de antecedentes.',
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

                    _selectManualDemo(
                      titulo: 'Grúa (empresa)',
                      valor: 'DANNY\'S',
                      seleccionado: gruaLista,
                      mostrarMenu: abrirGrua,
                      opciones: const [
                        'SIN GRÚA / N/A',
                        'DANNY\'S',
                        'GALVÁN',
                        'MUÑOZ',
                        'SERVÍ-GRÚAS PROFESIONALES',
                      ],
                      icono: Icons.local_shipping_outlined,
                    ),

                    const SizedBox(height: 10),

                    _selectManualDemo(
                      titulo: 'Corralón (empresa)',
                      valor: 'SIN CORRALÓN / N/A',
                      seleccionado: corralonListo,
                      mostrarMenu: false,
                      opciones: const ['SIN CORRALÓN / N/A'],
                      icono: Icons.warehouse_outlined,
                    ),

                    const SizedBox(height: 10),

                    _selectManualDemo(
                      titulo: 'Aseguradora (opcional)',
                      valor: 'Qualitas',
                      seleccionado: aseguradoraLista,
                      mostrarMenu: abrirAseguradora,
                      opciones: const [
                        'Ninguna',
                        'Qualitas',
                        'GNP',
                        'AXA',
                        'Banorte',
                        'HDI',
                        'Mapfre',
                        'Zurich',
                        'BBVA',
                        'Afirme',
                        'Inbursa',
                        'Chubb',
                        'Potosí',
                        'General de Seguros',
                      ],
                      icono: Icons.shield_outlined,
                    ),

                    const SizedBox(height: 10),

                    _campoManualDemo(
                      titulo: 'Monto daños *',
                      valor: '5000',
                      mostrar: montoListo,
                      icono: Icons.attach_money,
                    ),

                    const SizedBox(height: 10),

                    _campoManualDemo(
                      titulo: 'Partes dañadas *',
                      valor: 'Parte frontal, defensa y faro derecho',
                      mostrar: partesListas,
                      icono: Icons.car_crash_outlined,
                    ),

                    const SizedBox(height: 14),

                    AnimatedContainer(
                      duration: const Duration(milliseconds: 450),
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: antecedentesRevisados
                            ? Colors.orange.withValues(alpha: 0.16)
                            : Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.playlist_add_check_circle_outlined,
                            color: Colors.deepOrange,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Antecedente del vehículo',
                                  style: TextStyle(
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Confirma si ya se revisaron antecedentes.',
                                  style: TextStyle(
                                    color: Colors.deepOrange,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: antecedentesRevisados
                                ? const Icon(
                                    Icons.toggle_on,
                                    key: ValueKey('antecedentes-si'),
                                    color: Colors.deepOrange,
                                    size: 42,
                                  )
                                : const Icon(
                                    Icons.toggle_off,
                                    key: ValueKey('antecedentes-no'),
                                    color: Colors.grey,
                                    size: 42,
                                  ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    AnimatedContainer(
                      duration: const Duration(milliseconds: 450),
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.shade400),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.car_crash, color: Colors.red),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '¿Este vehículo tiene reporte de robo?',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'Selecciona Sí únicamente cuando el reporte esté confirmado.',
                            style: TextStyle(fontSize: 12, height: 1.35),
                          ),

                          const SizedBox(height: 10),

                          _selectManualDemo(
                            titulo: 'Reporte de robo *',
                            valor: 'No',
                            seleccionado: reporteRoboListo,
                            mostrarMenu:
                                antecedentesRevisados && !reporteRoboListo,
                            opciones: const ['No', 'Sí'],
                            icono: Icons.gpp_maybe_outlined,
                            deshabilitado: !antecedentesRevisados,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Container(
                        key: ValueKey(
                          '$gruaLista-$corralonListo-$aseguradoraLista-$montoListo-$partesListas-$antecedentesRevisados-$reporteRoboListo',
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
                          !gruaLista
                              ? 'Selecciona la grúa utilizada, si aplica.'
                              : !corralonListo
                              ? 'Indica el corralón correspondiente.'
                              : !aseguradoraLista
                              ? 'Selecciona la aseguradora o Ninguna.'
                              : !montoListo
                              ? 'Captura el monto estimado de los daños.'
                              : !partesListas
                              ? 'Describe las partes dañadas.'
                              : !antecedentesRevisados
                              ? 'Confirma que se revisaron los antecedentes del vehículo.'
                              : !reporteRoboListo
                              ? 'Indica si existe o no reporte de robo confirmado.'
                              : 'Información del vehículo completada.',
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
                icon: Icons.local_shipping_outlined,
                titulo: 'Grúa',
                texto:
                    'El listado muestra únicamente las empresas de grúas autorizadas por la Subdirección. Entre ellas pueden aparecer Danny\'s, Galván, Muñoz y Serví-Grúas Profesionales. Si falta alguna empresa autorizada, comunícate con la oficina para solicitar que sea agregada al catálogo.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.warehouse_outlined,
                titulo: 'Corralón',
                texto:
                    'Selecciona el corralón al que fue trasladado el vehículo. Si no hubo ingreso a corralón, utiliza la opción correspondiente a SIN CORRALÓN / N/A.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.shield_outlined,
                titulo: 'Aseguradora',
                texto:
                    'Selecciona la aseguradora que corresponda al vehículo. Si no cuenta con seguro o no aplica, selecciona Ninguna.',
              ),

              const SizedBox(height: 12),

              _avisoAdvertencia(
                icon: Icons.attach_money,
                titulo: 'Monto de daños',
                texto:
                    'Captura únicamente números. No escribas símbolos, letras, comas ni formatos monetarios. Por ejemplo, si el monto es cinco mil pesos escribe 5000, no \$5,000.00.',
              ),

              const SizedBox(height: 12),

              _aviso(
                icon: Icons.car_crash_outlined,
                titulo: 'Partes dañadas',
                texto:
                    'Describe las partes afectadas del vehículo. Puede ser una descripción general, por ejemplo “parte frontal”, o puedes detallar las piezas dañadas, como defensa, cofre, faro, salpicadera u otras.',
              ),

              const SizedBox(height: 12),

              _avisoAdvertencia(
                icon: Icons.manage_search_outlined,
                titulo: 'Antecedentes del vehículo',
                texto:
                    'Activa este control únicamente después de haber realizado la consulta de antecedentes correspondiente a este vehículo en específico.',
              ),

              const SizedBox(height: 12),

              _avisoAdvertencia(
                icon: Icons.gpp_maybe_outlined,
                titulo: 'Reporte de robo',
                texto:
                    'Después de consultar los antecedentes, indica si el vehículo cuenta o no con reporte de robo. Selecciona Sí únicamente cuando el reporte esté confirmado; de lo contrario selecciona No.',
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
                        'Al terminar, revisa que todos los datos correspondan al vehículo correcto antes de pulsar “Guardar vehículo”.',
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

  Widget _selectManualDemo({
    required String titulo,
    required String valor,
    required bool seleccionado,
    required bool mostrarMenu,
    required List<String> opciones,
    required IconData icono,
    bool deshabilitado = false,
  }) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: deshabilitado
                ? Colors.grey.withValues(alpha: 0.05)
                : mostrarMenu
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
                color: deshabilitado
                    ? Colors.grey.shade400
                    : seleccionado
                    ? Colors.deepPurple
                    : Colors.grey.shade600,
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
                        color: deshabilitado
                            ? Colors.grey.shade400
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Text(
                        deshabilitado
                            ? '-- Selecciona el campo anterior primero --'
                            : seleccionado
                            ? valor
                            : '-- Seleccione --',
                        key: ValueKey('$titulo-$seleccionado-$deshabilitado'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: seleccionado
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: deshabilitado
                              ? Colors.grey.shade400
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: deshabilitado ? Colors.grey.shade300 : Colors.grey,
              ),
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
            constraints: const BoxConstraints(maxHeight: 210),
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
            child: SingleChildScrollView(
              child: Column(
                children: opciones
                    .map(
                      (opcion) => Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        color: opcion == valor
                            ? Colors.deepPurple.withValues(alpha: 0.08)
                            : Colors.transparent,
                        child: Text(
                          opcion,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _campoManualDemo({
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
                  titulo,
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
            const Icon(Icons.edit, size: 18, color: Colors.deepPurple),
        ],
      ),
    );
  }

  Widget _camaraDemo({required double progreso, required bool qrDetectado}) {
    final posicionLinea = ((progreso * 5) % 1);

    return Container(
      width: double.infinity,
      height: 320,
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
            child: Row(
              children: [
                Icon(Icons.arrow_back, color: Colors.white),
                SizedBox(width: 14),
                Text(
                  'Escanear tarjeta',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 190,
              height: 190,
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
                        size: 115,
                        color: qrDetectado ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                  if (!qrDetectado)
                    Positioned(
                      left: 10,
                      right: 10,
                      top: 15 + (145 * posicionLinea),
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
            bottom: 18,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                qrDetectado
                    ? 'QR reconocido'
                    : 'Apunta al QR de la tarjeta de circulación',
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
