import 'package:flutter/material.dart';

class ConduceLegalidadShareTotalsHelpSheet extends StatefulWidget {
  const ConduceLegalidadShareTotalsHelpSheet({super.key});

  @override
  State<ConduceLegalidadShareTotalsHelpSheet> createState() =>
      _ConduceLegalidadShareTotalsHelpSheetState();
}

class _ConduceLegalidadShareTotalsHelpSheetState
    extends State<ConduceLegalidadShareTotalsHelpSheet>
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
                const Icon(Icons.share_outlined, color: Colors.green),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cómo compartir totales',
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
                _pasoUbicarBoton(),
                _pasoAbrirWhatsApp(),
                _pasoSeleccionarContacto(),
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

  Widget _pasoUbicarBoton() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;
        final resaltarShare = progreso >= 0.22 && progreso < 0.58;
        final mensajeVisible = progreso >= 0.58;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('1', 'Pulsa el botón de compartir'),
              const SizedBox(height: 8),
              const Text(
                'En la tarjeta del operativo, pulsa el icono de compartir que aparece del lado derecho.',
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
                        Icon(Icons.touch_app_outlined, color: Colors.blue),
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
                    Container(
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
                            backgroundColor: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.12),
                            child: const Icon(
                              Icons.fact_check_outlined,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Periférico Independencia 5000',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '2026-09-21  |  MORELIA  |  Sentimientos de la Nación  |  CP 58178  |  0 capturas  |  ACTIVO',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.35,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              AnimatedScale(
                                duration: const Duration(milliseconds: 350),
                                scale: resaltarShare ? 1.14 : 1,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 350),
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: resaltarShare
                                        ? Colors.green.withValues(alpha: 0.12)
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: resaltarShare
                                          ? Colors.green
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                    boxShadow: resaltarShare
                                        ? [
                                            BoxShadow(
                                              color: Colors.green.withValues(
                                                alpha: 0.18,
                                              ),
                                              blurRadius: 14,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: const Icon(
                                    Icons.share_outlined,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Icon(Icons.more_vert),
                            ],
                          ),
                        ],
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
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.20),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Pulsa este icono para compartir los totales del operativo.',
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
                icon: Icons.share_outlined,
                titulo: 'Sólo un toque',
                texto:
                    'No necesitas entrar al operativo. Desde el listado puedes compartir directamente sus totales.',
              ),
              const SizedBox(height: 12),
              _avisoAdvertencia(
                icon: Icons.visibility_outlined,
                titulo: 'Si no aparece el icono',
                texto:
                    'El botón de compartir puede mostrarse sólo a los perfiles que tienen acceso a la vista total del operativo.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pasoAbrirWhatsApp() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;

        final preparando = progreso >= 0.16 && progreso < 0.42;
        final abriendo = progreso >= 0.42 && progreso < 0.62;
        final abierto = progreso >= 0.62;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('2', 'Se abre WhatsApp'),
              const SizedBox(height: 8),
              const Text(
                'Después de pulsar compartir, el sistema prepara el resumen y abre WhatsApp para continuar el envío.',
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
                        Icon(Icons.open_in_new_outlined, color: Colors.blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Apertura automática',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: !abierto
                          ? Container(
                              key: ValueKey('$preparando-$abriendo'),
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    child: preparando || abriendo
                                        ? const SizedBox(
                                            key: ValueKey('loading'),
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.share_outlined,
                                            key: ValueKey('share'),
                                            size: 30,
                                            color: Colors.green,
                                          ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    preparando
                                        ? 'Preparando resumen del operativo...'
                                        : abriendo
                                        ? 'Abriendo WhatsApp...'
                                        : 'Listo para compartir',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    preparando || abriendo
                                        ? 'Espera unos segundos mientras se genera el mensaje.'
                                        : 'Pulsa compartir para iniciar.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              key: const ValueKey('whatsapp'),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF25D366),
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(18),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.message_outlined,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'WhatsApp',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.open_in_new,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F8F4),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFB7E4C7),
                                        ),
                                      ),
                                      child: const Text(
                                        'GUARDIA CIVIL\nCOORDINACIÓN DEL AGRUPAMIENTO DE SEGURIDAD VIAL\n\nResumen del operativo:\n• Vehículos revisados\n• Fundamentos aplicados\n• Totales acumulados',
                                        style: TextStyle(
                                          height: 1.35,
                                          fontSize: 14,
                                        ),
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
                icon: Icons.phone_android_outlined,
                titulo: 'Se abre WhatsApp automáticamente',
                texto:
                    'Después de pulsar compartir, WhatsApp se abrirá con el mensaje del resumen ya preparado.',
              ),
              const SizedBox(height: 12),
              _aviso(
                icon: Icons.description_outlined,
                titulo: 'El texto ya va listo',
                texto:
                    'No tienes que redactar el resumen manualmente; el sistema genera el contenido para compartirlo.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pasoSeleccionarContacto() {
    return AnimatedBuilder(
      animation: _demoController,
      builder: (context, _) {
        final progreso = _demoController.value;

        final resaltarContacto = progreso >= 0.18 && progreso < 0.52;
        final botonEnviar = progreso >= 0.52 && progreso < 0.76;
        final completado = progreso >= 0.76;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tituloPaso('3', 'Selecciona el contacto'),
              const SizedBox(height: 8),
              const Text(
                'Dentro de WhatsApp, sólo selecciona el contacto o grupo al que deseas enviar el resumen.',
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
                        Icon(Icons.contacts_outlined, color: Colors.blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Envío en WhatsApp',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFF25D366),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.person_search_outlined,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Seleccionar contacto',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _contactoDemo(
                            nombre: 'Grupo Coordinación',
                            subtitulo: 'Resumen operativo',
                            seleccionado: resaltarContacto,
                          ),
                          _contactoDemo(
                            nombre: 'Rosiles Soberanis',
                            subtitulo: 'Última vez hoy',
                            seleccionado: false,
                          ),
                          _contactoDemo(
                            nombre: 'Subdirección Siniestros',
                            subtitulo: 'Última vez ayer',
                            seleccionado: false,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 350),
                              scale: botonEnviar ? 1.04 : 1,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                width: double.infinity,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: completado
                                      ? Colors.green.withValues(alpha: 0.12)
                                      : const Color(0xFF25D366),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: botonEnviar
                                      ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF25D366,
                                            ).withValues(alpha: 0.28),
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
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      child: completado
                                          ? const Icon(
                                              Icons.check_circle_outline,
                                              key: ValueKey('done'),
                                              color: Colors.green,
                                            )
                                          : const Icon(
                                              Icons.send_outlined,
                                              key: ValueKey('send'),
                                              color: Colors.white,
                                            ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      completado ? 'Mensaje listo' : 'Enviar',
                                      style: TextStyle(
                                        color: completado
                                            ? Colors.green.shade800
                                            : Colors.white,
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
                    ),
                    const SizedBox(height: 14),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 350),
                      crossFadeState: completado
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
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.20),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Selecciona el contacto y WhatsApp dejará listo el envío del resumen.',
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
                icon: Icons.group_outlined,
                titulo: 'Puedes enviarlo a un contacto o grupo',
                texto:
                    'Elige a quién deseas mandar el resumen y continúa normalmente dentro de WhatsApp.',
              ),
              const SizedBox(height: 12),
              _aviso(
                icon: Icons.check_circle_outline,
                titulo: 'Proceso simple',
                texto:
                    'La acción real es: tocar compartir, abrir WhatsApp y seleccionar el destinatario.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _contactoDemo({
    required String nombre,
    required String subtitulo,
    required bool seleccionado,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: seleccionado
            ? const Color(0xFF25D366).withValues(alpha: 0.10)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: seleccionado ? const Color(0xFF25D366) : Colors.grey.shade300,
          width: seleccionado ? 1.7 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: seleccionado
                ? const Color(0xFF25D366)
                : Colors.grey.shade300,
            child: Icon(
              Icons.person,
              color: seleccionado ? Colors.white : Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: seleccionado ? const Color(0xFF128C7E) : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
          if (seleccionado)
            const Icon(Icons.check_circle, color: Color(0xFF25D366)),
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
