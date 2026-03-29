import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/job_config.dart';
import '../../core/protocol/models.dart';
import '../../core/ws/ws_client.dart';
import '../../core/ws/ws_event.dart';

enum JobPhase { queued, started, running, succeeded, failed, cancelled, timeout }

class ProgressState extends Equatable {
  final JobPhase phase;
  final String? jobId;
  final int iteration;
  final int maxIterations;
  final double? bestF;
  final List<double>? bestX;
  final List<double> historyBestF;
  final int elapsedMs;
  final int? queuePosition;
  final int? queueEtaMs;
  final JobResult? result;
  final String? errorMessage;

  const ProgressState({
    this.phase = JobPhase.queued,
    this.jobId,
    this.iteration = 0,
    this.maxIterations = 1,
    this.bestF,
    this.bestX,
    this.historyBestF = const [],
    this.elapsedMs = 0,
    this.queuePosition,
    this.queueEtaMs,
    this.result,
    this.errorMessage,
  });

  ProgressState copyWith({
    JobPhase? phase,
    String? jobId,
    int? iteration,
    int? maxIterations,
    double? bestF,
    List<double>? bestX,
    List<double>? historyBestF,
    int? elapsedMs,
    int? queuePosition,
    int? queueEtaMs,
    JobResult? result,
    String? errorMessage,
  }) {
    return ProgressState(
      phase: phase ?? this.phase,
      jobId: jobId ?? this.jobId,
      iteration: iteration ?? this.iteration,
      maxIterations: maxIterations ?? this.maxIterations,
      bestF: bestF ?? this.bestF,
      bestX: bestX ?? this.bestX,
      historyBestF: historyBestF ?? this.historyBestF,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      queuePosition: queuePosition ?? this.queuePosition,
      queueEtaMs: queueEtaMs ?? this.queueEtaMs,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  double get progress =>
      maxIterations > 0 ? iteration / maxIterations : 0;

  @override
  List<Object?> get props => [
        phase, jobId, iteration, maxIterations, bestF,
        historyBestF.length, elapsedMs, queuePosition, result, errorMessage,
      ];
}

class ProgressCubit extends Cubit<ProgressState> {
  final WsClient _ws;
  final JobConfig config;
  StreamSubscription? _sub;

  ProgressCubit(this._ws, this.config, {required String clientReqId})
      : super(const ProgressState()) {
    _sub = _ws.events.listen(_onEvent);
    _ws.submitJob(clientReqId: clientReqId, payload: config.toSubmitPayload());
  }

  void _onEvent(WsEvent event) {
    switch (event) {
      case WsJobAccepted(:final data):
        emit(state.copyWith(
          jobId: data.jobId,
          phase: JobPhase.queued,
          queuePosition: data.queue?.position,
          queueEtaMs: data.queue?.etaMs,
        ));
      case WsJobQueued(:final data):
        emit(state.copyWith(
          queuePosition: data.queue.position,
          queueEtaMs: data.queue.etaMs,
        ));
      case WsJobStarted(:final data):
        emit(state.copyWith(
          jobId: data.jobId,
          phase: JobPhase.started,
        ));
      case WsJobProgress(:final data):
        final newHistory = List<double>.from(state.historyBestF);
        if (data.progress.historyBestFTail != null) {
          for (final v in data.progress.historyBestFTail!) {
            if (newHistory.isEmpty || newHistory.last != v) {
              newHistory.add(v);
            }
          }
        } else {
          newHistory.add(data.progress.bestF);
        }
        emit(state.copyWith(
          phase: JobPhase.running,
          iteration: data.progress.iteration,
          maxIterations: data.progress.maxIterations,
          bestF: data.progress.bestF,
          bestX: data.progress.bestX,
          historyBestF: newHistory,
          elapsedMs: data.progress.elapsedMs,
        ));
      case WsJobResult(:final data):
        emit(state.copyWith(
          result: data,
          bestF: data.result.bestF,
          bestX: data.result.bestX,
          historyBestF: data.result.historyBestF,
        ));
      case WsJobFinished(:final data):
        final phase = switch (data.finalState) {
          'succeeded' => JobPhase.succeeded,
          'failed' => JobPhase.failed,
          'cancelled' => JobPhase.cancelled,
          'timeout' => JobPhase.timeout,
          _ => JobPhase.failed,
        };
        emit(state.copyWith(phase: phase));
      case WsError(:final error):
        emit(state.copyWith(
          phase: JobPhase.failed,
          errorMessage: error.message,
        ));
      default:
        break;
    }
  }

  void cancelJob() {
    final jobId = state.jobId;
    if (jobId == null) {
      emit(state.copyWith(
        phase: JobPhase.cancelled,
        errorMessage: 'Задача ещё не принята сервером',
      ));
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
