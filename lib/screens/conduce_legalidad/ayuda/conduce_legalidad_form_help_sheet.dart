import 'package:flutter/material.dart';

import 'conduce_legalidad_action_help_sheet.dart';

enum ConduceLegalidadCaptureFormHelpTopic {
  intervencion,
  vehiculo,
  persona,
  guardado,
}

enum ConduceLegalidadOperativoFormHelpTopic { datos, ubicacion, guardado }

class ConduceLegalidadCaptureFormHelpSheet extends StatelessWidget {
  final ConduceLegalidadCaptureFormHelpTopic topic;
  final bool isEditing;
  final bool isAlcoholimetria;

  const ConduceLegalidadCaptureFormHelpSheet({
    super.key,
    required this.topic,
    required this.isEditing,
    required this.isAlcoholimetria,
  });

  @override
  Widget build(BuildContext context) {
    return switch (topic) {
      ConduceLegalidadCaptureFormHelpTopic.intervencion =>
        const ConduceLegalidadActionHelpSheet(
          title: 'Fundamento e intervención',
          description:
              'Selecciona por qué se realizó la intervención; la ubicación general ya viene del operativo.',
          icon: Icons.gavel_outlined,
          color: Color(0xFF6D28D9),
          preview: _IntervencionPreview(),
          steps: <String>[
            'Abre Fundamento del operativo y selecciona la infracción que corresponda.',
            'Si aplican varias infracciones, pulsa Añadir otro fundamento y selecciona cada una.',
            'La Narrativa se genera sola. Revísala y corrígela sólo si hace falta; puedes restaurarla con el botón automático.',
            'Verifica la ubicación general mostrada. Esa misma se usa en el IPH y el ticket para evitar duplicarla.',
          ],
          note:
              'Selecciona solamente fundamentos que realmente correspondan a esta intervención.',
        ),
      ConduceLegalidadCaptureFormHelpTopic.vehiculo => ConduceLegalidadActionHelpSheet(
        title: isAlcoholimetria ? 'Agregar vehículo' : 'Agregar motocicleta',
        description:
            'Registra el vehículo y usa el escaneo de tarjeta para agilizar la captura sin dejar de revisar los datos.',
        icon: isAlcoholimetria
            ? Icons.directions_car_outlined
            : Icons.two_wheeler_outlined,
        color: const Color(0xFF0F766E),
        preview: _AgregarRegistroPreview(
          sectionTitle: 'Vehículos',
          addLabel: 'Agregar',
          scanLabel: 'Escanear tarjeta',
          saveLabel: 'Agregar vehículo',
          icon: isAlcoholimetria
              ? Icons.directions_car_outlined
              : Icons.two_wheeler_outlined,
          color: const Color(0xFF0F766E),
        ),
        steps: <String>[
          'En Vehículos pulsa Agregar.',
          'Dentro de la ventana pulsa Escanear tarjeta y encuadra el código con la cámara.',
          isAlcoholimetria
              ? 'Comprueba tipo, carrocería, marca, placas y serie; captura también el Número de inventario cuando exista.'
              : 'Comprueba tipo, carrocería, marca, placas y serie; captura obligatoriamente el Número de inventario y selecciona el Corralón de destino.',
          'Pulsa Agregar vehículo; al editar uno existente el botón dirá Guardar cambios.',
        ],
        note:
            'El escaneo propone datos, pero debes compararlos con la tarjeta física antes de agregarlos.',
      ),
      ConduceLegalidadCaptureFormHelpTopic.persona =>
        const ConduceLegalidadActionHelpSheet(
          title: 'Agregar persona y licencia',
          description:
              'Captura a la persona relacionada con la intervención y verifica su licencia.',
          icon: Icons.badge_outlined,
          color: Color(0xFF0369A1),
          preview: _AgregarRegistroPreview(
            sectionTitle: 'Personas',
            addLabel: 'Agregar',
            scanLabel: 'Escanear licencia',
            saveLabel: 'Agregar persona',
            icon: Icons.person_add_alt_1_outlined,
            color: Color(0xFF0369A1),
          ),
          steps: <String>[
            'En Personas pulsa Agregar.',
            'Pulsa Escanear licencia y mantén el código completo dentro del recuadro.',
            'Verifica los datos personales, el número de licencia y su vigencia.',
            'Pulsa Agregar persona y confirma que aparezca en la lista.',
          ],
          note:
              'Si algún dato no viene en el código, complétalo manualmente antes de agregar a la persona.',
        ),
      ConduceLegalidadCaptureFormHelpTopic.guardado => ConduceLegalidadActionHelpSheet(
        title: isEditing ? 'Actualizar la captura' : 'Guardar la captura',
        description:
            'Añade las evidencias, revisa el contenido y utiliza el botón final del formulario.',
        icon: Icons.save_outlined,
        color: const Color(0xFF15803D),
        preview: _GuardadoCapturaPreview(isEditing: isEditing),
        steps: <String>[
          'En Fotos pulsa Galería o Cámara y revisa las miniaturas seleccionadas.',
          'Usa Observaciones sólo para información adicional que no esté en la Narrativa.',
          isAlcoholimetria
              ? 'Revisa fundamentos, vehículo, personas y fotos.'
              : 'Confirma que exista un vehículo con Número de inventario y Corralón de destino; sin esos datos la captura no se guardará.',
          isEditing
              ? 'Pulsa Actualizar captura y espera el mensaje de confirmación.'
              : 'Pulsa Guardar captura y espera el mensaje de confirmación.',
        ],
        note: 'No cierres la pantalla mientras el botón muestre Guardando…',
      ),
    };
  }
}

