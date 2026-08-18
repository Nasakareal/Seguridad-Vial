import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

typedef RegistrarTokenCallback = Future<void> Function(String token);

enum ComunicacionPushAccion { recibida, abierta }

class ComunicacionPushEvento {
  final ComunicacionPushAccion accion;

  final String? messageId;

  final int? comunicacionId;
  final int? remitenteUserId;
  final int? destinatarioUserId;

  final String? tipo;
  final String? remitente;
  final String? asunto;
  final String? contenido;

  final bool tieneImagenes;

  const ComunicacionPushEvento({
    required this.accion,
    this.messageId,
    this.comunicacionId,
    this.remitenteUserId,
    this.destinatarioUserId,
    this.tipo,
    this.remitente,
    this.asunto,
    this.contenido,
    this.tieneImagenes = false,
  });

  bool get esMensaje => tipo?.toLowerCase() == 'mensaje';

  bool get esOrden => tipo?.toLowerCase() == 'orden';

  bool get esAviso => tipo?.toLowerCase() == 'aviso';

  bool get puedeAbrirConversacion => esMensaje && remitenteUserId != null;

  bool get puedeAbrirDetalle => comunicacionId != null;

  factory ComunicacionPushEvento.fromRemoteMessage(
    RemoteMessage message, {
    required ComunicacionPushAccion accion,
  }) {
    final data = message.data;

    return ComunicacionPushEvento(
      accion: accion,
      messageId: message.messageId,
      comunicacionId: _toInt(data['comunicacion_id']),
      remitenteUserId: _toInt(data['remitente_user_id']),
      destinatarioUserId: _toInt(data['destinatario_user_id']),
      tipo: _nullableString(data['tipo']),
      remitente:
          _nullableString(data['remitente']) ??
          _nullableString(data['remitente_nombre']),
      asunto:
          _nullableString(data['asunto']) ??
          _nullableString(message.notification?.title),
      contenido:
          _nullableString(data['contenido']) ??
          _nullableString(message.notification?.body),
      tieneImagenes: _toBool(data['tiene_imagenes']),
    );
  }

  factory ComunicacionPushEvento.fromPayload(
    String payload, {
    required ComunicacionPushAccion accion,
  }) {
    final decoded = jsonDecode(payload);

    if (decoded is! Map) {
      throw const FormatException('Payload inválido.');
    }

    final data = Map<String, dynamic>.from(decoded);

    return ComunicacionPushEvento(
      accion: accion,
      messageId: _nullableString(data['message_id']),
      comunicacionId: _toInt(data['comunicacion_id']),
      remitenteUserId: _toInt(data['remitente_user_id']),
      destinatarioUserId: _toInt(data['destinatario_user_id']),
      tipo: _nullableString(data['tipo']),
      remitente: _nullableString(data['remitente']),
      asunto: _nullableString(data['asunto']),
      contenido: _nullableString(data['contenido']),
      tieneImagenes: _toBool(data['tiene_imagenes']),
    );
  }

  String toPayload() {
    return jsonEncode({
      'message_id': messageId,
      'comunicacion_id': comunicacionId,
      'remitente_user_id': remitenteUserId,
      'destinatario_user_id': destinatarioUserId,
      'tipo': tipo,
      'remitente': remitente,
      'asunto': asunto,
      'contenido': contenido,
      'tiene_imagenes': tieneImagenes,
    });
  }
}

class ComunicacionNotificationService {
  ComunicacionNotificationService._();

  static final ComunicacionNotificationService instance =
      ComunicacionNotificationService._();

  static const String channelId = 'comunicaciones';

  static const String channelName = 'Comunicaciones';

  static const String channelDescription =
      'Mensajes, avisos y órdenes de Seguridad Vial';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<ComunicacionPushEvento> _eventosController =
      StreamController<ComunicacionPushEvento>.broadcast();

  final StreamController<String> _tokensController =
      StreamController<String>.broadcast();

  StreamSubscription<RemoteMessage>? _onMessageSubscription;

  StreamSubscription<RemoteMessage>? _onMessageOpenedSubscription;

  StreamSubscription<String>? _tokenSubscription;

  RegistrarTokenCallback? _registrarToken;

  ComunicacionPushEvento? _eventoInicialPendiente;

  bool _inicializado = false;

  Stream<ComunicacionPushEvento> get eventos => _eventosController.stream;

  Stream<String> get tokens => _tokensController.stream;

  Future<void> inicializar({RegistrarTokenCallback? registrarToken}) async {
    if (_inicializado) {
      if (registrarToken != null) {
        _registrarToken = registrarToken;

        await sincronizarToken();
      }

      return;
    }

    _registrarToken = registrarToken;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _inicializarNotificacionesLocales();

    await solicitarPermisos();

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    _onMessageSubscription = FirebaseMessaging.onMessage.listen(
      _procesarMensajeForeground,
    );

    _onMessageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _procesarMensajeAbierto,
    );

    _tokenSubscription = _messaging.onTokenRefresh.listen((token) async {
      _tokensController.add(token);

      final callback = _registrarToken;

      if (callback != null) {
        await callback(token);
      }
    });

    await sincronizarToken();

    await _procesarArranqueDesdeNotificacion();

