import '../core/network/api_client.dart';
import '../core/network/api_parsing.dart';
import '../models/assistant_message_model.dart';

/// The in-app assistant. Everything about the model, the key and the
/// prompt lives on the server - this only asks and listens.
class AssistantService {
  static Future<List<AssistantMessageModel>> getThread() async {
    final dynamic response = await ApiClient.get('/assistant/');

    return extractResults(response)
        .map(AssistantMessageModel.fromJson)
        .toList();
  }

  /// Returns the answer's text.
  static Future<String> ask(String question) async {
    final response = await ApiClient.post(
      '/assistant/ask/',
      body: <String, dynamic>{'question': question},
      // A model answer routinely takes longer than a normal API call.
      // Kept above AssistantProvider's own limit so a paused question
      // is not killed underneath it by the HTTP layer.
      timeout: const Duration(seconds: 120),
    );

    return response['answer']?.toString() ?? '';
  }

  static Future<void> clear() async {
    await ApiClient.post('/assistant/clear/');
  }
}
