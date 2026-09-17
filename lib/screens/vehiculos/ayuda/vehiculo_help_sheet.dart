import 'package:flutter/material.dart';

class VehiculoHelpSheet extends StatefulWidget {
  const VehiculoHelpSheet({super.key});

  @override
  State<VehiculoHelpSheet> createState() => _VehiculoHelpSheetState();
}

class _VehiculoHelpSheetState extends State<VehiculoHelpSheet>
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
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.10).animate(
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
    if (_pagina >= 1) {
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
                const Icon(Icons.directions_car_outlined, color: Colors.blue),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cómo registrar un vehículo',
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
              children: [_pasoBotonMas(), _pasoFormulario()],
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
                  child: Text(_pagina == 1 ? 'Entendido' : 'Siguiente'),
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
          _tituloPaso('1', 'Agrega un vehículo'),
          const SizedBox(height: 8),
          const Text(
            'Desde el listado de vehículos del hecho, utiliza el botón morado con el símbolo + ubicado en la esquina inferior derecha.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),
          Container(
            height: 430,
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
                      padding: const EdgeInsets.symmetric(horizontal: 15),
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
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No hay vehículos registrados.',
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                      height: 52,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xfffaf4fb),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.personal_injury, color: Colors.deepPurple),
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
                  ],
                ),
                Positioned(
                  right: 18,
                  bottom: 86,
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 64,
                      height: 64,
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
                  right: 12,
                  bottom: 158,
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
          const SizedBox(height: 18),
          _aviso(
            icon: Icons.add_circle_outline,
            titulo: 'Botón +',
            texto:
                'Cada vehículo involucrado en el hecho debe registrarse por separado. Pulsa + para iniciar la captura de un nuevo vehículo.',
          ),
        ],
      ),
    );
  }

  Widget _pasoFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tituloPaso('2', 'Comienza la captura del vehículo'),
          const SizedBox(height: 8),
          const Text(
            'Al pulsar + entrarás al formulario para registrar los datos del vehículo involucrado.',
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
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_car_outlined,
                    size: 58,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _aviso(
            icon: Icons.assignment_outlined,
            titulo: 'Formulario del vehículo',
            texto:
                'Captura la información del vehículo correspondiente. Dentro de ese formulario encontrarás su propia ayuda con la explicación de cada campo.',
          ),
          const SizedBox(height: 12),
          _aviso(
            icon: Icons.repeat,
            titulo: 'Más de un vehículo',
            texto:
                'Cuando termines un vehículo regresarás al listado. Si participaron más vehículos, vuelve a utilizar el botón + para registrar cada uno.',
          ),
          const SizedBox(height: 12),
          _aviso(
            icon: Icons.list_alt_outlined,
            titulo: 'Vehículos registrados',
            texto:
                'Los vehículos guardados aparecerán en esta pantalla asociados únicamente al hecho que estás consultando.',
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

  Widget _indicadores() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
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
