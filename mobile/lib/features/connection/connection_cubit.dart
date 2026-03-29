import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/protocol/models.dart';
import '../../core/ws/ws_client.dart';
import '../../core/ws/ws_event.dart';
import '../../storage/preferences.dart';

sealed class WsConnectionState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ConnectionDisconnected extends WsConnectionState {
  final List<Map<String, dynamic>> recentServers;
  ConnectionDisconnected({this.recentServers = const []});
  @override
  List<Object?> get props => [recentServers];
}

class ConnectionConnecting extends WsConnectionState {
  final String host;
  final int port;
  ConnectionConnecting(this.host, this.port);
  @override
  List<Object?> get props => [host, port];
}

class ConnectionConnected extends WsConnectionState {
  final ServerHello hello;
  ConnectionConnected(this.hello);
  @override
  List<Object?> get props => [hello];
}

class ConnectionError extends WsConnectionState {
  final String message;
  ConnectionError(this.message);
  @override
  List<Object?> get props => [message];
}

class ConnectionCubit extends Cubit<WsConnectionState> {
  final WsClient _ws;
  StreamSubscription? _sub;

  ConnectionCubit(this._ws) : super(ConnectionDisconnected()) {
    _loadRecent();
    _sub = _ws.events.listen(_onEvent);
  }

  Future<void> _loadRecent() async {
    final servers = await AppPreferences.getRecentServers();
    if (state is ConnectionDisconnected) {
      emit(ConnectionDisconnected(recentServers: servers));
    }
  }

  void _onEvent(WsEvent event) {
    switch (event) {
      case WsConnected():
        break;
      case WsHelloReceived(:final hello):
        emit(ConnectionConnected(hello));
      case WsDisconnected(:final reason):
        if (state is ConnectionConnecting || state is ConnectionConnected) {
          if (reason != null) {
            emit(ConnectionError(reason));
          } else {
            _loadRecent();
          }
        }
      case WsError(:final error):
        emit(ConnectionError(error.message));
      default:
        break;
    }
  }

  Future<void> connect(String host, int port) async {
    emit(ConnectionConnecting(host, port));
    try {
      await _ws.connect(host, port);
      await AppPreferences.addRecentServer(host, port);
    } catch (e) {
      emit(ConnectionError(e.toString()));
    }
  }

  Future<void> disconnect() async {
    await _ws.disconnect();
    _loadRecent();
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
