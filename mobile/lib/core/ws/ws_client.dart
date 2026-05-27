import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../protocol/envelope.dart';
import '../protocol/message_types.dart';
import '../protocol/models.dart';
import 'ws_event.dart';

class WsClient {
  WebSocketChannel? _channel;
  final _eventController = StreamController<WsEvent>.broadcast();
  Timer? _pingTimer;
  Timer? _pongTimeoutTimer;
  Timer? _reconnectTimer;
  Timer? _reconnectCountdownTimer;
  String? _host;
  int? _port;
  bool _intentionalClose = false;
  int _reconnectAttempts = 0;
  bool _isReconnecting = false;
  int _reconnectDelaySeconds = 0;
  int _reconnectRemainingSeconds = 0;
  bool _awaitingPong = false;
  final List<Map<String, dynamic>> _pendingEnvelopes = [];
  static const _maxReconnectDelay = 30;
  static const _pingIntervalSeconds = 5;
  static const _pongTimeoutSeconds = 10;

  Stream<WsEvent> get events => _eventController.stream;
  bool get isConnected => _channel != null;
  bool get isReconnecting => _isReconnecting;
  int get reconnectAttempt => _reconnectAttempts;
  int get reconnectDelaySeconds => _reconnectDelaySeconds;
  int get reconnectRemainingSeconds => _reconnectRemainingSeconds;

  Future<void> connect(String host, int port) async {
    _host = host;
    _port = port;
    _intentionalClose = false;
    _reconnectAttempts = 0;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    try {
      final uri = Uri.parse('ws://$_host:$_port/ws/optimize');
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _cancelReconnectTimers();
      _reconnectAttempts = 0;
      _eventController.add(WsConnected());

      _channel!.stream.listen(
        (data) => _onMessage(data as String),
        onDone: _onDone,
        onError: (e) => _onDone(),
      );

      _sendHello();
    } catch (e) {
      _channel = null;
      _eventController.add(WsDisconnected(reason: e.toString()));
      _scheduleReconnect();
    }
  }

  void _sendHello() {
    final envelope = buildEnvelope(
      type: MessageTypes.hello,
      payload: {
        'client': {
          'name': 'mobile-app',
          'version': '1.0.0',
          'platform': 'android',
          'lang': 'dart',
        },
        'wants': {'progress_stream': true, 'chunking': true},
      },
      clientReqId: 'hello-1',
    );
    send(envelope);
  }

  void _onMessage(String raw) {
    final envelope = parseEnvelope(raw);
    final type = getType(envelope);
    final payload = getPayload(envelope);

    switch (type) {
      case MessageTypes.hello:
        _eventController.add(WsHelloReceived(ServerHello.fromPayload(payload)));
        _flushPending();
        _startPing();
      case MessageTypes.ping:
        _sendRaw(buildEnvelope(type: MessageTypes.pong, payload: {}));
      case MessageTypes.jobAccepted:
        _eventController.add(WsJobAccepted(JobAccepted.fromPayload(payload)));
      case MessageTypes.jobQueued:
        _eventController.add(WsJobQueued(JobQueued.fromPayload(payload)));
      case MessageTypes.jobStarted:
        _eventController.add(WsJobStarted(JobStarted.fromPayload(payload)));
      case MessageTypes.jobProgress:
        _eventController.add(WsJobProgress(JobProgress.fromPayload(payload)));
      case MessageTypes.jobResult:
        _eventController.add(WsJobResult(JobResult.fromPayload(payload)));
      case MessageTypes.jobFinished:
        _eventController.add(WsJobFinished(JobFinished.fromPayload(payload)));
      case MessageTypes.jobStatus:
        _eventController.add(WsJobStatus(JobStatus.fromPayload(payload)));
      case MessageTypes.error:
        _eventController.add(WsError(ProtocolError.fromPayload(payload)));
      case MessageTypes.pong:
        _awaitingPong = false;
        _pongTimeoutTimer?.cancel();
        _eventController.add(WsPong());
    }
  }

  void _onDone() {
    if (_channel == null) return;
    _channel = null;
    _pingTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    _awaitingPong = false;
    if (!_intentionalClose) {
      _eventController.add(WsDisconnected(reason: 'Connection lost'));
      _scheduleReconnect();
    } else {
      _eventController.add(WsDisconnected());
    }
  }

