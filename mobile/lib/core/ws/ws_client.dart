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
  Timer? _reconnectTimer;
  String? _host;
  int? _port;
  bool _intentionalClose = false;
  int _reconnectAttempts = 0;
  static const _maxReconnectDelay = 30;

  Stream<WsEvent> get events => _eventController.stream;
  bool get isConnected => _channel != null;

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
      _eventController.add(WsConnected());
      _startPing();

      _channel!.stream.listen(
        (data) => _onMessage(data as String),
        onDone: _onDone,
        onError: (e) => _onDone(),
      );

      _sendHello();
    } catch (e) {
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
        'wants': {
          'progress_stream': true,
          'chunking': true,
        },
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
      case MessageTypes.jobAccepted:
        _eventController
            .add(WsJobAccepted(JobAccepted.fromPayload(payload)));
      case MessageTypes.jobQueued:
        _eventController.add(WsJobQueued(JobQueued.fromPayload(payload)));
      case MessageTypes.jobStarted:
        _eventController.add(WsJobStarted(JobStarted.fromPayload(payload)));
      case MessageTypes.jobProgress:
        _eventController
            .add(WsJobProgress(JobProgress.fromPayload(payload)));
      case MessageTypes.jobResult:
        _eventController.add(WsJobResult(JobResult.fromPayload(payload)));
      case MessageTypes.jobFinished:
        _eventController
            .add(WsJobFinished(JobFinished.fromPayload(payload)));
      case MessageTypes.error:
        _eventController
            .add(WsError(ProtocolError.fromPayload(payload)));
      case MessageTypes.pong:
        _eventController.add(WsPong());
    }
  }

  void _onDone() {
    _channel = null;
    _pingTimer?.cancel();
    if (!_intentionalClose) {
      _eventController.add(WsDisconnected(reason: 'Connection lost'));
      _scheduleReconnect();
    } else {
      _eventController.add(WsDisconnected());
    }
  }

  void _scheduleReconnect() {
    if (_intentionalClose || _host == null) return;
    _reconnectAttempts++;
    final delay = _reconnectDelay();
    _reconnectTimer = Timer(Duration(seconds: delay), _doConnect);
  }

  int _reconnectDelay() {
    final delay = 1 << (_reconnectAttempts - 1);
    return delay > _maxReconnectDelay ? _maxReconnectDelay : delay;
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_channel != null) {
        send(buildEnvelope(type: MessageTypes.ping, payload: {}));
      }
    });
  }

  void send(Map<String, dynamic> envelope) {
    _channel?.sink.add(jsonEncode(envelope));
  }

  void submitJob({
    required String clientReqId,
    required Map<String, dynamic> payload,
  }) {
    send(buildEnvelope(
      type: MessageTypes.jobSubmit,
      payload: payload,
      clientReqId: clientReqId,
    ));
  }

  void cancelJob(String jobId, String clientReqId) {
    send(buildEnvelope(
      type: MessageTypes.cancel,
      payload: {'job_id': jobId, 'reason': 'user_cancel'},
      clientReqId: clientReqId,
      jobId: jobId,
    ));
  }

  void requestStatus(String jobId, String clientReqId) {
    send(buildEnvelope(
      type: MessageTypes.jobStatusGet,
      payload: {'job_id': jobId},
      clientReqId: clientReqId,
      jobId: jobId,
    ));
  }

  Future<void> disconnect() async {
    _intentionalClose = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _intentionalClose = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _eventController.close();
  }
}
