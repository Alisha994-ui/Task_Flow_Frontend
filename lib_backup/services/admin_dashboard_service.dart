import '../core/network/api_client.dart';
import '../models/admin_dashboard_model.dart';

class AdminDashboardService {
  static Future<AdminDashboardModel> getDashboard() async {
    final response = await ApiClient.get(
      '/admin-dashboard/',
    );

    return AdminDashboardModel.fromJson(response);
  }
}