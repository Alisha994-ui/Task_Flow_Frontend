import '../core/network/api_client.dart';
import '../models/team_model.dart';

class TeamService {
  static Future<List<TeamModel>> getTeams() async {
    final response = await ApiClient.get('/teams/');

    final results = response['results'] as List<dynamic>? ?? [];

    return results
        .map(
          (item) => TeamModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  static Future<TeamModel> getTeam(int id) async {
    final response = await ApiClient.get('/teams/$id/');

    return TeamModel.fromJson(response);
  }
}
