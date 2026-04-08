import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class OfflineActionResult {
  final bool synced;
  final bool queued;
  final String message;

  const OfflineActionResult.synced({
    this.message = 'Sincronizado correctamente.',
  }) : synced = true,
       queued = false;

  const OfflineActionResult.queued({
    this.message = 'Guardado sin conexión. Se sincronizará automáticamente.',
  }) : synced = false,
       queued = true;
}

class OfflineUploadFile {
  final String field;
  final String path;
  final String? filename;

  const OfflineUploadFile({
    required this.field,
    required this.path,
    this.filename,
  });
}

typedef OfflineErrorParser = String Function(String body, int statusCode);

class OfflineSyncService {
  static const String _queueKey = 'offline_sync_queue_v1';
  static const Duration _requestTimeout = Duration(seconds: 15);

  static final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  static final ValueNotifier<int> failedCount = ValueNotifier<int>(0);
  static final ValueNotifier<String?> announcements = ValueNotifier<String?>(
    null,
  );

  static bool _initialized = false;
  static bool _flushing = false;
  static Timer? _timer;
  static final Random _random = Random();

  static Future<void> initialize() async {
    if (!_initialized) {
      _initialized = true;
      _timer ??= Timer.periodic(const Duration(seconds: 25), (_) {
        unawaited(flushPending());
      });
    }

    await _refreshCounts();
  }

  static void dispose() {
    _timer?.cancel();
    _timer = null;
    _initialized = false;
  }

  static void dismissAnnouncement() {
    announcements.value = null;
  }

  static String _queuedRetryMessage(String detail) {
    final trimmed = detail.trim();
    if (trimmed.isEmpty) {
      return 'Guardado pendiente. Se sincronizara automaticamente.';
    }

    final lower = trimmed.toLowerCase();
    final looksLikeConnectivityIssue =
        lower.contains('sin conexión') ||
        lower.contains('sin conexion') ||
        lower.contains('no fue posible conectar') ||
        lower.contains('tiempo de espera');

    if (looksLikeConnectivityIssue) {
      return 'Guardado sin conexión. Se sincronizará automáticamente.';
    }

    return 'Guardado pendiente por error del servidor. Se reintentará automáticamente.\n$trimmed';
  }

  static Future<OfflineActionResult> submitJson({
    required String label,
    required String method,
    required Uri uri,
    required Map<String, dynamic> body,
    String? requestId,
    String? dependsOnOperationId,
    Set<int> successCodes = const {200, 201},
    OfflineErrorParser? errorParser,
    bool announceOnQueue = true,
  }) async {
    await initialize();

    final ownerKey = await AuthService.getSessionOwnerKey();
    if (ownerKey == null || ownerKey.isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }

    final effectiveRequestId =
        _normalizeOperationId(requestId) ?? _newRequestId();
    final dependencyId = _normalizeOperationId(dependsOnOperationId);

    if (dependencyId != null) {
      final queue = await _loadQueue();
      final dependency = _findDependency(
        queue,
        ownerKey: ownerKey,
        dependencyId: dependencyId,
      );

      if (dependency != null) {
        if (dependency.state == _QueuedOperationState.failed) {
          throw Exception(
            'No se pudo sincronizar el registro padre requerido.',
          );
        }

        final op = _QueuedOperation(
          id: effectiveRequestId,
          ownerKey: ownerKey,
          label: label,
          method: method.toUpperCase(),
          url: uri.toString(),
          mode: 'json',
          dependsOnOperationId: dependencyId,
          body: body,
          fields: const <String, String>{},
          files: const <_QueuedUploadFile>[],
          successCodes: successCodes.toList()..sort(),
          attempts: 0,
          createdAt: DateTime.now().toUtc(),
          nextAttemptAt: null,
          state: _QueuedOperationState.pending,
          lastError: null,
        );

        await _appendOperation(op);
        if (announceOnQueue) {
          _announce('Guardado sin conexión. Se sincronizará automáticamente.');
        }
        return const OfflineActionResult.queued();
      }
    }

    try {
      await _performJsonRequest(
        requestId: effectiveRequestId,
        method: method,
        uri: uri,
        body: body,
        successCodes: successCodes,
        errorParser: errorParser,
      );
      await _removeOperationById(
        ownerKey: ownerKey,
        operationId: effectiveRequestId,
      );
      unawaited(flushPending());
      return const OfflineActionResult.synced();
    } on _RetryableSyncException catch (e) {
      final queuedMessage = _queuedRetryMessage(e.message);
      final op = _QueuedOperation(
        id: effectiveRequestId,
        ownerKey: ownerKey,
        label: label,
        method: method.toUpperCase(),
        url: uri.toString(),
        mode: 'json',
        dependsOnOperationId: dependencyId,
        body: body,
        fields: const <String, String>{},
        files: const <_QueuedUploadFile>[],
        successCodes: successCodes.toList()..sort(),
        attempts: 0,
        createdAt: DateTime.now().toUtc(),
        nextAttemptAt: null,
        state: _QueuedOperationState.pending,
        lastError: e.message,
      );

      await _appendOperation(op);
      if (announceOnQueue) {
        _announce(queuedMessage);
      }
      return OfflineActionResult.queued(message: queuedMessage);
    } on _PermanentSyncException catch (e) {
      throw Exception(e.message);
    }
  }

