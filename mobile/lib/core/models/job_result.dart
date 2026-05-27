import 'dart:convert';
import '../protocol/models.dart';

class SavedJobResult {
  final int? id;
  final String jobId;
  final String method;
  final String objectiveName;
  final String objectiveKind;
  final int dims;
  final double bestF;
  final String status;
  final JobResultData? resultData;
  final ResultMetrics? metrics;
  final Map<String, dynamic>? config;
  final DateTime createdAt;

  SavedJobResult({
    this.id,
    required this.jobId,
    required this.method,
    required this.objectiveName,
    required this.objectiveKind,
    required this.dims,
    required this.bestF,
    required this.status,
    this.resultData,
    this.metrics,
    this.config,
    required this.createdAt,
  });

  Map<String, dynamic> toDbMap() => {
    if (id != null) 'id': id,
    'job_id': jobId,
    'method': method,
    'objective_name': objectiveName,
    'objective_kind': objectiveKind,
    'dims': dims,
    'best_f': bestF,
    'status': status,
    'result_json': resultData != null ? jsonEncode(resultData!.toJson()) : null,
    'metrics_json': metrics != null ? jsonEncode(metrics!.toJson()) : null,
    'config_json': config != null ? jsonEncode(config) : null,
    'created_at': createdAt.toIso8601String(),
  };

  factory SavedJobResult.fromDbMap(Map<String, dynamic> map) {
    return SavedJobResult(
      id: map['id'] as int?,
      jobId: map['job_id'] as String,
      method: map['method'] as String,
      objectiveName: map['objective_name'] as String,
      objectiveKind: map['objective_kind'] as String,
      dims: map['dims'] as int,
      bestF: (map['best_f'] as num).toDouble(),
      status: map['status'] as String,
      resultData: map['result_json'] != null
          ? JobResultData.fromJson(
              jsonDecode(map['result_json'] as String) as Map<String, dynamic>,
            )
          : null,
      metrics: map['metrics_json'] != null
          ? ResultMetrics.fromJson(
              jsonDecode(map['metrics_json'] as String) as Map<String, dynamic>,
            )
          : null,
      config: map['config_json'] != null
          ? jsonDecode(map['config_json'] as String) as Map<String, dynamic>
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  String get displayObjectiveName {
    if (objectiveKind == 'expression') {
      return 'Пользовательская функция';
    }
    return objectiveName;
  }

  String? get expression {
    final objective = config?['objective'];
    if (objective is Map<String, dynamic>) {
      return objective['expr'] as String?;
    }
    if (objective is Map) {
      return objective['expr'] as String?;
    }
    return null;
  }
}
