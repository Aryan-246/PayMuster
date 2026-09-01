import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/tenant_api_client.dart';
import '../domain/worker.dart';

/// Real staff directory access via GET /api/v1/staff (+ /staff/:id). The
/// tenant scope, role permission (view_staff) and pagination are enforced
/// server-side; this repository only speaks the already-scoped API.
class WorkerRepository {
  const WorkerRepository(this._client);

  final TenantApiClient _client;

  /// First page of the roster (the API caps a page at 100 records).
  Future<List<Worker>> getWorkers({int page = 1}) async {
    final data = await _client.get('/staff', query: {
      'page': '$page',
      'limit': '100',
    });
    if (data is! List) {
      throw const TenantApiException(
        'The server returned invalid staff data.',
        code: 'INVALID_RESPONSE',
      );
    }
    return data
        .map((item) => Worker.fromJson(_map(item, 'staff')))
        .toList(growable: false);
  }

  Future<Worker> getWorker(String id) async {
    final data = await _client.get('/staff/$id');
    return Worker.fromJson(_map(data, 'staff'));
  }
}

Map<String, dynamic> _map(dynamic value, String field) {
  if (value is Map<String, dynamic>) return value;
  throw TenantApiException(
    'The server response contains invalid $field data.',
    code: 'INVALID_RESPONSE',
  );
}

final workerRepositoryProvider = Provider<WorkerRepository>((ref) {
  return WorkerRepository(ref.watch(tenantApiClientProvider));
});

final workersListProvider = FutureProvider<List<Worker>>((ref) {
  return ref.watch(workerRepositoryProvider).getWorkers();
});

final workerDetailProvider = FutureProvider.family<Worker, String>((ref, id) {
  return ref.watch(workerRepositoryProvider).getWorker(id);
});
