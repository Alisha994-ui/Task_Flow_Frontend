import '../core/network/api_client.dart';
import '../models/project_member_model.dart';
import '../models/project_model.dart';

class ProjectService {
  static Future<List<ProjectModel>> getProjects() async {
    final response = await ApiClient.get('/projects/');

    final results = response['results'] as List<dynamic>? ?? [];

    return results
        .map(
          (item) => ProjectModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  static Future<ProjectModel> getProject(int id) async {
    final response = await ApiClient.get('/projects/$id/');

    return ProjectModel.fromJson(response);
  }

  static Future<ProjectModel> createProject({
    required String name,
    required String description,
    String? startDate,
    String? endDate,
    required String priority,
    required String status,
    required int manager,
    required int team,
    bool isArchived = false,
  }) async {
    final response = await ApiClient.post(
      '/projects/',
      body: {
        'name': name,
        'description': description,
        'start_date': startDate,
        'end_date': endDate,
        'priority': priority,
        'status': status,
        'manager': manager,
        'team': team,
        'is_archived': isArchived,
      },
    );

    return ProjectModel.fromJson(response);
  }

  static Future<ProjectModel> updateProject({
    required int id,
    required String name,
    required String description,
    String? startDate,
    String? endDate,
    required String priority,
    required String status,
    required int manager,
    required int team,
    required bool isArchived,
  }) async {
    final response = await ApiClient.patch(
      '/projects/$id/',
      body: {
        'name': name,
        'description': description,
        'start_date': startDate,
        'end_date': endDate,
        'priority': priority,
        'status': status,
        'manager': manager,
        'team': team,
        'is_archived': isArchived,
      },
    );

    return ProjectModel.fromJson(response);
  }

  static Future<void> deleteProject(int id) async {
    await ApiClient.delete('/projects/$id/');
  }

  static Future<List<ProjectMemberModel>> getProjectMembers(
    int projectId,
  ) async {
    final response = await ApiClient.get(
      '/project-members/?project=$projectId',
    );

    final results = response['results'] as List<dynamic>? ?? [];

    return results
        .map(
          (item) => ProjectMemberModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  static Future<ProjectMemberModel> addMember({
    required int projectId,
    required int userId,
  }) async {
    final response = await ApiClient.post(
      '/project-members/',
      body: {
        'project': projectId,
        'user': userId,
      },
    );

    return ProjectMemberModel.fromJson(response);
  }

  static Future<void> removeMember(int memberId) async {
    await ApiClient.delete('/project-members/$memberId/');
  }

  static Future<Map<String, dynamic>> getProjectProgress(
    int projectId,
  ) async {
    return await ApiClient.get(
      '/projects/$projectId/progress/',
    );
  }
}