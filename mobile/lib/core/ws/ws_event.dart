import '../protocol/models.dart';

sealed class WsEvent {}

class WsConnected extends WsEvent {}

class WsDisconnected extends WsEvent {
  final String? reason;
  WsDisconnected({this.reason});
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

class WsError extends WsEvent {
  final ProtocolError error;
  WsError(this.error);
}

class WsPong extends WsEvent {}
