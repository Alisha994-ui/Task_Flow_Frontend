import '../core/network/api_client.dart';
import '../core/network/api_parsing.dart';
import '../models/notification_model.dart';

/// `/notifications/` is already scoped to the signed-in user and ordered
/// newest first by the backend. Create, edit and delete are blocked there,
/// so this service only reads and marks as read.
class NotificationService {
  static const int _maxPages = 10;

  static Future<List<NotificationModel>> getNotifications() async {
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

    for (int page = 1; page <= _maxPages; page++) {
      final dynamic response = await ApiClient.get(
        '/notifications/${buildQuery(<String, dynamic>{if (page > 1) 'page': page})}',
      );

      rows.addAll(extractResults(response));

      if (nextPageUrl(response) == null) {
        break;
      }
    }

    return rows.map(NotificationModel.fromJson).toList();
  }

  static Future<NotificationModel> markRead(int id) async {
    final response = await ApiClient.patch(
      '/notifications/$id/read/',
      body: <String, dynamic>{},
    );

    return NotificationModel.fromJson(Map<String, dynamic>.from(response));
  }

  static Future<void> markAllRead() async {
    await ApiClient.patch(
      '/notifications/read-all/',
      body: <String, dynamic>{},
    );
  }
}
