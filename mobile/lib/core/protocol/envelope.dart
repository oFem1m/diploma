import 'dart:convert';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

Map<String, dynamic> buildEnvelope({
  required String type,
  required Map<String, dynamic> payload,
  String? replyTo,
  String? clientReqId,
  String? jobId,
  String? spanId,
}) {
  return {
    'header': {
      'v': 1,
      'type': type,
      'msg_id': _uuid.v4(),
      'ts': DateTime.now().toUtc().toIso8601String(),
      'session_id': null,
      'reply_to': replyTo,
      'auth': {'scheme': 'none', 'token': null},
      'trace': {
        'client_req_id': clientReqId,
        'job_id': jobId,
        'span_id': spanId,
      },
      'stream': {
        'stream_id': null,
        'seq': null,
        'total': null,
        'is_last': null,
      },
      'compression': {'algo': 'none', 'original_bytes': null},
    },
    'payload': payload,
  };
}

Map<String, dynamic> parseEnvelope(String raw) {
  return jsonDecode(raw) as Map<String, dynamic>;
}

String getType(Map<String, dynamic> envelope) {
  return envelope['header']['type'] as String;
}

Map<String, dynamic> getPayload(Map<String, dynamic> envelope) {
  return envelope['payload'] as Map<String, dynamic>;
}

Map<String, dynamic> getTrace(Map<String, dynamic> envelope) {
  return envelope['header']['trace'] as Map<String, dynamic>;
}

String? getMsgId(Map<String, dynamic> envelope) {
  return envelope['header']['msg_id'] as String?;
}
