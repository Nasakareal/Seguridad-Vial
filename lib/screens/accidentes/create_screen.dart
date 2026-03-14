import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../models/hecho_form_data.dart';
import '../../services/offline_sync_service.dart';
import '../../services/hechos_form_service.dart';
import 'widgets/hecho_form.dart';

enum _PendingHechoAction { continueCapture, close }

class CreateHechoScreen extends StatefulWidget {
  const CreateHechoScreen({super.key});

  @override
  State<CreateHechoScreen> createState() => _CreateHechoScreenState();
}

class _CreateHechoScreenState extends State<CreateHechoScreen> {
  final HechoFormData _data = HechoFormData();

  Future<void> _handleSubmitted(
    OfflineActionResult result,
    HechoFormData data,
  ) async {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));

    final clientUuid = data.clientUuid?.trim() ?? '';
    if (!result.queued || clientUuid.isEmpty) {
      Navigator.pop(context, true);
      return;
    }

    final action = await showModalBottomSheet<_PendingHechoAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hecho guardado sin conexión',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ya puedes seguir capturando vehículos y lesionados para este hecho usando el UUID local mientras regresa internet.',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      _PendingHechoAction.continueCapture,
                    ),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Seguir capturando offline'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(sheetContext, _PendingHechoAction.close),
                    child: const Text('Terminar por ahora'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    switch (action) {
      case _PendingHechoAction.continueCapture:
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.pendingHechoCapture,
          arguments: {'hechoClientUuid': clientUuid},
        );
        return;
      case _PendingHechoAction.close:
      case null:
        Navigator.pop(context, true);
        return;
    }
  }

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
          onSubmitted: _handleSubmitted,
        ),
      ),
    );
  }
}