  static Future<OfflineActionResult> submitMultipart({
    required String label,
    required String method,
    required Uri uri,
    required Map<String, String> fields,
    List<OfflineUploadFile> files = const <OfflineUploadFile>[],
    String? requestId,
    String? dependsOnOperationId,
    Set<int> successCodes = const {200, 201},
    OfflineErrorParser? errorParser,
    bool announceOnQueue = true,
  }) async {
    await initialize();

    final ownerKey = await AuthService.getSessionOwnerKey();
    if (ownerKey == null || ownerKey.isEmpty) {
      throw Exception('Sesión inválida. Vuelve a iniciar sesión.');
    }

    final effectiveRequestId =
        _normalizeOperationId(requestId) ?? _newRequestId();
    final dependencyId = _normalizeOperationId(dependsOnOperationId);

    if (dependencyId != null) {
      final queue = await _loadQueue();
      final dependency = _findDependency(
        queue,
        ownerKey: ownerKey,
        dependencyId: dependencyId,
      );

      if (dependency != null) {
        if (dependency.state == _QueuedOperationState.failed) {
          throw Exception(
            'No se pudo sincronizar el registro padre requerido.',
          );
        }

        final storedFiles = await _stashFilesForQueue(
          effectiveRequestId,
          files,
        );
        final op = _QueuedOperation(
          id: effectiveRequestId,
          ownerKey: ownerKey,
          label: label,
          method: method.toUpperCase(),
          url: uri.toString(),
          mode: 'multipart',
          dependsOnOperationId: dependencyId,
          body: const <String, dynamic>{},
          fields: fields,
          files: storedFiles,
          successCodes: successCodes.toList()..sort(),
          attempts: 0,
          createdAt: DateTime.now().toUtc(),
          nextAttemptAt: null,
          state: _QueuedOperationState.pending,
          lastError: null,
        );

        await _appendOperation(op);
        if (announceOnQueue) {
          _announce('Guardado sin conexión. Se sincronizará automáticamente.');
        }
        return const OfflineActionResult.queued();
      }
    }

    try {
      await _performMultipartRequest(
        requestId: effectiveRequestId,
        method: method,
        uri: uri,
        fields: fields,
        files: files,
        successCodes: successCodes,
        errorParser: errorParser,
      );
      await _removeOperationById(
        ownerKey: ownerKey,
        operationId: effectiveRequestId,
      );
      unawaited(flushPending());
      return const OfflineActionResult.synced();
    } on _RetryableSyncException catch (e) {
      final queuedMessage = _queuedRetryMessage(e.message);
      final storedFiles = await _stashFilesForQueue(effectiveRequestId, files);
      final op = _QueuedOperation(
        id: effectiveRequestId,
        ownerKey: ownerKey,
        label: label,
        method: method.toUpperCase(),
        url: uri.toString(),
        mode: 'multipart',
        dependsOnOperationId: dependencyId,
        body: const <String, dynamic>{},
        fields: fields,
        files: storedFiles,
        successCodes: successCodes.toList()..sort(),
        attempts: 0,
        createdAt: DateTime.now().toUtc(),
        nextAttemptAt: null,
        state: _QueuedOperationState.pending,
        lastError: e.message,
      );

      await _appendOperation(op);
      if (announceOnQueue) {
        _announce(queuedMessage);
      }
      return OfflineActionResult.queued(message: queuedMessage);
    } on _PermanentSyncException catch (e) {
      throw Exception(e.message);
    }
  }