class ConduceLegalidadOperativoFormHelpSheet extends StatelessWidget {
  final ConduceLegalidadOperativoFormHelpTopic topic;
  final String operativoNombre;
  final bool isEditing;
  final bool canSetSchedule;
  final bool canAssignOrganization;

  const ConduceLegalidadOperativoFormHelpSheet({
    super.key,
    required this.topic,
    required this.operativoNombre,
    required this.isEditing,
    required this.canSetSchedule,
    required this.canAssignOrganization,
  });

  @override
  Widget build(BuildContext context) {
    return switch (topic) {
      ConduceLegalidadOperativoFormHelpTopic.datos => ConduceLegalidadActionHelpSheet(
        title: 'Datos del operativo',
        description:
            'Confirma el tipo de operativo y completa únicamente los controles habilitados para tu cuenta.',
        icon: Icons.fact_check_outlined,
        color: const Color(0xFF2563EB),
        preview: _DatosOperativoPreview(
          operativoNombre: operativoNombre,
          showSchedule: canSetSchedule,
          showOrganization: canAssignOrganization,
        ),
        steps: <String>[
          'Verifica que Operativo muestre $operativoNombre.',
          if (canAssignOrganization)
            'Selecciona la Unidad responsable y, cuando corresponda, la Delegación específica.',
          if (canSetSchedule)
            'Pulsa los botones de fecha y hora para establecer el inicio.',
          if (!canAssignOrganization && !canSetSchedule)
            'La adscripción, fecha y hora se asignan automáticamente; continúa con la ubicación.',
        ],
        note:
            'Los controles de adscripción, fecha y hora sólo aparecen cuando tu cuenta tiene permiso para modificarlos.',
      ),
      ConduceLegalidadOperativoFormHelpTopic.ubicacion =>
        const ConduceLegalidadActionHelpSheet(
          title: 'Ubicación y coordenadas',
          description:
              'Describe el punto del operativo y obtén su ubicación estando físicamente en el lugar.',
          icon: Icons.my_location_outlined,
          color: Color(0xFF7C3AED),
          preview: _UbicacionOperativoPreview(),
          steps: <String>[
            'Selecciona Municipio y captura Lugar, Número si existe y Colonia.',
            'Pulsa Obtener coordenadas y concede el permiso de ubicación si se solicita.',
            'Espera a que el campo Coordenadas muestre la latitud y longitud detectadas.',
            'Revisa los datos autocompletados antes de continuar.',
          ],
          note:
              'Obtén las coordenadas desde el punto real del operativo para evitar una ubicación incorrecta.',
        ),
      ConduceLegalidadOperativoFormHelpTopic.guardado =>
        ConduceLegalidadActionHelpSheet(
          title: isEditing ? 'Guardar los cambios' : 'Activar el operativo',
          description:
              'Cuando todos los datos sean correctos, utiliza el botón que aparece al final del formulario.',
          icon: isEditing ? Icons.save_outlined : Icons.play_circle_outline,
          color: const Color(0xFF15803D),
          preview: _GuardarOperativoPreview(isEditing: isEditing),
          steps: <String>[
            'Revisa municipio, lugar, colonia y coordenadas.',
            isEditing ? 'Pulsa Guardar cambios.' : 'Pulsa Activar operativo.',
            'Espera el mensaje de confirmación antes de regresar.',
          ],
          note: isEditing
              ? 'Los cambios se aplicarán al operativo existente.'
              : 'Después de activarlo podrás entrar al operativo y agregar capturas.',
        ),
    };
  }
}

