import 'package:flutter/material.dart';

class AccionesVehiculoHelpSheet extends StatefulWidget {
  const AccionesVehiculoHelpSheet({super.key});

  @override
  State<AccionesVehiculoHelpSheet> createState() =>
      _AccionesVehiculoHelpSheetState();
}

class _AccionesVehiculoHelpSheetState extends State<AccionesVehiculoHelpSheet>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  int _pagina = 0;

  static const int _totalPaginas = 4;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.08).animate(
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
                const Icon(Icons.touch_app_outlined, color: Colors.blue),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Qué hace cada botón',
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
                _pasoEditar(),
                _pasoConductor(),
                _pasoFoto(),
                _pasoInventario(),
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

  Widget _pasoEditar() {
    return _pasoAccion(
      numero: '1',
      titulo: 'Editar los datos del vehículo',
      descripcion:
          'Si algún dato del vehículo quedó incorrecto o faltó información, puedes volver al formulario de edición.',
      iconoActivo: Icons.edit,
      indiceActivo: 0,
      avisos: [
        _aviso(
          icon: Icons.edit_outlined,
          titulo: 'Botón del lápiz',
          texto:
              'Pulsa el lápiz para abrir el formulario de edición del vehículo.',
        ),
        _aviso(
          icon: Icons.directions_car_outlined,
          titulo: 'También puedes tocar los datos',
          texto:
              'Puedes pulsar directamente sobre la tarjeta donde aparecen la marca, línea, placas, modelo y conductor. También abrirá la edición del vehículo.',
        ),
        _aviso(
          icon: Icons.fact_check_outlined,
          titulo: 'Corrige solamente lo necesario',
          texto:
              'Utiliza esta opción cuando detectes que algún dato fue capturado incorrectamente o quedó pendiente de completar.',
        ),
      ],
    );
  }

  Widget _pasoConductor() {
    return _pasoAccion(
      numero: '2',
      titulo: 'Agregar o editar conductor',
      descripcion:
          'El botón de la persona con el símbolo + permite administrar al conductor relacionado con ese vehículo.',
      iconoActivo: Icons.person_add_alt_1,
      indiceActivo: 1,
      avisos: [
        _aviso(
          icon: Icons.person_add_alt_1,
          titulo: 'Si todavía no hay conductor',
          texto:
              'Pulsa este botón para abrir el formulario y registrar al conductor relacionado con el vehículo.',
        ),
        _aviso(
          icon: Icons.manage_accounts_outlined,
          titulo: 'Si el conductor ya existe',
          texto:
              'El mismo botón permite volver a la captura del conductor para revisar o modificar sus datos.',
        ),
        _aviso(
          icon: Icons.link_outlined,
          titulo: 'Conductor del vehículo',
          texto:
              'La persona que registres desde aquí queda relacionada con este vehículo en particular.',
        ),
      ],
    );
  }

  Widget _pasoFoto() {
    return _pasoAccion(
      numero: '3',
      titulo: 'Foto del vehículo',
      descripcion:
          'El botón de la cámara abre un menú para administrar la fotografía correspondiente al vehículo.',
      iconoActivo: Icons.photo_camera,
      indiceActivo: 2,
      contenidoExtra: _modalFotoDemo(),
      avisos: [
        _aviso(
          icon: Icons.photo_camera_outlined,
          titulo: 'Botón de cámara',
          texto:
              'Pulsa la cámara para abrir el menú de fotografía del vehículo.',
        ),
        _aviso(
          icon: Icons.upload_outlined,
          titulo: 'Subir fotografía',
          texto:
              'Si el vehículo todavía no cuenta con fotografía, utiliza la opción Subir para seleccionarla.',
        ),
        _aviso(
          icon: Icons.image_outlined,
          titulo: 'Foto existente',
          texto:
              'Cuando ya existe una fotografía, desde este mismo menú puedes consultarla o reemplazarla.',
        ),
      ],
    );
  }

  Widget _pasoInventario() {
    return _pasoAccion(
      numero: '4',
      titulo: 'Inventario del vehículo',
      descripcion:
          'El último botón, representado por una caja de archivo, abre el registro de inventario relacionado con la grúa.',
      iconoActivo: Icons.inventory_2,
      indiceActivo: 3,
      contenidoExtra: _modalInventarioDemo(),
      avisos: [
        _aviso(
          icon: Icons.inventory_2_outlined,
          titulo: 'Botón de inventario',
          texto:
              'Pulsa este botón para abrir los datos de inventario del vehículo.',
        ),
        _aviso(
          icon: Icons.confirmation_number_outlined,
          titulo: 'Número de inventario',
          texto: 'Captura el número de inventario que corresponda al vehículo.',
        ),
        _aviso(
          icon: Icons.upload_file_outlined,
          titulo: 'Foto del inventario',
          texto:
              'El mismo menú permite agregar una fotografía del inventario y guardar ambos datos relacionados.',
        ),
      ],
    );
  }

  Widget _pasoAccion({
    required String numero,
    required String titulo,
    required String descripcion,
    required IconData iconoActivo,
    required int indiceActivo,
    required List<Widget> avisos,
    Widget? contenidoExtra,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tituloPaso(numero, titulo),
          const SizedBox(height: 8),
          Text(descripcion, style: const TextStyle(fontSize: 15, height: 1.4)),
          const SizedBox(height: 20),
          _tarjetaVehiculoDemo(
            iconoActivo: iconoActivo,
            indiceActivo: indiceActivo,
          ),
          if (contenidoExtra != null) ...[
            const SizedBox(height: 16),
            contenidoExtra,
          ],
          const SizedBox(height: 18),
          ..._separarAvisos(avisos),
        ],
      ),
    );
  }

  Widget _tarjetaVehiculoDemo({
    required IconData iconoActivo,
    required int indiceActivo,
  }) {
    final iconos = [
      Icons.edit,
      Icons.person_add_alt_1,
      Icons.photo_camera,
      Icons.inventory_2,
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xfffbf5fc),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.directions_car, size: 28),
            title: Text(
              'AUDI A4',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('Placas: PGD023B  •  Modelo: 2008\nConductor: —'),
            isThreeLine: true,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(iconos.length, (index) {
                final activo = index == indiceActivo;

                if (!activo) {
                  return Icon(
                    iconos[index],
                    size: 29,
                    color: Colors.grey.shade700,
                  );
                }

                return ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withValues(alpha: 0.25),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      iconoActivo,
                      size: 29,
                      color: Colors.deepPurple,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modalFotoDemo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfff3f5fb),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Foto del vehículo #137960',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text('Este vehículo no tiene foto todavía.'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.upload),
                  label: const Text('Subir'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modalInventarioDemo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfff3f5fb),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inventario del vehículo #137960',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text('Este vehículo no tiene inventario todavía.'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
            child: const Row(
              children: [
                Icon(Icons.confirmation_number_outlined),
                SizedBox(width: 10),
                Text(
                  'Número de inventario',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Subir foto'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _separarAvisos(List<Widget> avisos) {
    final resultado = <Widget>[];

    for (var i = 0; i < avisos.length; i++) {
      resultado.add(avisos[i]);

      if (i < avisos.length - 1) {
        resultado.add(const SizedBox(height: 12));
      }
    }

    return resultado;
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