  static Future<void> flushPending({
    bool announceWhenDone = true,
    bool force = false,
    bool announceSkipped = false,
  }) async {
    if (_flushing) {
      if (announceSkipped) {
        _announce('Ya hay una sincronización en curso.');
      }
      return;
    }
    _flushing = true;

    try {
      final ownerKey = await AuthService.getSessionOwnerKey();
      final token = await AuthService.getToken();
      if (ownerKey == null ||
          ownerKey.isEmpty ||
          token == null ||
          token.isEmpty) {
        await _refreshCounts();
        if (announceSkipped) {
          _announce('Sesión inválida. Vuelve a iniciar sesión.');
        }
        return;
      }

      final queue = await _loadQueue();
      if (queue.isEmpty) {
        await _refreshCounts();
        if (announceSkipped) {
          _announce('No hay registros pendientes por sincronizar.');
        }
        return;
      }

      final now = DateTime.now().toUtc();
      var synced = 0;
      var changed = false;
      final nextQueue = <_QueuedOperation>[];
      final completedIds = <String>{};
      final failedIds = <String>{};
      var retryableCount = 0;
      var deferredCount = 0;
      var ownerPendingCount = 0;
      var ownerFailedCount = 0;
      String? firstRetryableMessage;

      for (final op in queue) {
        if (op.ownerKey != ownerKey) continue;
        if (op.state == _QueuedOperationState.failed) {
          ownerFailedCount += 1;
        } else {
          ownerPendingCount += 1;
        }
      }

      for (final op in queue) {
        if (op.ownerKey != ownerKey) {
          nextQueue.add(op);
          continue;
        }

        if (op.state == _QueuedOperationState.failed) {
          failedIds.add(op.id);
          nextQueue.add(op);
          continue;
        }

        final dependencyId = op.dependsOnOperationId;
        if (dependencyId != null && dependencyId.isNotEmpty) {
          if (!completedIds.contains(dependencyId)) {
            final dependency = _findDependency(
              queue,
              ownerKey: ownerKey,
              dependencyId: dependencyId,
            );

            if (failedIds.contains(dependencyId) ||
                dependency?.state == _QueuedOperationState.failed) {
              changed = true;
              failedIds.add(op.id);
              nextQueue.add(
                op.copyWith(
                  state: _QueuedOperationState.failed,
                  nextAttemptAt: null,
                  lastError:
                      'No se pudo sincronizar el registro padre requerido.',
                ),
              );
              continue;
            }

            if (dependency != null) {
              nextQueue.add(op);
              continue;
            }
          }
        }

        final nextAttemptAt = op.nextAttemptAt;
        if (!force && nextAttemptAt != null && nextAttemptAt.isAfter(now)) {
          deferredCount += 1;
          nextQueue.add(op);
          continue;
        }

        try {
          await _performQueuedOperation(op);
          synced += 1;
          changed = true;
          completedIds.add(op.id);
          await _cleanupOperationArtifacts(op);
        } on _RetryableSyncException catch (e) {
          changed = true;
          retryableCount += 1;
          firstRetryableMessage ??= e.message;
          nextQueue.add(
            op.copyWith(
              attempts: op.attempts + 1,
              nextAttemptAt: now.add(_retryDelay(op.attempts + 1)),
              state: _QueuedOperationState.pending,
              lastError: e.message,
            ),
          );
        } on _PermanentSyncException catch (e) {
          changed = true;
          failedIds.add(op.id);
          nextQueue.add(
            op.copyWith(
              state: _QueuedOperationState.failed,
              nextAttemptAt: null,
              lastError: e.message,
            ),
          );
        }
      }

      if (changed) {
        await _saveQueue(nextQueue);
      }

      await _refreshCounts();

      if (synced > 0 && announceWhenDone) {
        final suffix = synced == 1
            ? 'registro pendiente.'
            : 'registros pendientes.';
        _announce('Se sincronizaron $synced $suffix');
      } else if (announceSkipped) {
        if (retryableCount > 0) {
          final message = firstRetryableMessage?.trim() ?? '';
          if (message.isNotEmpty) {
            _announce('$message Se reintentará automáticamente.');
          } else {
            _announce(
              'No fue posible sincronizar por ahora. Se reintentará automáticamente.',
            );
          }
        } else if (deferredCount > 0) {
          _announce('Todavía no toca el siguiente reintento automático.');
        } else if (ownerPendingCount <= 0 && ownerFailedCount > 0) {
          _announce(
            'Hay registros con error que requieren revisión antes de sincronizar.',
          );
        } else if (ownerPendingCount <= 0) {
          _announce('No hay registros pendientes por sincronizar.');
        }
      }
    } finally {
      _flushing = false;
    }
  }

