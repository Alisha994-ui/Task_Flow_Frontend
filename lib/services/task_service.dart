import '../core/network/api_client.dart';
import '../core/network/api_parsing.dart';
import '../models/activity_log_model.dart';
import '../models/comment_model.dart';
import '../models/label_model.dart';
import '../models/subtask_model.dart';
import '../models/task_model.dart';
import '../models/task_stats_model.dart';

/// Talks to the `tasks` app.
///
/// The backend already scopes every list to the signed-in user's role
/// (a PROJECT_MANAGER only ever sees tasks on projects they manage), so the
/// app does not have to send an owner filter.
class TaskService {
  /// Safety cap so a bad `next` link can never loop forever.
  static const int _maxPages = 20;

  /// Walks DRF pagination and returns every page of a list endpoint.
  static Future<List<Map<String, dynamic>>> _getAll(
    String path, {
    Map<String, dynamic> params = const <String, dynamic>{},
  }) async {
    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];

    for (int page = 1; page <= _maxPages; page++) {
      final Map<String, dynamic> query = <String, dynamic>{
        ...params,
        if (page > 1) 'page': page,
      };

      final dynamic response = await ApiClient.get('$path${buildQuery(query)}');

      items.addAll(extractResults(response));

      if (nextPageUrl(response) == null) {
        break;
      }
    }