    _inicializado = true;
  }

  Future<NotificationSettings> solicitarPermisos() async {
    return _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  Future<String?> obtenerToken() async {
    return _messaging.getToken();
  }

  Future<void> sincronizarToken() async {
    final token = await _messaging.getToken();

    if (token == null || token.trim().isEmpty) {
      return;
    }

    _tokensController.add(token);

    final callback = _registrarToken;

    if (callback != null) {
      await callback(token);
    }
  }

  Future<void> eliminarToken() async {
    await _messaging.deleteToken();
  }

  ComunicacionPushEvento? consumirEventoInicial() {
    final evento = _eventoInicialPendiente;

    _eventoInicialPendiente = null;

    return evento;
  }

  Future<void> _inicializarNotificacionesLocales() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    const settings = InitializationSettings(android: android, iOS: ios);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _procesarNotificacionLocalAbierta,
    );

    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(channel);
  }

  Future<void> _procesarArranqueDesdeNotificacion() async {
    final initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null && _esComunicacion(initialMessage)) {
      _eventoInicialPendiente = ComunicacionPushEvento.fromRemoteMessage(
        initialMessage,
        accion: ComunicacionPushAccion.abierta,
      );
    }

    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();

    if (launchDetails?.didNotificationLaunchApp == true &&
        launchDetails?.notificationResponse?.payload != null) {
      final payload = launchDetails!.notificationResponse!.payload!;

      try {
        _eventoInicialPendiente = ComunicacionPushEvento.fromPayload(
          payload,
          accion: ComunicacionPushAccion.abierta,
        );
      } catch (_) {}
    }
  }

  Future<void> _procesarMensajeForeground(RemoteMessage message) async {
    if (!_esComunicacion(message)) {
      return;
    }

    final evento = ComunicacionPushEvento.fromRemoteMessage(
      message,
      accion: ComunicacionPushAccion.recibida,
    );

    _eventosController.add(evento);

    await _mostrarNotificacionLocal(message, evento);
  }

  void _procesarMensajeAbierto(RemoteMessage message) {
    if (!_esComunicacion(message)) {
      return;
    }

    final evento = ComunicacionPushEvento.fromRemoteMessage(
      message,
      accion: ComunicacionPushAccion.abierta,
    );

    _eventosController.add(evento);
  }

  void _procesarNotificacionLocalAbierta(NotificationResponse response) {
    final payload = response.payload;

    if (payload == null || payload.trim().isEmpty) {
      return;
    }

    try {
      final evento = ComunicacionPushEvento.fromPayload(
        payload,
        accion: ComunicacionPushAccion.abierta,
      );

      _eventosController.add(evento);
    } catch (_) {}
  }

  Future<void> _mostrarNotificacionLocal(
    RemoteMessage message,
    ComunicacionPushEvento evento,
  ) async {
    final notification = message.notification;

    final titulo = notification?.title ?? _tituloEvento(evento);

    final cuerpo = notification?.body ?? _cuerpoEvento(evento);

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.private,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final id = evento.comunicacionId ?? _notificationId(message.messageId);

    await _localNotifications.show(
      id,
      titulo,
      cuerpo,
      details,
      payload: evento.toPayload(),
    );
  }

  String _tituloEvento(ComunicacionPushEvento evento) {
    if (evento.remitente != null && evento.remitente!.trim().isNotEmpty) {
      return evento.remitente!.trim();
    }

    if (evento.esOrden) {
      return 'Nueva orden';
    }

    if (evento.esAviso) {
      return 'Nuevo aviso';
    }

    return 'Nuevo mensaje';
  }

  String _cuerpoEvento(ComunicacionPushEvento evento) {
    if (evento.contenido != null && evento.contenido!.trim().isNotEmpty) {
      return evento.contenido!.trim();
    }

    if (evento.asunto != null && evento.asunto!.trim().isNotEmpty) {
      return evento.asunto!.trim();
    }

    if (evento.tieneImagenes) {
      return 'Te envió una imagen';
    }

    if (evento.esOrden) {
      return 'Tienes una nueva orden pendiente.';
    }

    if (evento.esAviso) {
      return 'Tienes un nuevo aviso.';
    }

    return 'Tienes un nuevo mensaje.';
  }

  bool _esComunicacion(RemoteMessage message) {
    final data = message.data;

    final modulo = data['modulo']?.toString().trim().toLowerCase();

    if (modulo == 'comunicaciones' || modulo == 'comunicacion') {
      return true;
    }

    if (data.containsKey('comunicacion_id')) {
      return true;
    }

    return data.containsKey('remitente_user_id');
  }

  int _notificationId(String? messageId) {
    if (messageId == null || messageId.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    }

    return messageId.hashCode.abs().remainder(2147483647);
  }

  Future<void> dispose() async {
    await _onMessageSubscription?.cancel();

    await _onMessageOpenedSubscription?.cancel();

    await _tokenSubscription?.cancel();

    await _eventosController.close();

    await _tokensController.close();

    _inicializado = false;
  }
}

int? _toInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value.toString());
}

bool _toBool(dynamic value) {
  if (value == null) {
    return false;
  }

  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final texto = value.toString().trim().toLowerCase();

  return texto == '1' ||
      texto == 'true' ||
      texto == 'yes' ||
      texto == 'si' ||
      texto == 'sí';
}

String? _nullableString(dynamic value) {
  if (value == null) {
    return null;
  }

  final texto = value.toString().trim();

  return texto.isEmpty ? null : texto;
}
