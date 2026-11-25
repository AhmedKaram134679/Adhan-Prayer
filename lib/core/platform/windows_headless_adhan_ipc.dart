import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:adhan_and_prayer/core/utils/logger.dart';

/// Result of sending a Stop command from the GUI process to a headless Adhan process.
enum HeadlessStopStatus {
  stopped,
  alreadyStopped,
  rejectedSessionMismatch,
  unreachable,
  timedOut,
  error,
}

class HeadlessStopResult {
  final HeadlessStopStatus status;
  final String? message;

  const HeadlessStopResult(this.status, {this.message});

  bool get isStoppedOrGone =>
      status == HeadlessStopStatus.stopped ||
      status == HeadlessStopStatus.alreadyStopped ||
      status == HeadlessStopStatus.unreachable;
}

/// Event-driven loopback IPC server hosted by the Windows headless `--play-adhan`
/// process so the interactive GUI process can reliably stop playback for a
/// specific session without polling or killing arbitrary processes.
class HeadlessAdhanControlServer {
  final String sessionId;
  final Future<void> Function() onStopRequested;

  ServerSocket? _server;
  bool _isStopped = false;
  bool _isClosed = false;
  final Completer<void> _stoppedCompleter = Completer<void>();

  HeadlessAdhanControlServer({
    required this.sessionId,
    required this.onStopRequested,
  });

  int get port => _server?.port ?? 0;
  bool get isRunning => _server != null && !_isClosed;
  bool get isStopped => _isStopped;

  /// Completes when a valid Stop command has finished stopping playback.
  Future<void> get onStopped => _stoppedCompleter.future;

  /// Starts listening on `127.0.0.1` with an OS-assigned ephemeral port.
  Future<int> start() async {
    if (_server != null) return _server!.port;
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(
      _handleClient,
      onError: (Object error, StackTrace stack) {
        AppLogger.warning('Headless IPC server error: $error', 'HEADLESS_IPC');
      },
    );
    AppLogger.info(
      'Headless IPC control server listening on 127.0.0.1:${_server!.port} for session $sessionId',
      'HEADLESS_IPC',
    );
    return _server!.port;
  }

  Future<void> _handleClient(Socket socket) async {
    try {
      final line = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 2));

      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        _writeResponse(socket, {'status': 'error', 'reason': 'invalid_payload'});
        return;
      }

      final action = decoded['action'];
      final requestedSessionId = decoded['sessionId'];

      if (action != 'stop' || requestedSessionId is! String || requestedSessionId.isEmpty) {
        _writeResponse(socket, {'status': 'error', 'reason': 'invalid_command'});
        return;
      }

      if (requestedSessionId != sessionId) {
        AppLogger.warning(
          'Headless IPC rejected stop for mismatched session "$requestedSessionId" (active: "$sessionId")',
          'HEADLESS_IPC',
        );
        _writeResponse(socket, {
          'status': 'rejected',
          'reason': 'session_mismatch',
          'sessionId': requestedSessionId,
        });
        return;
      }

      if (_isStopped) {
        _writeResponse(socket, {
          'status': 'already_stopped',
          'sessionId': sessionId,
        });
        return;
      }

      // Execute the actual playback stop BEFORE acknowledging success.
      _isStopped = true;
      await onStopRequested();

      _writeResponse(socket, {
        'status': 'stopped',
        'sessionId': sessionId,
      });
      await socket.flush();

      if (!_stoppedCompleter.isCompleted) {
        _stoppedCompleter.complete();
      }
    } catch (e) {
      AppLogger.warning('Headless IPC client handling error: $e', 'HEADLESS_IPC');
      try {
        _writeResponse(socket, {'status': 'error', 'reason': e.toString()});
      } catch (_) {}
    } finally {
      try {
        await socket.close();
      } catch (_) {}
    }
  }

  void _writeResponse(Socket socket, Map<String, dynamic> payload) {
    socket.writeln(jsonEncode(payload));
  }

  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    try {
      await _server?.close();
    } catch (_) {}
    _server = null;
  }
}

/// Client used by the interactive GUI process to send a targeted Stop command
/// to a specific headless Adhan playback session.
class HeadlessAdhanControlClient {
  HeadlessAdhanControlClient._();

  static Future<HeadlessStopResult> sendStop({
    required int port,
    required String sessionId,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (port <= 0 || sessionId.trim().isEmpty) {
      return const HeadlessStopResult(
        HeadlessStopStatus.error,
        message: 'Invalid port or sessionId',
      );
    }

    Socket? socket;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: timeout,
      );

      final request = jsonEncode({
        'action': 'stop',
        'sessionId': sessionId,
      });
      socket.writeln(request);
      await socket.flush();

      final responseLine = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(timeout);

      final decoded = jsonDecode(responseLine);
      if (decoded is Map) {
        final status = decoded['status'];
        if (status == 'stopped') {
          return const HeadlessStopResult(HeadlessStopStatus.stopped);
        }
        if (status == 'already_stopped') {
          return const HeadlessStopResult(HeadlessStopStatus.alreadyStopped);
        }
        if (status == 'rejected') {
          return HeadlessStopResult(
            HeadlessStopStatus.rejectedSessionMismatch,
            message: decoded['reason']?.toString(),
          );
        }
        return HeadlessStopResult(
          HeadlessStopStatus.error,
          message: decoded['reason']?.toString() ?? 'Unknown IPC error',
        );
      }

      return const HeadlessStopResult(
        HeadlessStopStatus.error,
        message: 'Malformed IPC response',
      );
    } on TimeoutException {
      return const HeadlessStopResult(
        HeadlessStopStatus.timedOut,
        message: 'Timed out waiting for headless playback confirmation',
      );
    } on SocketException catch (e) {
      return HeadlessStopResult(
        HeadlessStopStatus.unreachable,
        message: e.message,
      );
    } catch (e) {
      return HeadlessStopResult(
        HeadlessStopStatus.error,
        message: e.toString(),
      );
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
    }
  }
}
