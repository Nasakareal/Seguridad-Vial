import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../services/calea_survey_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../login_screen.dart';
import 'calea_survey_attempt_screen.dart';

class CaleaSurveysScreen extends StatefulWidget {
  const CaleaSurveysScreen({super.key});
  @override
  State<CaleaSurveysScreen> createState() => _CaleaSurveysScreenState();
}

class _CaleaSurveysScreenState extends State<CaleaSurveysScreen> {
  List<Map<String, dynamic>> _active = [], _managed = [];
  bool _loading = true, _admin = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _admin =
          await AuthService.isSuperadmin() ||
          await AuthService.hasRoleName('administrador');
      final active = await CaleaSurveyService.active();
      final managed = _admin
          ? await CaleaSurveyService.managed()
          : <Map<String, dynamic>>[];
      if (mounted)
        setState(() {
          _active = active;
          _managed = managed;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = CaleaSurveyService.clean(e);
        });
    }
  }

  Future<void> _logout() async {
    try {
      await TrackingService.stop();
    } catch (_) {}
    await AuthService.logout();
    if (mounted)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
  }

  Future<void> _start(Map<String, dynamic> survey) async {
    final previous = survey['ultimo_intento'] is Map
        ? Map<String, dynamic>.from(survey['ultimo_intento'] as Map)
        : null;
    final running = previous?['estado'] == 'en_curso';
    if (survey['puede_iniciar'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este intento ya fue utilizado. Solicita una reautorización.',
          ),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaleaSurveyAttemptScreen(
          surveyId: running ? null : int.parse('${survey['id']}'),
          attemptUuid: running ? '${previous!['uuid']}' : null,
        ),
      ),
    );
    _load();
  }

  Future<void> _openResults(Map<String, dynamic> survey) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ResultsSheet(survey: survey, onChanged: _load),
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: _admin ? 2 : 1,
    child: Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF102A43),
        foregroundColor: Colors.white,
        title: const Text('Encuestas CALEA'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          const AccountMenuAction(),
        ],
        bottom: _admin
            ? const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: [
                  Tab(text: 'Mis encuestas'),
                  Tab(text: 'Administrar'),
                ],
              )
            : null,
      ),
      endDrawer: AppAccountDrawer(onLogout: _logout),
      floatingActionButton: _admin
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  AppRoutes.caleaEncuestaCrear,
                );
                if (result == true) _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('Crear encuesta'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _state(Icons.cloud_off, 'No pudimos cargar las encuestas', _error!)
          : TabBarView(children: [_activeList(), if (_admin) _managedList()]),
    ),
  );
  Widget _activeList() => RefreshIndicator(
    onRefresh: _load,
    child: _active.isEmpty
        ? _state(
            Icons.assignment_turned_in_outlined,
            'Sin encuestas pendientes',
            'Cuando te asignen una encuesta activa aparecerá aquí.',
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _hero(),
              ..._active.map((e) => _surveyCard(e, admin: false)),
              const SizedBox(height: 80),
            ],
          ),
  );
  Widget _managedList() => RefreshIndicator(
    onRefresh: _load,
    child: _managed.isEmpty
        ? _state(
            Icons.inventory_2_outlined,
            'Aún no hay encuestas',
            'Crea la primera con el botón inferior.',
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ..._managed.map((e) => _surveyCard(e, admin: true)),
              const SizedBox(height: 80),
            ],
          ),
  );
  Widget _hero() => Container(
    margin: const EdgeInsets.only(bottom: 15),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF173F5F), Color(0xFF245B78)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      children: [
        Icon(Icons.timer_outlined, color: Color(0xFFFFD76A), size: 38),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Evaluaciones cronometradas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Al iniciar, el reloj no se detiene. Prepárate antes de entrar.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _surveyCard(Map<String, dynamic> e, {required bool admin}) {
    final attempt = e['ultimo_intento'] is Map
        ? Map<String, dynamic>.from(e['ultimo_intento'] as Map)
        : null;
    final status = '${attempt?['estado'] ?? ''}';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: admin ? () => _openResults(e) : () => _start(e),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4D1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      admin
                          ? Icons.admin_panel_settings_outlined
                          : Icons.fact_check_outlined,
                      color: const Color(0xFF997300),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      '${e['titulo']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF102A43),
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if ('${e['descripcion'] ?? ''}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '${e['descripcion']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _chip(Icons.timer_outlined, '${e['duracion_minutos']} min'),
                  _chip(
                    Icons.quiz_outlined,
                    '${e['preguntas_count'] ?? '?'} preguntas',
                  ),
                  if (admin)
                    _chip(
                      Icons.groups_outlined,
                      '${e['intentos_count'] ?? 0} intentos',
                    ),
                  if (status.isNotEmpty)
                    _chip(Icons.circle_outlined, status.replaceAll('_', ' ')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.blueGrey.shade50,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
  Widget _state(IconData icon, String title, String subtitle) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      SizedBox(height: 140),
      Icon(icon, size: 58, color: Colors.blueGrey),
      const SizedBox(height: 12),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(subtitle, textAlign: TextAlign.center),
      ),
    ],
  );
}

class _ResultsSheet extends StatefulWidget {
  final Map<String, dynamic> survey;
  final Future<void> Function() onChanged;
  const _ResultsSheet({required this.survey, required this.onChanged});
  @override
  State<_ResultsSheet> createState() => _ResultsSheetState();
}

class _ResultsSheetState extends State<_ResultsSheet> {
  late Future<List<Map<String, dynamic>>> _future = CaleaSurveyService.results(
    int.parse('${widget.survey['id']}'),
  );
  Future<void> _reauthorize(Map<String, dynamic> row) async {
    await CaleaSurveyService.reauthorize(
      int.parse('${widget.survey['id']}'),
      int.parse('${row['user_id']}'),
      reason: 'Reautorizado desde la aplicación',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nuevo intento autorizado.')),
      );
      setState(
        () => _future = CaleaSurveyService.results(
          int.parse('${widget.survey['id']}'),
        ),
      );
    }
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.survey['titulo']}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (_, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rows = snap.data!;
                  if (rows.isEmpty) {
                    return const Center(
                      child: Text('Todavía no hay intentos.'),
                    );
                  }
                  return ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      final userId = r['user_id'];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            r['estado'] == 'finalizado'
                                ? Icons.check
                                : Icons.person_outline,
                          ),
                        ),
                        title: Text(
                          '${r['participante']}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${r['estado']} · Calificación: ${r['calificacion'] ?? '—'}',
                        ),
                        trailing: userId == null
                            ? null
                            : FilledButton.tonal(
                                onPressed: () => _reauthorize(r),
                                child: const Text('Reautorizar'),
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
