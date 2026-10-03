import '../core/network/api_client.dart';
import '../core/network/api_parsing.dart';
import '../models/attachment_model.dart';

/// Files attached to a task.
///
/// `/attachments/` has no server-side task filter yet, so the list is
/// narrowed here. Add `filterset_fields = ["task"]` to AttachmentViewSet
/// to make this cheaper.
class AttachmentService {
  static const int _maxPages = 10;

  static Future<List<AttachmentModel>> getForTask(int taskId) async {
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

    for (int page = 1; page <= _maxPages; page++) {
      final dynamic response = await ApiClient.get(
        '/attachments/${buildQuery(<String, dynamic>{
              'task': taskId,
              if (page > 1) 'page': page,
            })}',
      );

      rows.addAll(extractResults(response));

      if (nextPageUrl(response) == null) {
        break;
      }
    }

    return rows
        .map(AttachmentModel.fromJson)
        .where((AttachmentModel a) => a.task == taskId)
        .toList();
  }

  /// `uploaded_by` is filled in by the backend, so it is not sent.
  static Future<AttachmentModel> upload({
    required int taskId,
    required String filePath,
  }) async {
    final response = await ApiClient.postMultipart(
      '/attachments/',
      filePath: filePath,
      fields: <String, String>{'task': '$taskId'},
    );

    return AttachmentModel.fromJson(Map<String, dynamic>.from(response));
  }

  static Future<void> delete(int attachmentId) async {
    await ApiClient.delete('/attachments/$attachmentId/');
  }
}
