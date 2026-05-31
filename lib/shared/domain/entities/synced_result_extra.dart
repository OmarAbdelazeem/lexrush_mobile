import 'package:lexrush/shared/application/services/backend_result_sync_service.dart';

class SyncedResultExtra {
  const SyncedResultExtra({required this.result, required this.syncHandle});

  final Object result;
  final BackendResultSyncHandle syncHandle;
}
