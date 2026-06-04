import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/settings_statistics_files_service.dart';
import '../../services/tracking_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/account_drawer.dart';
import '../login_screen.dart';

class SettingsStatisticsFilesScreen extends StatefulWidget {
  final String? initialModuleId;

  const SettingsStatisticsFilesScreen({super.key, this.initialModuleId});

  @override
  State<SettingsStatisticsFilesScreen> createState() =>
      _SettingsStatisticsFilesScreenState();
}

class _SettingsStatisticsFilesScreenState
    extends State<SettingsStatisticsFilesScreen> {
  final _service = SettingsStatisticsFilesService();
  late Future<List<SettingsStatisticsModule>> _future;
  String? _downloadingEndpoint;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _future = _loadModules();
  }

  Future<List<SettingsStatisticsModule>> _loadModules() async {
    final modules = await _service.fetchModules();
    final selected = widget.initialModuleId?.trim();
    if (selected == null || selected.isEmpty) return modules;

    final filtered = modules.where((module) => module.id == selected).toList();
    return filtered.isEmpty ? modules : filtered;
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadModules();
    });
    await _future;
  }

  Future<void> _download(SettingsStatisticsFile file) async {
    if (_downloadingEndpoint != null) return;

    setState(() => _downloadingEndpoint = file.downloadEndpoint);

    try {
      final bytes = await _service.download(file);
      if (bytes.isEmpty) {
        throw Exception('El servidor regreso el archivo vacio.');
      }

      final dir = await getApplicationDocumentsDirectory();
      final safeName = file.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final savedFile = File('${dir.path}/$safeName');
      await savedFile.writeAsBytes(bytes, flush: true);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Archivo guardado: ${savedFile.path}')),
      );

      final result = await OpenFilex.open(savedFile.path);
      if (result.type != ResultType.done) {
        await Share.shareXFiles([XFile(savedFile.path)], text: file.fileName);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo descargar: $e')));
    } finally {
      if (mounted) {
        setState(() => _downloadingEndpoint = null);
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    if (_loggingOut) return;
    _loggingOut = true;

    try {
      try {
        await TrackingService.stop();
      } catch (_) {}
      await AuthService.logout();
    } finally {
      _loggingOut = false;
    }

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Consulta de archivos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          const AccountMenuAction(),
        ],
      ),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<SettingsStatisticsModule>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _EmptyState(
                      icon: Icons.warning_amber_rounded,
                      title: 'No se pudieron cargar los archivos',
                      subtitle: snapshot.error.toString(),
                    ),
                  ],
                );
              }

              final modules = snapshot.data ?? const [];
              if (modules.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: const [
                    _EmptyState(
                      icon: Icons.folder_off_outlined,
                      title: 'Sin consultas disponibles',
                      subtitle:
                          'Tu rol no tiene archivos de configuraciones asignados.',
                    ),
                  ],
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  for (final module in modules)
                    _ModuleSection(
                      module: module,
                      downloadingEndpoint: _downloadingEndpoint,
                      onDownload: _download,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ModuleSection extends StatelessWidget {
  final SettingsStatisticsModule module;
  final String? downloadingEndpoint;
  final ValueChanged<SettingsStatisticsFile> onDownload;

  const _ModuleSection({
    required this.module,
    required this.downloadingEndpoint,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  module.subtitle,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          for (final report in module.reports)
            _ReportCard(
              report: report,
              downloadingEndpoint: downloadingEndpoint,
              onDownload: onDownload,
            ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final SettingsStatisticsReport report;
  final String? downloadingEndpoint;
  final ValueChanged<SettingsStatisticsFile> onDownload;

  const _ReportCard({
    required this.report,
    required this.downloadingEndpoint,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        initiallyExpanded: report.files.isNotEmpty,
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withValues(alpha: .12),
          child: Icon(_iconForExtension(report.extension), color: Colors.blue),
        ),
        title: Text(
          report.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(report.subtitle),
        children: report.files.isEmpty
            ? const [
                ListTile(
                  title: Text('Sin archivos generados'),
                  subtitle: Text(
                    'Todavia no hay cortes guardados para esta consulta.',
                  ),
                ),
              ]
            : [
                for (final file in report.files)
                  ListTile(
                    title: Text(
                      file.fileName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      [
                        if (file.date.isNotEmpty) file.date,
                        if (file.sizeBytes != null)
                          _formatBytes(file.sizeBytes!),
                      ].join('  ·  '),
                    ),
                    trailing: IconButton(
                      tooltip: 'Descargar',
                      icon: downloadingEndpoint == file.downloadEndpoint
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      onPressed: downloadingEndpoint == null
                          ? () => onDownload(file)
                          : null,
                    ),
                  ),
              ],
      ),
    );
  }

  static IconData _iconForExtension(String extension) {
    switch (extension.trim().toLowerCase()) {
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'docx':
        return Icons.description_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'json':
        return Icons.data_object_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF64748B)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