  void _scheduleReconnect() {
    if (_intentionalClose || _host == null) return;
    _cancelReconnectTimers();
    _reconnectAttempts++;
    final delay = _reconnectDelay();
    var remaining = delay;
    _isReconnecting = true;
    _reconnectDelaySeconds = delay;
    _reconnectRemainingSeconds = remaining;
    _eventController.add(
      WsReconnectScheduled(
        attempt: _reconnectAttempts,
        delaySeconds: delay,
        remainingSeconds: remaining,
      ),
    );
    _reconnectCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      remaining--;
      if (remaining <= 0) {
        timer.cancel();
        return;
      }
      _reconnectRemainingSeconds = remaining;
      _eventController.add(
        WsReconnectTick(
          attempt: _reconnectAttempts,
          delaySeconds: delay,
          remainingSeconds: remaining,
        ),
      );
    });
    _reconnectTimer = Timer(Duration(seconds: delay), _doConnect);
  }

  int _reconnectDelay() {
    final delay = 1 << (_reconnectAttempts - 1);
    return delay > _maxReconnectDelay ? _maxReconnectDelay : delay;
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: _pingIntervalSeconds), (
      _,
    ) {
      _sendPing();
    });
    _sendPing();
  }

  void _startPongTimeout() {
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = Timer(const Duration(seconds: _pongTimeoutSeconds), () {
      _handleConnectionLost('Ping timeout');
    });
  }

  void _sendPing() {
    if (_channel == null || _awaitingPong) return;
    _awaitingPong = true;
    send(buildEnvelope(type: MessageTypes.ping, payload: {}));
    _startPongTimeout();
  }

  void _handleConnectionLost(String reason) {
    if (_channel == null || _intentionalClose) return;
    _channel?.sink.close();
    _channel = null;
    _pingTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    _awaitingPong = false;
    _eventController.add(WsDisconnected(reason: reason));
    _scheduleReconnect();
  }

  void send(Map<String, dynamic> envelope) {
    if (_channel == null) {
      _pendingEnvelopes.add(envelope);
      return;
    }
    _sendRaw(envelope);
  }

  void _sendRaw(Map<String, dynamic> envelope) {
    try {
      _channel?.sink.add(jsonEncode(envelope));
    } catch (_) {
      _handleConnectionLost('Connection lost');
    }
  }

  void _flushPending() {
    if (_channel == null || _pendingEnvelopes.isEmpty) return;
    final pending = List<Map<String, dynamic>>.from(_pendingEnvelopes);
    _pendingEnvelopes.clear();
    for (final envelope in pending) {
      _channel!.sink.add(jsonEncode(envelope));
    }
  }

  void _cancelReconnectTimers() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectCountdownTimer?.cancel();
    _reconnectCountdownTimer = null;
    _isReconnecting = false;
    _reconnectDelaySeconds = 0;
    _reconnectRemainingSeconds = 0;
  }

  void submitJob({
    required String clientReqId,
    required Map<String, dynamic> payload,
  }) {
    send(
      buildEnvelope(
        type: MessageTypes.jobSubmit,
        payload: payload,
        clientReqId: clientReqId,
      ),
    );
  }

  void removePendingByClientReqId(String clientReqId) {
    _pendingEnvelopes.removeWhere((envelope) {
      final header = envelope['header'] as Map<String, dynamic>?;
      final trace = header?['trace'] as Map<String, dynamic>?;
      return trace?['client_req_id'] == clientReqId;
    });
  }

  void cancelJob(String jobId, String clientReqId) {
    send(
      buildEnvelope(
        type: MessageTypes.cancel,
        payload: {'job_id': jobId, 'reason': 'user_cancel'},
        clientReqId: clientReqId,
        jobId: jobId,
      ),
    );
  }

  void requestStatus(String jobId, String clientReqId) {
    send(
      buildEnvelope(
        type: MessageTypes.jobStatusGet,
        payload: {'job_id': jobId},
        clientReqId: clientReqId,
        jobId: jobId,
      ),
    );
  }

  Future<void> disconnect() async {
    _intentionalClose = true;
    _pingTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    _awaitingPong = false;
    _cancelReconnectTimers();
    _pendingEnvelopes.clear();
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _intentionalClose = true;
    _pingTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    _awaitingPong = false;
    _cancelReconnectTimers();
    _pendingEnvelopes.clear();
    _channel?.sink.close();
    _eventController.close();
  }
}
