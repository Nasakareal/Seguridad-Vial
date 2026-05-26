import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/tutorial.dart';
import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../services/tutoriales_service.dart';
import '../../widgets/account_drawer.dart';
import '../login_screen.dart';

class TutorialesScreen extends StatefulWidget {
  const TutorialesScreen({super.key});

  @override
  State<TutorialesScreen> createState() => _TutorialesScreenState();
}

class _TutorialesScreenState extends State<TutorialesScreen> {
  late Future<List<TutorialCategory>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = TutorialesService.fetchCategorias();
  }

  Future<void> _reload() async {
    setState(() {
      _future = TutorialesService.fetchCategorias();
    });
    await _future;
  }

  Future<void> _logout(BuildContext context) async {
    if (_busy) return;
    _busy = true;

    try {
      try {
        await TrackingService.stop();
      } catch (_) {}
      await AuthService.logout();
    } finally {
      _busy = false;
    }

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _openTutorial(TutorialVideo tutorial) async {
    final url = tutorial.youtubeUrl.trim();
    if (url.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showMessage('Link de YouTube invalido.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _showMessage('No se pudo abrir el tutorial.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Tutoriales'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () {
              _reload().catchError((_) {});
            },
            icon: const Icon(Icons.refresh),
          ),
          const AccountMenuAction(),
        ],
      ),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: SafeArea(
        child: FutureBuilder<List<TutorialCategory>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _StatePanel(
                icon: Icons.cloud_off_outlined,
                title: 'No se pudieron cargar los tutoriales',
                subtitle: snapshot.error.toString(),
                actionLabel: 'Reintentar',
                onAction: () {
                  _reload().catchError((_) {});
                },
              );
            }

            final categories = snapshot.data ?? const <TutorialCategory>[];
            if (categories.isEmpty) {
              return _StatePanel(
                icon: Icons.play_circle_outline,
                title: 'Sin tutoriales publicados',
                subtitle: 'Cuando se agreguen en el panel web apareceran aqui.',
                actionLabel: 'Actualizar',
                onAction: () {
                  _reload().catchError((_) {});
                },
              );
            }

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return _CategorySection(
                    category: category,
                    onOpen: _openTutorial,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final TutorialCategory category;
  final ValueChanged<TutorialVideo> onOpen;

  const _CategorySection({required this.category, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.nombre,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (category.descripcion.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              category.descripcion,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...category.tutoriales.map(
            (tutorial) => _TutorialCard(tutorial: tutorial, onTap: onOpen),
          ),
        ],
      ),
    );
  }
}

class _TutorialCard extends StatelessWidget {
  final TutorialVideo tutorial;
  final ValueChanged<TutorialVideo> onTap;

  const _TutorialCard({required this.tutorial, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(tutorial),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _Thumbnail(url: tutorial.youtubeThumbnailUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tutorial.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    if (tutorial.descripcion.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        tutorial.descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.red,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String url;

  const _Thumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 112,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.play_circle_outline,
        color: Colors.blue,
        size: 34,
      ),
    );

    if (url.trim().isEmpty) {
      return placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 112,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _StatePanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 72),
        Icon(icon, size: 54, color: Colors.blue),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh),
            label: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}