    return items;
  }

  // ------------------------------------------------------------------ tasks

  /// All tasks visible to the user, with optional server-side filters.
  static Future<List<TaskModel>> getTasks({
    int? project,
    String? status,
    String? priority,
    int? assignee,
    String? search,
    bool overdueOnly = false,
  }) async {
    final List<Map<String, dynamic>> rows = await _getAll(
      '/tasks/',
      params: <String, dynamic>{
        'project': project,
        'status': status,
        'priority': priority,
        'assignee': assignee,
        'search': search,
        if (overdueOnly) 'overdue': 'true',
      },
    );

    return rows.map(TaskModel.fromJson).toList();
  }

  static Future<TaskModel> getTask(int id) async {
    final response = await ApiClient.get('/tasks/$id/');

    return TaskModel.fromJson(Map<String, dynamic>.from(response));
  }

  static Future<TaskModel> createTask({
    required int project,
    required String title,
    String description = '',
    int? assignee,
    required String priority,
    required String status,
    String? startDate,
    String? dueDate,
    int progress = 0,
    List<int> labels = const <int>[],
  }) async {
    final response = await ApiClient.post(
      '/tasks/',
      body: <String, dynamic>{
        'project': project,
        'title': title,
        'description': description,
        'assignee': assignee,
        'priority': priority,
        'status': status,
        'start_date': startDate,
        'due_date': dueDate,
        'progress': progress,
        if (labels.isNotEmpty) 'labels': labels,
      },
    );

    return TaskModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Partial update. Pass only the keys that change, e.g.
  /// `{'status': 'IN_PROGRESS'}` or `{'assignee': 12}`.
  ///
  /// The dedicated `/tasks/{id}/status/` endpoint is assignee-only, so
  /// managers always go through this one.
  static Future<TaskModel> patchTask(
    int id,
    Map<String, dynamic> changes,
  ) async {
    final response = await ApiClient.patch('/tasks/$id/', body: changes);

    return TaskModel.fromJson(Map<String, dynamic>.from(response));
  }

  static Future<void> deleteTask(int id) async {
    await ApiClient.delete('/tasks/$id/');
  }

  /// `/tasks/{id}/status/` - the endpoint an EMPLOYEE is allowed to call on
  /// their own task. It also resets progress to 0 or 100 server-side.
  static Future<TaskModel> updateOwnStatus({
    required int id,
    required String status,
  }) async {
    final response = await ApiClient.patch(
      '/tasks/$id/status/',
      body: <String, dynamic>{'status': status},
    );

    return TaskModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Counts across every project this manager owns.
  static Future<TaskStatsModel> managerDashboard() async {
    final response = await ApiClient.get('/tasks/manager-dashboard/');

    return TaskStatsModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Counts across every project owned by a team this user leads.
  static Future<TaskStatsModel> teamLeadDashboard() async {
    final response = await ApiClient.get('/tasks/team-lead-dashboard/');

    return TaskStatsModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Counts for the tasks assigned to the signed-in user.
  static Future<TaskStatsModel> myDashboard() async {
    final response = await ApiClient.get('/tasks/dashboard/');

    return TaskStatsModel.fromJson(Map<String, dynamic>.from(response));
  }

  // --------------------------------------------------------------- subtasks

  /// `/subtasks/` has no server-side task filter yet, so the list is
  /// filtered here. Add a filterset on SubtaskViewSet to make this cheaper.
  static Future<List<SubtaskModel>> getSubtasks(int taskId) async {
    final List<Map<String, dynamic>> rows =
        await _getAll('/subtasks/', params: <String, dynamic>{'task': taskId});

    return rows
        .map(SubtaskModel.fromJson)
        .where((SubtaskModel s) => s.task == taskId)
        .toList();
  }

  static Future<SubtaskModel> createSubtask({
    required int taskId,
    required String title,
  }) async {
    final response = await ApiClient.post(
      '/subtasks/',
      body: <String, dynamic>{
        'task': taskId,
        'title': title,
        'is_done': false,
      },
    );

    return SubtaskModel.fromJson(Map<String, dynamic>.from(response));
  }

  static Future<SubtaskModel> setSubtaskDone({
    required int subtaskId,
    required bool isDone,
  }) async {
    final response = await ApiClient.patch(
      '/subtasks/$subtaskId/',
      body: <String, dynamic>{'is_done': isDone},
    );

    return SubtaskModel.fromJson(Map<String, dynamic>.from(response));
  }

  static Future<void> deleteSubtask(int subtaskId) async {
    await ApiClient.delete('/subtasks/$subtaskId/');
  }

  // --------------------------------------------------------------- comments

  static Future<List<CommentModel>> getComments(int taskId) async {
    final List<Map<String, dynamic>> rows =
        await _getAll('/comments/', params: <String, dynamic>{'task': taskId});

    return rows
        .map(CommentModel.fromJson)
        .where((CommentModel c) => c.task == taskId)
        .toList();
  }

  static Future<CommentModel> addComment({
    required int taskId,
    required String text,
  }) async {
    final response = await ApiClient.post(
      '/comments/',
      body: <String, dynamic>{'task': taskId, 'text': text},
    );

    return CommentModel.fromJson(Map<String, dynamic>.from(response));
  }

  static Future<void> deleteComment(int commentId) async {
    await ApiClient.delete('/comments/$commentId/');
  }

  // ----------------------------------------------------------- activity log

  /// Activity for one task, or - when [taskIds] is given - for a whole
  /// project (ActivityLog only links to a task, so the project view filters
  /// by the tasks that belong to it).
  static Future<List<ActivityLogModel>> getActivityLogs({
    int? taskId,
    Set<int>? taskIds,
  }) async {
    final List<Map<String, dynamic>> rows = await _getAll(
      '/activity-logs/',
      params: <String, dynamic>{'task': taskId},
    );

    final List<ActivityLogModel> logs =
        rows.map(ActivityLogModel.fromJson).toList();

    if (taskId != null) {
      return logs.where((ActivityLogModel l) => l.task == taskId).toList();
    }

    if (taskIds != null) {
      return logs.where((ActivityLogModel l) => taskIds.contains(l.task)).toList();
    }

    return logs;
  }

  // ----------------------------------------------------------------- labels

  static Future<List<LabelModel>> getLabels() async {
    final List<Map<String, dynamic>> rows = await _getAll('/labels/');

    return rows.map(LabelModel.fromJson).toList();
  }
}
