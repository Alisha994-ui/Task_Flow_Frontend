import '../core/network/api_client.dart';
import '../core/network/api_parsing.dart';
import '../models/team_member_model.dart';
import '../models/team_model.dart';

class TeamService {
  static const int _maxPages = 10;

  static Future<List<Map<String, dynamic>>> _getAll(
    String path, {
    Map<String, dynamic> params = const <String, dynamic>{},
  }) async {
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

    for (int page = 1; page <= _maxPages; page++) {
      final dynamic response = await ApiClient.get(
        '$path${buildQuery(<String, dynamic>{...params, if (page > 1) 'page': page})}',
      );

      rows.addAll(extractResults(response));

      if (nextPageUrl(response) == null) {
        break;
      }
    }

    return rows;
  }

  static Future<List<TeamModel>> getTeams() async {
    final List<Map<String, dynamic>> rows = await _getAll('/teams/');

    return rows.map(TeamModel.fromJson).toList();
  }

  static Future<TeamModel> getTeam(int id) async {
    final response = await ApiClient.get('/teams/$id/');

    return TeamModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// `members` is read-only on the serializer, so a new team starts
  /// empty and people are added through /team-members/.
  static Future<TeamModel> createTeam({
    required String name,
    String description = '',
    int? teamLead,
    bool isActive = true,
  }) async {
    final response = await ApiClient.post(
      '/teams/',
      body: <String, dynamic>{
        'name': name,
        'description': description,
        'team_lead': teamLead,
        'is_active': isActive,
      },
    );

    return TeamModel.fromJson(Map<String, dynamic>.from(response));
  }

  static Future<TeamModel> updateTeam({
    required int id,
    String? name,
    String? description,
    int? teamLead,
    bool clearLead = false,
    bool? isActive,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};

    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (clearLead) {
      body['team_lead'] = null;
    } else if (teamLead != null) {
      body['team_lead'] = teamLead;
    }
    if (isActive != null) body['is_active'] = isActive;

    final response = await ApiClient.patch('/teams/$id/', body: body);

    return TeamModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Projects point at a team with SET_NULL, so deleting one leaves its
  /// projects in place without a team rather than destroying them.
  static Future<void> deleteTeam(int id) async {
    await ApiClient.delete('/teams/$id/');
  }

  // --------------------------------------------------------- membership

  /// `/team-members/` has no server-side filter, so the rows are
  /// narrowed here. Add `filterset_fields = ["team"]` to make this
  /// cheaper.
  static Future<List<TeamMemberModel>> getMembers({int? teamId}) async {
    final List<Map<String, dynamic>> rows = await _getAll(
      '/team-members/',
      params: <String, dynamic>{'team': teamId},
    );

    final List<TeamMemberModel> all =
        rows.map(TeamMemberModel.fromJson).toList();

    if (teamId == null) {
      return all;
    }

    return all.where((TeamMemberModel m) => m.team == teamId).toList();
  }

  static Future<TeamMemberModel> addMember({
    required int teamId,
    required int userId,
  }) async {
    final response = await ApiClient.post(
      '/team-members/',
      body: <String, dynamic>{'team': teamId, 'user': userId},
    );

    return TeamMemberModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Takes the TeamMember row id, not the user id.
  static Future<void> removeMember(int memberRowId) async {
    await ApiClient.delete('/team-members/$memberRowId/');
  }
}
