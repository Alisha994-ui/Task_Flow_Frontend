import '../core/constants/app_config.dart';
import '../core/network/api_client.dart';

class AppConfigService {
  static Future<void> load() async {
    final response = await ApiClient.get('/app-config/');

    AppConfig.supportEmail =
        response['support_email']?.toString() ?? '';
  }
}