import '../core/network/api_client.dart';
import '../core/network/api_parsing.dart';
import '../models/project_message_model.dart';

/// The project discussion - one conversation per project, separate from
/// task comments.
class DiscussionService {
  static const int _maxPages = 20;

  static Future<List<ProjectMessageModel>> getMessages(int projectId) async {
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

    for (int page = 1; page <= _maxPages; page++) {
      final dynamic response = await ApiClient.get(
        '/project-messages/${buildQuery(<String, dynamic>{
              'project': projectId,
              if (page > 1) 'page': page,
            })}',
      );

      rows.addAll(extractResults(response));

      if (nextPageUrl(response) == null) {
        break;
      }
    }

    return rows.map(ProjectMessageModel.fromJson).toList();
  }

  /// Text only - the common case, and cheaper than multipart.
  static Future<ProjectMessageModel> send({
    required int projectId,
    required String text,
  }) async {
    final response = await ApiClient.post(
      '/project-messages/',
      body: <String, dynamic>{'project': projectId, 'text': text},
    );

    return ProjectMessageModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// With a file. [text] may be empty - the backend accepts a message
  /// that is just a file.
  static Future<ProjectMessageModel> sendWithFile({
    required int projectId,
    required String filePath,
    String text = '',
  }) async {
    final response = await ApiClient.postMultipart(
      '/project-messages/',
      filePath: filePath,
      fields: <String, String>{
        'project': '$projectId',
        'text': text,
      },
    );

    return ProjectMessageModel.fromJson(Map<String, dynamic>.from(response));
  }

  static Future<void> delete(int messageId) async {
    await ApiClient.delete('/project-messages/$messageId/');
  }
}
