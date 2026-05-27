import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/job_config.dart';
import '../../core/protocol/models.dart';
import '../../core/ws/ws_client.dart';
import '../../core/ws/ws_event.dart';

enum JobPhase {
  submitting,
  queued,
  started,
  running,
  succeeded,
  failed,
  cancelled,
  timeout,
}

class ProgressState extends Equatable {
  final JobPhase phase;
  final String? jobId;
  final int iteration;
  final int maxIterations;
  final double? bestF;
  final List<double>? bestX;
  final List<double> historyBestF;
  final List<double?> liveHistoryBestF;
  final List<List<double>> historyBestX;
  final int elapsedMs;
  final int? queuePosition;
  final int? queueEtaMs;
  final JobResult? result;
  final String? errorMessage;
  final bool isReconnecting;
  final int reconnectAttempt;
  final int reconnectDelaySeconds;
  final int reconnectRemainingSeconds;

  const ProgressState({
    this.phase = JobPhase.submitting,
    this.jobId,
    this.iteration = 0,
    this.maxIterations = 1,
    this.bestF,
    this.bestX,
    this.historyBestF = const [],
    this.liveHistoryBestF = const [],
    this.historyBestX = const [],
    this.elapsedMs = 0,
    this.queuePosition,
    this.queueEtaMs,
    this.result,
    this.errorMessage,
    this.isReconnecting = false,
    this.reconnectAttempt = 0,
    this.reconnectDelaySeconds = 0,
    this.reconnectRemainingSeconds = 0,
  });

  ProgressState copyWith({
    JobPhase? phase,
    String? jobId,
    int? iteration,
    int? maxIterations,
    double? bestF,
    List<double>? bestX,
    List<double>? historyBestF,
    List<double?>? liveHistoryBestF,
    List<List<double>>? historyBestX,
    int? elapsedMs,
    int? queuePosition,
    int? queueEtaMs,
    JobResult? result,
    String? errorMessage,
    bool? isReconnecting,
    int? reconnectAttempt,
    int? reconnectDelaySeconds,
    int? reconnectRemainingSeconds,
  }) {
    return ProgressState(
      phase: phase ?? this.phase,
      jobId: jobId ?? this.jobId,
      iteration: iteration ?? this.iteration,
      maxIterations: maxIterations ?? this.maxIterations,
      bestF: bestF ?? this.bestF,
      bestX: bestX ?? this.bestX,
      historyBestF: historyBestF ?? this.historyBestF,
      liveHistoryBestF: liveHistoryBestF ?? this.liveHistoryBestF,
      historyBestX: historyBestX ?? this.historyBestX,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      queuePosition: queuePosition ?? this.queuePosition,
      queueEtaMs: queueEtaMs ?? this.queueEtaMs,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      reconnectDelaySeconds:
          reconnectDelaySeconds ?? this.reconnectDelaySeconds,
      reconnectRemainingSeconds:
          reconnectRemainingSeconds ?? this.reconnectRemainingSeconds,
    );
  }

  double get progress => maxIterations > 0 ? iteration / maxIterations : 0;

  @override
  List<Object?> get props => [
    phase,
    jobId,
    iteration,
    maxIterations,
    bestF,
    historyBestF.length,
    liveHistoryBestF.length,
    historyBestX.length,
    elapsedMs,
    queuePosition,
    result,
    errorMessage,
    isReconnecting,
    reconnectAttempt,
    reconnectDelaySeconds,
    reconnectRemainingSeconds,
  ];
}

class ProgressCubit extends Cubit<ProgressState> {
  final WsClient _ws;
  final JobConfig config;
  final String _clientReqId;
  StreamSubscription? _sub;
  bool _hadConnectionGap = false;

  ProgressCubit(this._ws, this.config, {required String clientReqId})
    : _clientReqId = clientReqId,
      super(
        ProgressState(
          isReconnecting: _ws.isReconnecting,
          reconnectAttempt: _ws.reconnectAttempt,
          reconnectDelaySeconds: _ws.reconnectDelaySeconds,
          reconnectRemainingSeconds: _ws.reconnectRemainingSeconds,
        ),
      ) {
    _sub = _ws.events.listen(_onEvent);
    _ws.submitJob(clientReqId: clientReqId, payload: config.toSubmitPayload());
  }

