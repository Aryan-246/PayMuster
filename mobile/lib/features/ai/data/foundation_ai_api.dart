import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/tenant_api_client.dart';

/// Result of POST /ai/:operation — backend-authoritative; the mobile client
/// never fabricates an answer.
class AiAnalysisResult {
  const AiAnalysisResult({
    required this.analysis,
    required this.operation,
    required this.provider,
    required this.model,
    required this.generatedAt,
  });

  final String analysis;
  final String operation;
  final String provider;
  final String model;
  final DateTime generatedAt;

  factory AiAnalysisResult.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    final meta = metadata is Map<String, dynamic> ? metadata : <String, dynamic>{};
    final analysis = json['analysis'];
    if (analysis is! String || analysis.isEmpty) {
      throw const TenantApiException(
        'The AI service returned an empty analysis.',
        code: 'INVALID_RESPONSE',
      );
    }
    return AiAnalysisResult(
      analysis: analysis,
      operation: meta['operation'] is String ? meta['operation'] as String : '',
      provider: meta['provider'] is String ? meta['provider'] as String : '',
      model: meta['model'] is String ? meta['model'] as String : '',
      generatedAt: DateTime.tryParse(
            meta['generatedAt'] is String ? meta['generatedAt'] as String : '',
          ) ??
          DateTime.now(),
    );
  }
}

class FoundationAiApi {
  const FoundationAiApi(this._client);

  final TenantApiClient _client;

  /// [operation] is one of query / analyze / summary / insights. The backend
  /// is the only place prompts and data access are decided — this client just
  /// transports them.
  Future<AiAnalysisResult> submit(String operation, String prompt) async {
    final data = await _client.post('/ai/$operation', body: {'prompt': prompt});
    if (data is! Map<String, dynamic>) {
      throw const TenantApiException(
        'The AI service returned an unexpected response.',
        code: 'INVALID_RESPONSE',
      );
    }
    return AiAnalysisResult.fromJson(data);
  }
}

final foundationAiApiProvider = Provider<FoundationAiApi>((ref) {
  return FoundationAiApi(ref.watch(tenantApiClientProvider));
});