  static Future<List<Map<String, dynamic>>> loadQueueSnapshot() async {
    final queue = await _loadQueue();
    return queue.map((op) => op.toJson()).toList();
  }

  static Future<void> discardOperation({
    required String ownerKey,
    required String operationId,
  }) async {
    final queue = await _loadQueue();
    final idsToRemove = <String>{operationId};

    var changed = true;
    while (changed) {
      changed = false;
      for (final item in queue) {
        if (item.ownerKey != ownerKey) continue;
        final dependencyId = item.dependsOnOperationId;
        if (dependencyId == null || dependencyId.isEmpty) continue;
        if (idsToRemove.contains(item.id)) continue;
        if (idsToRemove.contains(dependencyId)) {
          idsToRemove.add(item.id);
          changed = true;
        }
      }
    }

    final toCleanup = queue
        .where((item) => item.ownerKey == ownerKey && idsToRemove.contains(item.id))
        .toList();

    if (toCleanup.isEmpty) return;

    final nextQueue = queue
        .where((item) => !(item.ownerKey == ownerKey && idsToRemove.contains(item.id)))
        .toList();

    await _saveQueue(nextQueue);

    for (final item in toCleanup) {
      await _cleanupOperationArtifacts(item);
    }

    await _refreshCounts();
  }

  static Future<void> _appendOperation(_QueuedOperation op) async {
    final queue = await _loadQueue();
    final index = queue.indexWhere(
      (item) => item.id == op.id && item.ownerKey == op.ownerKey,
    );
    if (index >= 0) {
      queue[index] = op;
    } else {
      queue.add(op);
    }
    await _saveQueue(queue);
    await _refreshCounts();
  }

  static Future<void> _removeOperationById({
    required String ownerKey,
    required String operationId,
  }) async {
    final queue = await _loadQueue();
    final nextQueue = queue
        .where((item) => !(item.ownerKey == ownerKey && item.id == operationId))
        .toList();

    if (nextQueue.length == queue.length) return;

    await _saveQueue(nextQueue);
    await _refreshCounts();
  }

  static Future<void> _refreshCounts() async {
    final queue = await _loadQueue();
    pendingCount.value = queue
        .where((op) => op.state == _QueuedOperationState.pending)
        .length;
    failedCount.value = queue
        .where((op) => op.state == _QueuedOperationState.failed)
        .length;
  }