  void _onEvent(WsEvent event) {
    switch (event) {
      case WsConnected():
        emit(state.copyWith(isReconnecting: false));
      case WsHelloReceived():
        emit(state.copyWith(isReconnecting: false));
        final jobId = state.jobId;
        if (jobId != null && !_isTerminal(state.phase)) {
          _ws.requestStatus(jobId, _clientReqId);
        }
      case WsReconnectScheduled(
        :final attempt,
        :final delaySeconds,
        :final remainingSeconds,
      ):
        _hadConnectionGap = true;
        emit(
          state.copyWith(
            isReconnecting: true,
            reconnectAttempt: attempt,
            reconnectDelaySeconds: delaySeconds,
            reconnectRemainingSeconds: remainingSeconds,
          ),
        );
      case WsReconnectTick(
        :final attempt,
        :final delaySeconds,
        :final remainingSeconds,
      ):
        emit(
          state.copyWith(
            isReconnecting: true,
            reconnectAttempt: attempt,
            reconnectDelaySeconds: delaySeconds,
            reconnectRemainingSeconds: remainingSeconds,
          ),
        );
      case WsJobAccepted(:final data):
        emit(
          state.copyWith(
            jobId: data.jobId,
            phase: JobPhase.queued,
            queuePosition: data.queue?.position,
            queueEtaMs: data.queue?.etaMs,
          ),
        );
      case WsJobQueued(:final data):
        emit(
          state.copyWith(
            queuePosition: data.queue.position,
            queueEtaMs: data.queue.etaMs,
          ),
        );
      case WsJobStarted(:final data):
        emit(state.copyWith(jobId: data.jobId, phase: JobPhase.started));
      case WsJobProgress(:final data):
        _emitProgress(data.progress);
      case WsJobResult(:final data):
        emit(
          state.copyWith(
            result: data,
            bestF: data.result.bestF,
            bestX: data.result.bestX,
            historyBestF: data.result.historyBestF,
          ),
        );
      case WsJobFinished(:final data):
        final phase = _phaseFromServerState(data.finalState);
        emit(state.copyWith(phase: phase));
      case WsJobStatus(:final data):
        final phase = _phaseFromServerState(data.state);
        if (data.progress != null) {
          _emitProgress(data.progress!, phase: phase);
        } else {
          emit(
            state.copyWith(
              jobId: data.jobId,
              phase: phase,
              queuePosition: data.queue?.position,
              queueEtaMs: data.queue?.etaMs,
            ),
          );
        }
      case WsError(:final error):
        emit(
          state.copyWith(phase: JobPhase.failed, errorMessage: error.message),
        );
      default:
        break;
    }
  }

  void _emitProgress(
    ProgressData progress, {
    JobPhase phase = JobPhase.running,
  }) {
    final previousIteration = state.iteration;
    final newHistory = List<double>.from(state.historyBestF);
    final newLiveHistory = List<double?>.from(state.liveHistoryBestF);
    if (progress.historyBestFTail != null) {
      final tail = progress.historyBestFTail!;
      final tailStartIteration = progress.iteration - tail.length + 1;
      if (_hadConnectionGap && state.iteration > 0) {
        final missedPoints = tailStartIteration - previousIteration - 1;
        if (missedPoints > 0) {
          newLiveHistory.addAll(List<double?>.filled(missedPoints, null));
        }
      }
      for (var i = 0; i < tail.length; i++) {
        final iteration = tailStartIteration + i;
        if (newHistory.isEmpty || iteration > previousIteration) {
          final v = tail[i];
          newHistory.add(v);
          newLiveHistory.add(v);
        }
      }
    } else if (progress.bestF != null &&
        (newHistory.isEmpty || progress.iteration > previousIteration)) {
      if (_hadConnectionGap && state.iteration > 0) {
        final missedPoints = progress.iteration - previousIteration - 1;
        if (missedPoints > 0) {
          newLiveHistory.addAll(List<double?>.filled(missedPoints, null));
        }
      }
      newHistory.add(progress.bestF!);
      newLiveHistory.add(progress.bestF!);
    }
    _hadConnectionGap = false;
    final newHistoryX = List<List<double>>.from(state.historyBestX);
    if (progress.bestX != null) {
      newHistoryX.add(List<double>.from(progress.bestX!));
    }
    emit(
      state.copyWith(
        phase: phase,
        iteration: progress.iteration,
        maxIterations: progress.maxIterations,
        bestF: progress.bestF,
        bestX: progress.bestX,
        historyBestF: newHistory,
        liveHistoryBestF: newLiveHistory,
        historyBestX: newHistoryX,
        elapsedMs: progress.elapsedMs,
      ),
    );
  }

  JobPhase _phaseFromServerState(String value) {
    return switch (value) {
      'queued' => JobPhase.queued,
      'started' => JobPhase.started,
      'running' => JobPhase.running,
      'succeeded' => JobPhase.succeeded,
      'failed' => JobPhase.failed,
      'cancelled' => JobPhase.cancelled,
      'timeout' => JobPhase.timeout,
      _ => JobPhase.failed,
    };
  }

  bool _isTerminal(JobPhase phase) {
    return phase == JobPhase.succeeded ||
        phase == JobPhase.failed ||
        phase == JobPhase.cancelled ||
        phase == JobPhase.timeout;
  }

  void cancelJob() {
    final jobId = state.jobId;
    if (jobId == null) {
      _ws.removePendingByClientReqId(_clientReqId);
      emit(
        state.copyWith(
          phase: JobPhase.cancelled,
          errorMessage: 'Задача ещё не принята сервером',
        ),
      );
      return;
    }
    _ws.cancelJob(jobId, 'cancel-$jobId');
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
