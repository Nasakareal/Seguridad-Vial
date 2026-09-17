import 'package:flutter/material.dart';

class SiniestroHelpSheet extends StatefulWidget {
  const SiniestroHelpSheet({super.key});

  @override
  State<SiniestroHelpSheet> createState() => _SiniestroHelpSheetState();
}

class _SiniestroHelpSheetState extends State<SiniestroHelpSheet>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  int _pagina = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _siguiente() {
    if (_pagina >= 3) {
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
                const Icon(Icons.car_crash, color: Colors.blue),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cómo registrar un siniestro',
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
          const SizedBox(height: 6),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _pagina = index);
              },
              children: [
                _pasoBotonMas(),
                _pasoMenuInicial(),
                _pasoNuevoHecho(),
                _pasoCaptura(),
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
                  child: Text(_pagina == 3 ? 'Entendido' : 'Siguiente'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pasoBotonMas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tituloPaso('1', 'Inicia una nueva captura'),
          const SizedBox(height: 8),
          const Text(
            'Desde el listado de siniestros, busca el botón morado con el símbolo + ubicado en la esquina inferior derecha.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),
          Container(
            height: 390,
            decoration: BoxDecoration(
              color: const Color(0xfff8f5fb),
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
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: const Row(
                        children: [
                          Icon(Icons.menu),
                          SizedBox(width: 18),
                          Text('Siniestros', style: TextStyle(fontSize: 20)),
                          Spacer(),
                          Icon(Icons.search),
                          SizedBox(width: 14),
                          Icon(Icons.calendar_month),
                          SizedBox(width: 14),
                          Icon(Icons.refresh),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mostrando hechos del día',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text('Estado: Todos'),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xfffaf4fb),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Folio: MOR2026...',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 10),
                            Text('Ubicación: Morelia'),
                            Text('Situación: PENDIENTE'),
                            Text('Perito: ...'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: 18,
                  bottom: 18,
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: const Color(0xffeadcff),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.deepPurple,
                        size: 34,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 92,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) {
                      return Opacity(
                        opacity: 0.65 + (_pulseController.value * 0.35),
                        child: const Text(
                          'Toca aquí',
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
        ],
      ),
    );
  }

  Widget _pasoMenuInicial() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tituloPaso('2', 'La aplicación revisa si dejaste algo pendiente'),
          const SizedBox(height: 8),
          const Text(
            'Al presionar + puede aparecer esta ventana. Aquí debes indicar si vas a continuar una captura anterior o registrar un evento diferente.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xffedf3ff),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Continuar una captura anterior?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Continúa solo si es el mismo evento que dejaste sin terminar.',
                  style: TextStyle(fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Si ya lo guardaste sin conexión, puede estar pendiente de subir automáticamente. No debes capturarlo otra vez.',
                  style: TextStyle(fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Empezar una nueva captura descarta únicamente el borrador local que no terminaste.',
                  style: TextStyle(fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Continuar captura anterior',
                      style: TextStyle(
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                      onPressed: () {},
                      child: const Text('Nuevo hecho'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _aviso(
            icon: Icons.history,
            titulo: 'Continuar captura anterior',
            texto:
                'Úsalo únicamente cuando sea el mismo siniestro que estabas capturando y todavía no terminaste.',
          ),
          const SizedBox(height: 12),
          _aviso(
            icon: Icons.add_circle_outline,
            titulo: 'Nuevo hecho',
            texto:
                'Úsalo cuando vas a registrar un siniestro diferente. Este será el botón que normalmente debes seleccionar para una atención nueva.',
          ),
        ],
      ),
    );
  }

  Widget _pasoNuevoHecho() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tituloPaso('3', 'Selecciona “Nuevo hecho”'),
          const SizedBox(height: 8),
          const Text(
            'Si acabas de llegar a un siniestro y vas a iniciar su registro desde cero, selecciona Nuevo hecho.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 24),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 240,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: 18,
                    ),
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Nuevo hecho',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _aviso(
            icon: Icons.warning_amber_rounded,
            titulo: 'No dupliques siniestros',
            texto:
                'Si el mismo hecho ya fue guardado y está pendiente de sincronizarse, no debes volver a capturarlo.',
          ),
          const SizedBox(height: 12),
          _aviso(
            icon: Icons.delete_outline,
            titulo: 'Borrador anterior',
            texto:
                'Al iniciar un nuevo hecho se descarta el borrador local anterior que no habías terminado.',
          ),
        ],
      ),
    );
  }

  Widget _pasoCaptura() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tituloPaso('4', 'Comienza la captura'),
          const SizedBox(height: 8),
          const Text(
            'Después de seleccionar Nuevo hecho entrarás a la pantalla de captura. Completa la información solicitada antes de finalizar el registro.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Container(
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0xff2196f3),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back),
                      SizedBox(width: 18),
                      Text('Crear Hecho', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                ),
                _campoEjemplo(
                  Icons.location_on_outlined,
                  'Ubicación (GPS)',
                  'Verifica que la ubicación sea correcta.',
                ),
                _campoEjemplo(
                  Icons.description_outlined,
                  'Datos generales',
                  'Captura la información correspondiente al siniestro.',
                ),
                _campoEjemplo(
                  Icons.photo_camera_outlined,
                  'Foto del hecho',
                  'Agrega las fotografías requeridas.',
                ),
                _campoEjemplo(
                  Icons.directions_car_outlined,
                  'Vehículos',
                  'Registra los vehículos involucrados.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _aviso(
            icon: Icons.check_circle_outline,
            titulo: 'Antes de terminar',
            texto:
                'Revisa ubicación, datos del hecho, vehículos y fotografías para evitar que la captura quede incompleta.',
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

  Widget _campoEjemplo(IconData icon, String titulo, String descripcion) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    descripcion,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _indicadores() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
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