class _IntervencionPreview extends StatelessWidget {
  const _IntervencionPreview();

  @override
  Widget build(BuildContext context) {
    return const _PreviewCard(
      color: Color(0xFF6D28D9),
      children: <Widget>[
        _DemoField(
          label: 'Fundamento del operativo',
          value: 'Selecciona la infracción',
          icon: Icons.gavel_outlined,
          trailing: Icons.arrow_drop_down,
          highlighted: true,
        ),
        SizedBox(height: 9),
        _DemoButton(
          label: 'Añadir otro fundamento',
          icon: Icons.add,
          outlined: true,
        ),
        SizedBox(height: 9),
        _DemoField(label: 'Narrativa', icon: Icons.notes_outlined),
        SizedBox(height: 9),
        Row(
          children: <Widget>[
            Expanded(
              child: _DemoField(label: 'Municipio', icon: Icons.location_city),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _DemoField(
                label: 'Lugar específico',
                icon: Icons.place_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AgregarRegistroPreview extends StatelessWidget {
  final String sectionTitle;
  final String addLabel;
  final String scanLabel;
  final String saveLabel;
  final IconData icon;
  final Color color;

  const _AgregarRegistroPreview({
    required this.sectionTitle,
    required this.addLabel,
    required this.scanLabel,
    required this.saveLabel,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      color: color,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sectionTitle,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            _DemoButton(label: addLabel, icon: Icons.add, highlighted: true),
          ],
        ),
        const SizedBox(height: 12),
        _DemoButton(
          label: scanLabel,
          icon: Icons.qr_code_scanner,
          outlined: true,
          highlighted: true,
          expand: true,
        ),
        const SizedBox(height: 9),
        const _DemoField(label: 'Datos leídos y revisados'),
        const SizedBox(height: 9),
        _DemoButton(label: saveLabel, icon: Icons.check, expand: true),
      ],
    );
  }
}

class _GuardadoCapturaPreview extends StatelessWidget {
  final bool isEditing;

  const _GuardadoCapturaPreview({required this.isEditing});

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      color: const Color(0xFF15803D),
      children: <Widget>[
        const Text('Fotos', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 9),
        const Row(
          children: <Widget>[
            Expanded(
              child: _DemoButton(
                label: 'Galería',
                icon: Icons.photo_library_outlined,
                outlined: true,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _DemoButton(
                label: 'Cámara',
                icon: Icons.photo_camera_outlined,
                outlined: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        const _DemoField(label: 'Observaciones', icon: Icons.info_outline),
        const SizedBox(height: 12),
        _DemoButton(
          label: isEditing ? 'Actualizar captura' : 'Guardar captura',
          icon: Icons.save,
          highlighted: true,
          expand: true,
        ),
      ],
    );
  }
}

class _DatosOperativoPreview extends StatelessWidget {
  final String operativoNombre;
  final bool showSchedule;
  final bool showOrganization;

  const _DatosOperativoPreview({
    required this.operativoNombre,
    required this.showSchedule,
    required this.showOrganization,
  });

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      color: const Color(0xFF2563EB),
      children: <Widget>[
        _DemoField(
          label: 'Operativo',
          value: operativoNombre,
          icon: Icons.fact_check_outlined,
        ),
        if (showOrganization) ...const <Widget>[
          SizedBox(height: 9),
          _DemoField(
            label: 'Unidad responsable',
            icon: Icons.apartment_outlined,
            trailing: Icons.arrow_drop_down,
          ),
        ],
        if (showSchedule) ...const <Widget>[
          SizedBox(height: 9),
          Row(
            children: <Widget>[
              Expanded(
                child: _DemoButton(
                  label: 'Fecha',
                  icon: Icons.calendar_month_outlined,
                  outlined: true,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _DemoButton(
                  label: 'Hora',
                  icon: Icons.schedule,
                  outlined: true,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _UbicacionOperativoPreview extends StatelessWidget {
  const _UbicacionOperativoPreview();

  @override
  Widget build(BuildContext context) {
    return const _PreviewCard(
      color: Color(0xFF7C3AED),
      children: <Widget>[
        _DemoField(
          label: 'Municipio *',
          value: 'MORELIA',
          icon: Icons.location_city,
          trailing: Icons.edit_location_alt_outlined,
        ),
        SizedBox(height: 9),
        Row(
          children: <Widget>[
            Expanded(
              child: _DemoField(label: 'Lugar *', icon: Icons.place),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _DemoField(
                label: 'Colonia *',
                icon: Icons.location_city_outlined,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        _DemoButton(
          label: 'Obtener coordenadas',
          icon: Icons.my_location,
          outlined: true,
          highlighted: true,
          expand: true,
        ),
        SizedBox(height: 9),
        _DemoField(
          label: 'Coordenadas *',
          value: '19.6841234, -101.1805678',
          icon: Icons.pin_drop_outlined,
        ),
      ],
    );
  }
}

class _GuardarOperativoPreview extends StatelessWidget {
  final bool isEditing;

  const _GuardarOperativoPreview({required this.isEditing});

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      color: const Color(0xFF15803D),
      children: <Widget>[
        const _DemoField(
          label: 'Coordenadas *',
          value: 'Ubicación lista',
          icon: Icons.check_circle_outline,
        ),
        const SizedBox(height: 12),
        _DemoButton(
          label: isEditing ? 'Guardar cambios' : 'Activar operativo',
          icon: isEditing ? Icons.save_outlined : Icons.play_arrow,
          highlighted: true,
          expand: true,
        ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final Color color;
  final List<Widget> children;

  const _PreviewCard({required this.color, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .28)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: .08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _DemoField extends StatelessWidget {
  final String label;
  final String? value;
  final IconData? icon;
  final IconData? trailing;
  final bool highlighted;

  const _DemoField({
    required this.label,
    this.value,
    this.icon,
    this.trailing,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFF5F3FF) : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: highlighted ? const Color(0xFF7C3AED) : Colors.grey.shade400,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                if ((value ?? '').isNotEmpty)
                  Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
              ],
            ),
          ),
          if (trailing != null) Icon(trailing, size: 21),
        ],
      ),
    );
  }
}

class _DemoButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool outlined;
  final bool highlighted;
  final bool expand;

  const _DemoButton({
    required this.label,
    required this.icon,
    this.outlined = false,
    this.highlighted = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = outlined
        ? const Color(0xFF374151)
        : const Color(0xFF166534);
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: outlined ? Colors.white : const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: highlighted
              ? const Color(0xFFEA580C)
              : (outlined ? Colors.grey.shade400 : const Color(0xFF86EFAC)),
          width: highlighted ? 2 : 1,
        ),
        boxShadow: highlighted
            ? <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFFEA580C).withValues(alpha: .18),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 19, color: foreground),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    return child;
  }
}