  static Future<List<_QueuedOperation>> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.trim().isEmpty) return <_QueuedOperation>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <_QueuedOperation>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                _QueuedOperation.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      return <_QueuedOperation>[];
    }
  }

  static Future<void> _saveQueue(List<_QueuedOperation> queue) async {
    final prefs = await SharedPreferences.getInstance();
    if (queue.isEmpty) {
      await prefs.remove(_queueKey);
      return;
    }

    final payload = jsonEncode(queue.map((op) => op.toJson()).toList());
    await prefs.setString(_queueKey, payload);
  }

  static Future<void> _performQueuedOperation(_QueuedOperation op) async {
    if (op.mode == 'multipart') {
      await _performMultipartRequest(
        requestId: op.id,
        method: op.method,
        uri: Uri.parse(op.url),
        fields: op.fields,
        files: op.files
            .map(
              (file) => OfflineUploadFile(
                field: file.field,
                path: file.path,
                filename: file.filename,
              ),
            )
            .toList(),
        successCodes: op.successCodes.toSet(),
      );
      return;
    }

    await _performJsonRequest(
      requestId: op.id,
      method: op.method,
      uri: Uri.parse(op.url),
      body: op.body,
      successCodes: op.successCodes.toSet(),
    );
  }

  static Future<void> _performJsonRequest({
    required String requestId,
    required String method,
    required Uri uri,
    required Map<String, dynamic> body,
    required Set<int> successCodes,
    OfflineErrorParser? errorParser,
  }) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw const _PermanentSyncException(
        'Sesión inválida. Vuelve a iniciar sesión.',
      );
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Client-Request-Id': requestId,
    };

    try {
      final upperMethod = method.toUpperCase();
      late final http.Response response;

      switch (upperMethod) {
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(_requestTimeout);
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: jsonEncode(body))
              .timeout(_requestTimeout);
          break;
        case 'PATCH':
          response = await http
              .patch(uri, headers: headers, body: jsonEncode(body))
              .timeout(_requestTimeout);
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers, body: jsonEncode(body))
              .timeout(_requestTimeout);
          break;
        default:
          throw _PermanentSyncException(
            'Método HTTP no soportado: $upperMethod',
          );
      }

      _handleResponse(
        response: response,
        successCodes: successCodes,
        errorParser: errorParser,
      );
    } on TimeoutException {
      throw const _RetryableSyncException(
        'Tiempo de espera agotado al sincronizar.',
      );
    } on SocketException {
      throw const _RetryableSyncException('Sin conexión disponible.');
    } on http.ClientException {
      throw const _RetryableSyncException(
        'No fue posible conectar con el servidor.',
      );
    }
  }

  static Future<void> _performMultipartRequest({
    required String requestId,
    required String method,
    required Uri uri,
    required Map<String, String> fields,
    required List<OfflineUploadFile> files,
    required Set<int> successCodes,
    OfflineErrorParser? errorParser,
  }) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw const _PermanentSyncException(
        'Sesión inválida. Vuelve a iniciar sesión.',
      );
    }

    final request = http.MultipartRequest(method.toUpperCase(), uri);
    request.headers.addAll(<String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Client-Request-Id': requestId,
    });
    request.fields.addAll(fields);

    for (final file in files) {
      final ioFile = File(file.path);
      if (!await ioFile.exists()) {
        throw _PermanentSyncException(
          'No se encontró un archivo pendiente para sincronizar: ${file.path}',
        );
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          file.field,
          file.path,
          filename: file.filename ?? p.basename(file.path),
        ),
      );
    }

    try {
      final streamed = await request.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamed);
      _handleResponse(
        response: response,
        successCodes: successCodes,
        errorParser: errorParser,
      );
    } on TimeoutException {
      throw const _RetryableSyncException(
        'Tiempo de espera agotado al sincronizar.',
      );
    } on SocketException {
      throw const _RetryableSyncException('Sin conexión disponible.');
    } on http.ClientException {
      throw const _RetryableSyncException(
        'No fue posible conectar con el servidor.',
      );
    }
  }

  static void _handleResponse({
    required http.Response response,
    required Set<int> successCodes,
    OfflineErrorParser? errorParser,
  }) {
    if (successCodes.contains(response.statusCode)) return;

    final baseMessage = errorParser != null
        ? errorParser(response.body, response.statusCode)
        : _defaultErrorMessage(response.body, response.statusCode);
    final message = _decorateHttpError(
      baseMessage: baseMessage,
      response: response,
    );

    if (response.statusCode == 408 ||
        response.statusCode == 425 ||
        response.statusCode == 429 ||
        response.statusCode >= 500) {
      throw _RetryableSyncException(message);
    }

    throw _PermanentSyncException(message);
  }

  static String _defaultErrorMessage(String body, int statusCode) {
    try {
      final raw = jsonDecode(body);
      if (raw is Map<String, dynamic>) {
        final message = (raw['message'] ?? '').toString().trim();
        if (message.isNotEmpty) return message;

        final errors = raw['errors'];
        if (errors is Map) {
          final buffer = StringBuffer();
          errors.forEach((_, value) {
            if (value is List && value.isNotEmpty) {
              buffer.writeln('• ${value.first}');
            }
          });
          final text = buffer.toString().trim();
          if (text.isNotEmpty) return text;
        }
      }
    } catch (_) {}

    return 'Error HTTP $statusCode';
  }

  static String _decorateHttpError({
    required String baseMessage,
    required http.Response response,
  }) {
    final trimmedBase = baseMessage.trim().isEmpty
        ? 'Error HTTP ${response.statusCode}'
        : baseMessage.trim();

    final buffer = StringBuffer(trimmedBase);
    final location = response.headers['location']?.trim();
    final contentType = response.headers['content-type']?.trim() ?? '';

    if (response.statusCode >= 300 && response.statusCode < 400) {
      if (location != null && location.isNotEmpty) {
        buffer.write(' Redirección a: $location');
      } else {
        buffer.write(' El servidor respondió con una redirección.');
      }
    }

    final looksLikeHtml =
        contentType.toLowerCase().contains('text/html') ||
        response.body.toLowerCase().contains('<html') ||
        response.body.toLowerCase().contains('<!doctype html');

    if (looksLikeHtml) {
      buffer.write(' El servidor devolvió HTML en lugar de JSON.');
    }

    return buffer.toString();
  }

  static Future<List<_QueuedUploadFile>> _stashFilesForQueue(
    String requestId,
    List<OfflineUploadFile> files,
  ) async {
    if (files.isEmpty) return const <_QueuedUploadFile>[];

    final docsDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(
      p.join(docsDir.path, 'offline_sync', requestId),
    );
    await targetDir.create(recursive: true);

    final out = <_QueuedUploadFile>[];
    for (var index = 0; index < files.length; index += 1) {
      final source = File(files[index].path);
      if (!await source.exists()) {
        throw Exception(
          'No se pudo guardar un archivo para modo offline: ${files[index].path}',
        );
      }

      final filename = files[index].filename ?? p.basename(files[index].path);
      final safeName =
          '${index.toString().padLeft(2, '0')}_${filename.replaceAll(' ', '_')}';
      final destPath = p.join(targetDir.path, safeName);
      await source.copy(destPath);

      out.add(
        _QueuedUploadFile(
          field: files[index].field,
          path: destPath,
          filename: filename,
        ),
      );
    }

    return out;
  }

  static Future<void> _cleanupOperationArtifacts(_QueuedOperation op) async {
    if (op.files.isEmpty) return;

    final folderPath = p.dirname(op.files.first.path);
    final folder = Directory(folderPath);
    if (await folder.exists()) {
      await folder.delete(recursive: true);
    }
  }

  static Duration _retryDelay(int attempts) {
    if (attempts <= 1) return const Duration(seconds: 30);
    if (attempts == 2) return const Duration(minutes: 1);
    if (attempts == 3) return const Duration(minutes: 2);
    if (attempts == 4) return const Duration(minutes: 5);
    if (attempts == 5) return const Duration(minutes: 10);
    return const Duration(minutes: 20);
  }

  static String _newRequestId() {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final suffix = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'offline_$now$suffix';
  }

  static String newClientUuid() {
    String hex(int length) {
      const alphabet = '0123456789abcdef';
      final buffer = StringBuffer();
      for (var index = 0; index < length; index += 1) {
        buffer.write(alphabet[_random.nextInt(alphabet.length)]);
      }
      return buffer.toString();
    }

    return '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';
  }

  static String? _normalizeOperationId(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static _QueuedOperation? _findDependency(
    List<_QueuedOperation> queue, {
    required String ownerKey,
    required String dependencyId,
  }) {
    for (final item in queue) {
      if (item.ownerKey == ownerKey && item.id == dependencyId) {
        return item;
      }
    }
    return null;
  }

  static void _announce(String message) {
    announcements.value = message;
  }
}

