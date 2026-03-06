import 'package:flutter/material.dart';

import '../../models/hecho_form_data.dart';
import '../../services/hechos_form_service.dart';
import 'widgets/hecho_form.dart';

class CreateHechoScreen extends StatefulWidget {
  const CreateHechoScreen({super.key});

  @override
  State<CreateHechoScreen> createState() => _CreateHechoScreenState();
}

class _CreateHechoScreenState extends State<CreateHechoScreen> {
  final HechoFormData _data = HechoFormData();

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear Hecho')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomSafe + 18),
        child: HechoForm(
          mode: HechoFormMode.create,
          data: _data,
          onSubmit:
              ({
                required data,
                required dictamenSelected,
                required fotoLugar,
                required fotoSituacion,
              }) {
                return HechosFormService.create(
                  data: data,
                  dictamenSelected: dictamenSelected,
                  fotoLugar: fotoLugar,
                  fotoSituacion: fotoSituacion,
                );
              },
        ),
      ),
    );
  }
}
