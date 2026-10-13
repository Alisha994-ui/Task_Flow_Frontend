import '../core/network/api_client.dart';
import '../core/network/api_parsing.dart';
import '../models/time_log_model.dart';

/// `/time-logs/` is already scoped to the signed-in user by the backend.
class TimeLogService {
  static const int _maxPages = 10;

  static Future<List<TimeLogModel>> getLogs() async {
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

    for (int page = 1; page <= _maxPages; page++) {
      final dynamic response = await ApiClient.get(
        '/time-logs/${buildQuery(<String, dynamic>{if (page > 1) 'page': page})}',
      );

      rows.addAll(extractResults(response));

      if (nextPageUrl(response) == null) {
        break;
      }
    }

    return rows.map(TimeLogModel.fromJson).toList();
  }

  /// Fails with 400 when a timer is already running.
  static Future<TimeLogModel> start(int taskId) async {
    final response = await ApiClient.post(
      '/time-logs/start/',
      body: <String, dynamic>{'task': taskId},
    );

    return TimeLogModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Stops whichever timer is open and writes the duration.
  static Future<TimeLogModel> stop() async {
    final response = await ApiClient.post(
      '/time-logs/stop/',
      body: <String, dynamic>{},
    );

    return TimeLogModel.fromJson(Map<String, dynamic>.from(response));
  }
}