enum _QueuedOperationState { pending, failed }

class _QueuedOperation {
  final String id;
  final String ownerKey;
  final String label;
  final String method;
  final String url;
  final String mode;
  final String? dependsOnOperationId;
  final Map<String, dynamic> body;
  final Map<String, String> fields;
  final List<_QueuedUploadFile> files;
  final List<int> successCodes;
  final int attempts;
  final DateTime createdAt;
  final DateTime? nextAttemptAt;
  final _QueuedOperationState state;
  final String? lastError;

  const _QueuedOperation({
    required this.id,
    required this.ownerKey,
    required this.label,
    required this.method,
    required this.url,
    required this.mode,
    required this.dependsOnOperationId,
    required this.body,
    required this.fields,
    required this.files,
    required this.successCodes,
    required this.attempts,
    required this.createdAt,
    required this.nextAttemptAt,
    required this.state,
    required this.lastError,
  });

  factory _QueuedOperation.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'];
    final rawCodes = json['success_codes'];

    return _QueuedOperation(
      id: (json['id'] ?? '').toString(),
      ownerKey: (json['owner_key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      method: (json['method'] ?? 'POST').toString().toUpperCase(),
      url: (json['url'] ?? '').toString(),
      mode: (json['mode'] ?? 'json').toString(),
      dependsOnOperationId:
          (json['depends_on_operation_id'] ?? '').toString().trim().isEmpty
          ? null
          : (json['depends_on_operation_id'] ?? '').toString(),
      body: json['body'] is Map
          ? Map<String, dynamic>.from(json['body'] as Map)
          : const <String, dynamic>{},
      fields: json['fields'] is Map
          ? Map<String, String>.from(
              (json['fields'] as Map).map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              ),
            )
          : const <String, String>{},
      files: rawFiles is List
          ? rawFiles
                .whereType<Map>()
                .map(
                  (file) => _QueuedUploadFile.fromJson(
                    Map<String, dynamic>.from(file),
                  ),
                )
                .toList()
          : const <_QueuedUploadFile>[],
      successCodes: rawCodes is List
          ? rawCodes
                .map((code) => int.tryParse(code.toString()) ?? 0)
                .where((code) => code > 0)
                .toList()
          : const <int>[200, 201],
      attempts: int.tryParse((json['attempts'] ?? '0').toString()) ?? 0,
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString())?.toUtc() ??
          DateTime.now().toUtc(),
      nextAttemptAt: DateTime.tryParse(
        (json['next_attempt_at'] ?? '').toString(),
      )?.toUtc(),
      state: (json['state'] ?? '') == 'failed'
          ? _QueuedOperationState.failed
          : _QueuedOperationState.pending,
      lastError: (json['last_error'] ?? '').toString().trim().isEmpty
          ? null
          : (json['last_error'] ?? '').toString(),
    );
  }

  _QueuedOperation copyWith({
    int? attempts,
    DateTime? nextAttemptAt,
    _QueuedOperationState? state,
    String? lastError,
  }) {
    return _QueuedOperation(
      id: id,
      ownerKey: ownerKey,
      label: label,
      method: method,
      url: url,
      mode: mode,
      dependsOnOperationId: dependsOnOperationId,
      body: body,
      fields: fields,
      files: files,
      successCodes: successCodes,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt,
      nextAttemptAt: nextAttemptAt,
      state: state ?? this.state,
      lastError: lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'owner_key': ownerKey,
      'label': label,
      'method': method,
      'url': url,
      'mode': mode,
      'depends_on_operation_id': dependsOnOperationId,
      'body': body,
      'fields': fields,
      'files': files.map((file) => file.toJson()).toList(),
      'success_codes': successCodes,
      'attempts': attempts,
      'created_at': createdAt.toIso8601String(),
      'next_attempt_at': nextAttemptAt?.toIso8601String(),
      'state': state == _QueuedOperationState.failed ? 'failed' : 'pending',
      'last_error': lastError,
    };
  }
}

class _QueuedUploadFile {
  final String field;
  final String path;
  final String? filename;

  const _QueuedUploadFile({
    required this.field,
    required this.path,
    required this.filename,
  });

  factory _QueuedUploadFile.fromJson(Map<String, dynamic> json) {
    return _QueuedUploadFile(
      field: (json['field'] ?? '').toString(),
      path: (json['path'] ?? '').toString(),
      filename: (json['filename'] ?? '').toString().trim().isEmpty
          ? null
          : (json['filename'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'field': field,
      'path': path,
      'filename': filename,
    };
  }
}

class _RetryableSyncException implements Exception {
  final String message;

  const _RetryableSyncException(this.message);
}

class _PermanentSyncException implements Exception {
  final String message;

  const _PermanentSyncException(this.message);
}
