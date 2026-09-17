import 'dart:async';
import 'package:flutter/material.dart';

class FormularioHechoHelpSheet extends StatefulWidget {
  const FormularioHechoHelpSheet({super.key});

  @override
  State<FormularioHechoHelpSheet> createState() =>
      _FormularioHechoHelpSheetState();
}

class _FormularioHechoHelpSheetState extends State<FormularioHechoHelpSheet>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  int _pagina = 0;

  Timer? _demoTimer;
  int _demoDatosFase = 0;
  int _demoLugarFase = 0;
  int _demoCaracteristicasFase = 0;
  int _demoCierreFase = 0;

  static const int _totalPaginas = 7;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _demoTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;

      setState(() {
        _demoDatosFase = (_demoDatosFase + 1) % 3;
        _demoLugarFase = (_demoLugarFase + 1) % 2;
        _demoCaracteristicasFase = (_demoCaracteristicasFase + 1) % 7;
        _demoCierreFase = (_demoCierreFase + 1) % 8;
      });
    });
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _pageController.dispose();
    _pulseController.dispose();
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
                const Icon(Icons.assignment_outlined, color: Colors.blue),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cómo llenar el formulario',
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
                _pasoUbicacion(),
                _pasoDanosPatrimoniales(),
                _pasoFotografias(),
                _pasoDatosIdentificacion(),
                _pasoLugarHecho(),
                _pasoCaracteristicasHecho(),
                _pasoCierreHecho(),
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

  Widget _pasoUbicacion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tituloPaso('1', 'Ubicación GPS'),
          const SizedBox(height: 8),
          const Text(
            'Lo primero es registrar las coordenadas exactas del lugar donde ocurrió el hecho de tránsito.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xfffaf5fb),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ubicación (GPS)',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  'Sin ubicación (revisa GPS/permisos)',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 58,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade600),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'Latitud',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 58,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade600),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'Longitud',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.my_location),
                      label: const Text('Obtener ubicación'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _aviso(
            icon: Icons.my_location,
            titulo: 'Obtener ubicación',
            texto:
                'Pulsa el botón “Obtener ubicación”. La aplicación llenará automáticamente la latitud y longitud del lugar.',
          ),
          const SizedBox(height: 12),
          _aviso(
            icon: Icons.signal_cellular_alt,
            titulo: 'No necesitas datos móviles',
            texto:
                'La obtención de coordenadas funciona aun cuando no tengas conexión a internet. El GPS del dispositivo puede obtener la posición sin utilizar datos móviles.',
          ),
          const SizedBox(height: 12),
          _avisoAdvertencia(
            icon: Icons.signal_cellular_connected_no_internet_4_bar,
            titulo: 'Si tu conexión está muy lenta',
            texto:
                'Una conexión de datos muy lenta puede hacer que el proceso tarde. En ese caso, activa el modo avión o desactiva temporalmente los datos móviles y vuelve a pulsar “Obtener ubicación”.',
          ),
          const SizedBox(height: 12),
          _aviso(
            icon: Icons.edit_location_alt_outlined,
            titulo: 'También puedes escribirlas',
            texto:
                'Si ya conoces las coordenadas exactas, puedes escribir manualmente la latitud y longitud en sus respectivos campos.',
          ),
        ],
      ),
    );
  }

  Widget _pasoDanosPatrimoniales() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tituloPaso('2', 'Daños patrimoniales'),
          const SizedBox(height: 8),
          const Text(
            'Indica si además de los vehículos involucrados existieron daños a algún bien o propiedad.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xfffaf5fb),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daños patrimoniales',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '¿Hubo daños patrimoniales?',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Switch(value: true, onChanged: (_) {}),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade600),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'Propiedades afectadas',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade600),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'Monto daños patrimoniales',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _aviso(
            icon: Icons.toggle_on_outlined,
            titulo: 'Si no hubo daños',
            texto: 'Deja el interruptor apagado y continúa con el formulario.',
          ),
          const SizedBox(height: 12),
          _aviso(
            icon: Icons.home_work_outlined,
            titulo: 'Si sí hubo daños',
            texto:
                'Activa el interruptor. Se mostrarán los campos para indicar qué propiedad resultó afectada y el monto estimado de los daños.',
          ),
          const SizedBox(height: 12),
          _aviso(
            icon: Icons.edit_note_outlined,
            titulo: 'Propiedad afectada',
            texto:
                'Describe qué bien fue dañado, por ejemplo: poste, semáforo, señalamiento, barda, inmueble, mobiliario urbano u otra propiedad.',
          ),
          const SizedBox(height: 12),
          _aviso(
            icon: Icons.attach_money,
            titulo: 'Monto del daño',
            texto:
                'Captura el monto estimado en dinero cuando cuentes con esa información.',
          ),
        ],
      ),
    );
  }

  Widget _pasoFotografias() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tituloPaso('3', 'Fotografías'),
          const SizedBox(height: 8),

          const Text(
            'En esta parte se pueden cargar tres fotografías. Foto 1 y Foto 2 corresponden al hecho de tránsito. La Foto de la situación se utiliza para documentar el convenio o, cuando el hecho sea TURNADO, la puesta a disposición.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),

          const SizedBox(height: 20),

          _fotoTipo(
            icono: Icons.photo_camera_outlined,
            titulo: 'Foto 1 del hecho',
            descripcion: 'Fotografía panorámica de la escena del siniestro.',
          ),

          const SizedBox(height: 12),

          _fotoTipo(
            icono: Icons.photo_camera_outlined,
            titulo: 'Foto 2 del hecho',
            descripcion:
                'Segunda fotografía panorámica desde otro ángulo que permita observar mejor la situación.',
          ),

          const SizedBox(height: 12),

          _fotoTipo(
            icono: Icons.description_outlined,
            titulo: 'Foto de la situación (opcional)',
            descripcion:
                'Puede utilizarse para adjuntar el convenio. Si la situación del hecho es TURNADO, debe adjuntarse la puesta a disposición.',
          ),

          const SizedBox(height: 22),

          Container(
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
                const Row(
                  children: [
                    Icon(Icons.panorama_horizontal_select, color: Colors.blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Foto 1 y Foto 2 del hecho',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                const Text(
                  'Deben ser fotografías panorámicas y abiertas de toda la escena. Deben permitir observar los vehículos, las condiciones del lugar y, cuando sea posible, la patrulla realizando el abanderamiento.',
                  style: TextStyle(height: 1.4),
                ),

                const SizedBox(height: 14),

                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/ayuda/foto_siniestro_ejemplo.jpg',
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Ejemplo de fotografía panorámica del hecho',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
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
                const Row(
                  children: [
                    Icon(Icons.description_outlined, color: Colors.blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Foto de la situación',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                const Text(
                  'Este campo es opcional, excepto cuando la situación del hecho sea TURNADO. Puede utilizarse para registrar el convenio realizado entre las partes.',
                  style: TextStyle(height: 1.4),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Ejemplo de convenio',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 8),

                Container(
                  width: double.infinity,
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/ayuda/convenio_ejemplo.jpg',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Si la situación es TURNADO',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 6),

                const Text(
                  'La Foto de la situación deja de ser opcional y debe corresponder al documento de puesta a disposición.',
                  style: TextStyle(height: 1.4),
                ),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/ayuda/puesta_disposicion_ejemplo.jpg',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Ejemplo de puesta a disposición',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.crop, color: Colors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Formato panorámico',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                const Text(
                  'Las fotografías deben tomarse en formato horizontal o panorámico. Si seleccionas una imagen que no tiene el formato requerido, la aplicación abrirá automáticamente la herramienta de recorte.',
                  style: TextStyle(height: 1.4),
                ),

                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  height: 330,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/ayuda/recorte_foto_ejemplo.jpeg',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Ajusta el recuadro y pulsa “Usar recorte”.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _aviso(
            icon: Icons.screen_rotation_alt_outlined,
            titulo: 'Toma las fotografías en horizontal',
            texto:
                'Las imágenes son revisadas posteriormente y se requieren en formato panorámico. Lo recomendable es tomar todas las fotografías con el teléfono en posición horizontal desde el principio.',
          ),
        ],
      ),
    );
  }

  //Nuevo

  Widget _pasoDatosIdentificacion() {
    final bool mostrarLleno = _demoDatosFase == 1;
    final bool mostrarSector = _demoDatosFase == 2;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tituloPaso('4', 'Datos de identificación del hecho'),
          const SizedBox(height: 8),
          const Text(
            'En esta sección se registran los datos básicos que identifican la atención y al personal que realiza la captura.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),

          Container(
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
                const SizedBox(height: 12),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  child: ClipRRect(
                    key: ValueKey(_demoDatosFase),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: Colors.white,
                      child: Image.asset(
                        mostrarLleno || mostrarSector
                            ? 'assets/ayuda/datos_identificacion_lleno.png'
                            : 'assets/ayuda/datos_identificacion_vacio.png',
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: mostrarSector
                        ? Colors.deepPurple.withValues(alpha: 0.10)
                        : Colors.green.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    mostrarSector
                        ? 'Ahora se muestra el selector de Sector para Morelia.'
                        : mostrarLleno
                        ? 'Ejemplo con los campos ya capturados.'
                        : 'Vista inicial del bloque de identificación.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: mostrarSector
                          ? Colors.deepPurple
                          : Colors.green.shade700,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 450),
                  crossFadeState: mostrarSector
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selector de Sector',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          color: Colors.white,
                          child: Image.asset(
                            'assets/ayuda/sector_morelia_ejemplo.png',
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
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
            icon: Icons.confirmation_number_outlined,
            titulo: 'Folio C5i',
            texto:
                'Es opcional. Si no cuentas con un folio C5i, deja el campo vacío. No inventes uno. Si sí cuentas con él, asegúrate de capturarlo correctamente porque es un dato único y no debe repetirse en dos hechos distintos.',
          ),

          const SizedBox(height: 12),

          _aviso(
            icon: Icons.badge_outlined,
            titulo: 'Agente, autorización y unidad',
            texto:
                'Registra el nombre del elemento que realiza la atención y la unidad correspondiente. La autorización de práctico se captura cuando aplique.',
          ),

          const SizedBox(height: 12),

          _aviso(
            icon: Icons.schedule,
            titulo: 'Hora y fecha',
            texto:
                'Estos campos se asignan automáticamente y permanecen bloqueados. La aplicación utiliza la hora y fecha actual del sistema para mantener correctamente los cortes de información; no toma como referencia la hora configurada manualmente en el dispositivo.',
          ),

          const SizedBox(height: 12),

          _aviso(
            icon: Icons.map_outlined,
            titulo: 'Sector',
            texto:
                'El sector se selecciona de una lista y únicamente aplica para hechos registrados en Morelia. Fuera de Morelia este campo no aparece.',
          ),
        ],
      ),
    );
  }

  Widget _pasoLugarHecho() {
    final bool mostrarLleno = _demoLugarFase == 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tituloPaso('5', 'Lugar del hecho'),
          const SizedBox(height: 8),
          const Text(
            'Estos campos identifican el punto donde ocurrió el siniestro.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),

          Container(
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
                const Row(
                  children: [
                    Icon(Icons.place_outlined, color: Colors.blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ejemplo de autocompletado',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  child: ClipRRect(
                    key: ValueKey(_demoLugarFase),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: Colors.white,
                      child: Image.asset(
                        mostrarLleno
                            ? 'assets/ayuda/lugar_hecho_lleno.png'
                            : 'assets/ayuda/lugar_hecho_vacio.png',
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: mostrarLleno
                        ? Colors.green.withValues(alpha: 0.10)
                        : Colors.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    mostrarLleno
                        ? 'Ejemplo con los campos llenados automáticamente.'
                        : 'Vista inicial de Lugar, Colonia, Entre calles y Municipio.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: mostrarLleno
                          ? Colors.green.shade700
                          : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          _aviso(
            icon: Icons.my_location,
            titulo: 'Si utilizaste “Obtener ubicación”',
            texto:
                'La aplicación intentará completar automáticamente Lugar, Colonia, Entre calles y Municipio con base en las coordenadas obtenidas al inicio de la captura.',
          ),

          const SizedBox(height: 12),

          _avisoAdvertencia(
            icon: Icons.fact_check_outlined,
            titulo: 'Verifica los datos',
            texto:
                'Aunque los campos se completen automáticamente, revisa que correspondan al lugar real del hecho antes de continuar.',
          ),

          const SizedBox(height: 12),

          _aviso(
            icon: Icons.edit_location_alt_outlined,
            titulo: 'Si no utilizaste la ubicación',
            texto:
                'Si no se obtuvieron coordenadas al inicio, deberás capturar manualmente el lugar, colonia, entre calles y municipio.',
          ),
        ],
      ),
    );
  }

  Widget _pasoCaracteristicasHecho() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tituloPaso('6', 'Características del hecho'),
          const SizedBox(height: 8),

          const Text(
            'Todos los campos de esta sección son obligatorios. Selecciona la opción que corresponda a las condiciones observadas durante la atención del siniestro.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),

          const SizedBox(height: 20),

          Container(
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

                _selectDemo(
                  titulo: 'Tipo Hecho *',
                  valor: 'COLISIÓN POR ALCANCE',
                  mostrar: _demoCaracteristicasFase >= 1,
                ),

                const SizedBox(height: 10),

                _selectDemo(
                  titulo: 'Superficie vía *',
                  valor: 'Asfalto',
                  mostrar: _demoCaracteristicasFase >= 2,
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _selectDemo(
                        titulo: 'Tiempo *',
                        valor: 'Día',
                        mostrar: _demoCaracteristicasFase >= 3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _selectDemo(
                        titulo: 'Clima *',
                        valor: 'Bueno',
                        mostrar: _demoCaracteristicasFase >= 3,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                _selectDemo(
                  titulo: 'Condiciones *',
                  valor: 'Bueno',
                  mostrar: _demoCaracteristicasFase >= 4,
                ),

                const SizedBox(height: 10),

                _selectDemo(
                  titulo: 'Control tránsito *',
                  valor: 'Marca vial',
                  mostrar: _demoCaracteristicasFase >= 5,
                ),

                const SizedBox(height: 12),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _demoCaracteristicasFase >= 6
                        ? Colors.orange.withValues(alpha: 0.16)
                        : Colors.orange.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.checklist, color: Colors.orange),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¿Se checaron antecedentes?',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.deepOrange,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Confirma si ya se revisaron antecedentes.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _demoCaracteristicasFase >= 6
                            ? const Icon(
                                Icons.check_box,
                                key: ValueKey('checked'),
                                color: Colors.deepOrange,
                                size: 28,
                              )
                            : const Icon(
                                Icons.check_box_outline_blank,
                                key: ValueKey('unchecked'),
                                size: 28,
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _demoCaracteristicasFase == 0
                        ? 'Los campos comienzan sin seleccionar.'
                        : _demoCaracteristicasFase == 1
                        ? 'Primero se selecciona el tipo de hecho.'
                        : _demoCaracteristicasFase == 2
                        ? 'Después se indica la superficie de la vía.'
                        : _demoCaracteristicasFase == 3
                        ? 'Se registran el tiempo y el clima.'
                        : _demoCaracteristicasFase == 4
                        ? 'Se indican las condiciones de la vía.'
                        : _demoCaracteristicasFase == 5
                        ? 'Se selecciona el control de tránsito existente.'
                        : 'Finalmente se confirma si fueron revisados los antecedentes.',
                    key: ValueKey(_demoCaracteristicasFase),
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          _aviso(
            icon: Icons.car_crash_outlined,
            titulo: 'Tipo de hecho',
            texto:
                'Selecciona la modalidad que corresponda al evento atendido, por ejemplo: colisión por alcance, volcadura, caída de motocicleta, colisión con peatón u otra de las opciones disponibles.',
          ),

          const SizedBox(height: 12),

          _aviso(
            icon: Icons.add_road,
            titulo: 'Superficie de la vía',
            texto:
                'Selecciona el material de la superficie donde ocurrió el hecho: asfalto, concreto, adoquín, terracería, empedrado, grava u otra opción disponible.',
          ),

          const SizedBox(height: 12),

          _aviso(
            icon: Icons.wb_sunny_outlined,
            titulo: 'Tiempo y clima',
            texto:
                'Tiempo identifica el momento del día, como Día, Noche, Amanecer o Atardecer. Clima registra las condiciones meteorológicas observadas durante la atención.',
          ),

          const SizedBox(height: 12),

          _aviso(
            icon: Icons.route_outlined,
            titulo: 'Condiciones',
            texto:
                'Selecciona el estado de las condiciones observadas en la vía. Registra lo que realmente encuentres en el lugar.',
          ),

          const SizedBox(height: 12),

          _aviso(
            icon: Icons.traffic_outlined,
            titulo: 'Control de tránsito',
            texto:
                'Indica qué elemento de control existe en el lugar, por ejemplo semáforo, señalamiento vertical, marca vial, agente de tránsito, reductor de velocidad, glorieta o ninguno.',
          ),

          const SizedBox(height: 12),

          _avisoAdvertencia(
            icon: Icons.manage_search_outlined,
            titulo: 'Antecedentes',
            texto:
                'Marca la casilla únicamente cuando realmente se hayan revisado los antecedentes correspondientes.',
          ),
        ],
      ),
    );
  }

  Widget _pasoCierreHecho() {
    final bool causaLista = _demoCierreFase >= 1;
    final bool responsableListo = _demoCierreFase >= 2;
    final bool colisionLista = _demoCierreFase >= 3;

    String situacion = 'Situación *';

    if (_demoCierreFase == 4) {
      situacion = 'PENDIENTE';
    } else if (_demoCierreFase == 5) {
      situacion = 'RESUELTO';
    } else if (_demoCierreFase == 6) {
      situacion = 'TURNADO';
    } else if (_demoCierreFase >= 7) {
      situacion = 'REPORTE';
    }

    final bool mostrarSituacion = _demoCierreFase >= 4;
    final bool esPendiente = situacion == 'PENDIENTE';
    final bool esResuelto = situacion == 'RESUELTO';
    final bool esTurnado = situacion == 'TURNADO';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tituloPaso('7', 'Causa, responsable y situación'),
          const SizedBox(height: 8),

          const Text(
            'Esta es la parte final de la creación del hecho. Completa la causa, identifica al responsable, señala contra qué ocurrió la colisión y define la situación en la que queda la atención.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),

          const SizedBox(height: 20),

          Container(
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
                const Row(
                  children: [
                    Icon(Icons.task_alt_outlined, color: Colors.blue),
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

                _selectDemo(
                  titulo: 'Causas *',
                  valor: 'No conservar distancia',
                  mostrar: causaLista,
                ),

                const SizedBox(height: 10),

                _selectDemo(
                  titulo: 'Responsable *',
                  valor: 'Vehículo A',
                  mostrar: responsableListo,
                ),

                const SizedBox(height: 10),

                _selectDemo(
                  titulo: 'Colisión camino *',
                  valor: 'Vehículos',
                  mostrar: colisionLista,
                ),

                const SizedBox(height: 10),

                _selectDemo(
                  titulo: 'Situación *',
                  valor: situacion,
                  mostrar: mostrarSituacion,
                ),

                const SizedBox(height: 14),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: !mostrarSituacion
                      ? const SizedBox.shrink()
                      : Container(
                          key: ValueKey(situacion),
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: esTurnado
                                ? Colors.orange.withValues(alpha: 0.10)
                                : esResuelto
                                ? Colors.green.withValues(alpha: 0.10)
                                : Colors.blue.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                esTurnado
                                    ? Icons.account_balance_outlined
                                    : esResuelto
                                    ? Icons.handshake_outlined
                                    : esPendiente
                                    ? Icons.hourglass_bottom
                                    : Icons.description_outlined,
                                color: esTurnado
                                    ? Colors.orange.shade800
                                    : esResuelto
                                    ? Colors.green.shade700
                                    : Colors.blue.shade700,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  esPendiente
                                      ? 'Las partes todavía se encuentran intentando llegar a un acuerdo respecto de los daños.'
                                      : esResuelto
                                      ? 'Las partes llegaron a un acuerdo. La Foto de la situación se vuelve obligatoria y debe corresponder al convenio.'
                                      : esTurnado
                                      ? 'El hecho será puesto a disposición. La Foto de la situación se vuelve obligatoria y debe corresponder a la puesta a disposición.'
                                      : 'Se registran los datos del hecho, pero no se realiza una atención completa del siniestro.',
                                  style: const TextStyle(
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),

                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 450),
                  crossFadeState: esTurnado
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Información adicional para TURNADO',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 12),

                        _selectDemo(
                          titulo: 'Dictamen *',
                          valor: '105/2026 MIRIAM HILARIO HILARIO',
                          mostrar: true,
                        ),

                        const SizedBox(height: 6),

                        Text(
                          'En Morelia se selecciona el dictamen de tránsito correspondiente para vincularlo con el hecho.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 62,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.deepPurple),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Vehículos MP *',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '1',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Container(
                                height: 62,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Personas MP *',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '0',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
            icon: Icons.rule_outlined,
            titulo: 'Causa',
            texto:
                'Selecciona la causa que corresponda al análisis del hecho, por ejemplo: no conservar distancia, invasión de carril, corte de circulación, exceso de velocidad, falla mecánica u otra opción disponible.',
          ),

          const SizedBox(height: 12),

          _aviso(
            icon: Icons.directions_car_outlined,
            titulo: 'Responsable',
            texto:
                'Selecciona el vehículo identificado como responsable dentro de la captura: Vehículo A, B, C, D, E o F, según corresponda.',
          ),

          const SizedBox(height: 12),

          _aviso(
            icon: Icons.route_outlined,
            titulo: 'Colisión camino',
            texto:
                'Indica con qué elemento ocurrió la colisión: vehículos, semovientes, objeto fijo, peatón, bicicleta u otra opción disponible.',
          ),

          const SizedBox(height: 12),

          _aviso(
            icon: Icons.hourglass_bottom,
            titulo: 'PENDIENTE',
            texto:
                'Utilízalo cuando la atención todavía no se encuentra concluida porque las partes involucradas continúan intentando llegar a un acuerdo respecto de los daños.',
          ),

          const SizedBox(height: 12),

          _aviso(
            icon: Icons.handshake_outlined,
            titulo: 'RESUELTO',
            texto:
                'Indica que las partes llegaron a un acuerdo. En este caso la Foto de la situación es obligatoria y debe mostrar el convenio.',
          ),

          const SizedBox(height: 12),

          _avisoAdvertencia(
            icon: Icons.account_balance_outlined,
            titulo: 'TURNADO',
            texto:
                'Indica que el hecho será puesto a disposición. La Foto de la situación es obligatoria y debe corresponder a la puesta a disposición. Al seleccionar TURNADO aparecen campos adicionales.',
          ),

          const SizedBox(height: 12),

          _aviso(
            icon: Icons.description_outlined,
            titulo: 'REPORTE',
            texto:
                'Utilízalo cuando únicamente se realiza el registro de datos del hecho y no se lleva a cabo una atención completa del siniestro.',
          ),

          const SizedBox(height: 12),

          _aviso(
            icon: Icons.assignment_outlined,
            titulo: 'Dictamen en hechos TURNADOS',
            texto:
                'Si el hecho ocurrió en Morelia, selecciona el dictamen de tránsito correspondiente para vincularlo directamente. En delegaciones fuera de Morelia, la vinculación del dictamen se realiza por fuera de este selector.',
          ),

          const SizedBox(height: 12),

          _avisoAdvertencia(
            icon: Icons.warning_amber_rounded,
            titulo: 'Vehículos MP y Personas MP',
            texto:
                'Ambos campos no pueden quedar en 0. Si el hecho está TURNADO debe existir al menos un vehículo o una persona puesta a disposición. Captura 1, 2 o la cantidad que corresponda en al menos uno de los dos campos.',
          ),

          const SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Después de revisar esta información, pulsa “Registrar Hecho” para terminar la creación inicial.',
                    style: TextStyle(height: 1.4, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectDemo({
    required String titulo,
    required String valor,
    required bool mostrar,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: mostrar
            ? Colors.deepPurple.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: mostrar ? Colors.deepPurple : Colors.grey.shade500,
          width: mostrar ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Text(
                mostrar ? valor : titulo,
                key: ValueKey('$titulo-$mostrar'),
                style: TextStyle(
                  fontSize: 16,
                  color: mostrar ? Colors.black87 : Colors.grey.shade700,
                  fontWeight: mostrar ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _fotoTipo({
    required IconData icono,
    required String titulo,
    required String descripcion,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfffaf5fb),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.deepPurple.withValues(alpha: 0.10),
            child: Icon(icono, color: Colors.deepPurple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(descripcion, style: const TextStyle(height: 1.4)),
              ],
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
