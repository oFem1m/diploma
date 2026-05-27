import '../protocol/models.dart';

sealed class WsEvent {}

class WsConnected extends WsEvent {}

class WsDisconnected extends WsEvent {
  final String? reason;
  WsDisconnected({this.reason});
}

class WsReconnectScheduled extends WsEvent {
  final int attempt;
  final int delaySeconds;
  final int remainingSeconds;

  WsReconnectScheduled({
    required this.attempt,
    required this.delaySeconds,
    required this.remainingSeconds,
  });
}

class WsReconnectTick extends WsEvent {
  final int attempt;
  final int delaySeconds;
  final int remainingSeconds;

  WsReconnectTick({
    required this.attempt,
    required this.delaySeconds,
    required this.remainingSeconds,
  });
}

class WsHelloReceived extends WsEvent {
  final ServerHello hello;
  WsHelloReceived(this.hello);
}

class WsJobAccepted extends WsEvent {
  final JobAccepted data;
  WsJobAccepted(this.data);
}

class WsJobQueued extends WsEvent {
  final JobQueued data;
  WsJobQueued(this.data);
}

class WsJobStarted extends WsEvent {
  final JobStarted data;
  WsJobStarted(this.data);
}

class WsJobProgress extends WsEvent {
  final JobProgress data;
  WsJobProgress(this.data);
}

class WsJobResult extends WsEvent {
  final JobResult data;
  WsJobResult(this.data);
}

class WsJobFinished extends WsEvent {
  final JobFinished data;
  WsJobFinished(this.data);
}

class WsJobStatus extends WsEvent {
  final JobStatus data;
  WsJobStatus(this.data);
}

class WsError extends WsEvent {
  final ProtocolError error;
  WsError(this.error);
}

class WsPong extends WsEvent {}
