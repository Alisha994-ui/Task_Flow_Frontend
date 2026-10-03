import 'package:flutter/foundation.dart';

import '../core/constants/project_constants.dart';
import '../core/utils/app_date_utils.dart';
import '../models/project_model.dart';
import '../services/project_service.dart';

class ProjectProvider extends ChangeNotifier {
  List<ProjectModel> _all = <ProjectModel>[];

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  String _search = '';
  String _statusFilter = kFilterAll;
  String _priorityFilter = kFilterAll;
  bool _showArchived = false;

  // ---------------------------------------------------------------- getters

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  String? get error => _error;

  String get search => _search;

  String get statusFilter => _statusFilter;

  String get priorityFilter => _priorityFilter;

  bool get showArchived => _showArchived;

  bool get isLoaded => _all.isNotEmpty || (!_isLoading && _error == null);

  List<ProjectModel> get allProjects => List<ProjectModel>.unmodifiable(_all);

  int get totalCount => _all.length;

  int get archivedCount => _all.where((ProjectModel p) => p.isArchived).length;

  int get activeCount => _all
      .where((ProjectModel p) =>
          !p.isArchived && p.status == ProjectStatus.inProgress)
      .length;

  bool get hasActiveFilters =>
      _search.trim().isNotEmpty ||
      _statusFilter != kFilterAll ||
      _priorityFilter != kFilterAll ||
      _showArchived;

  /// Filters are applied on the client because `/projects/` currently returns
  /// a plain paginated list with no query params wired up.
  List<ProjectModel> get projects {
    final String query = _search.trim().toLowerCase();

    final List<ProjectModel> filtered = _all.where((ProjectModel p) {
      if (!_showArchived && p.isArchived) {
        return false;
      }

      if (_statusFilter != kFilterAll && p.status != _statusFilter) {
        return false;
      }

      if (_priorityFilter != kFilterAll && p.priority != _priorityFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return p.name.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query);
    }).toList();

    filtered.sort((ProjectModel a, ProjectModel b) {
      final DateTime aDate =
          a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bDate =
          b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  ProjectModel? byId(int id) {
    for (final ProjectModel project in _all) {
      if (project.id == id) {
        return project;
      }
    }

    return null;
  }

  // ---------------------------------------------------------------- filters

  void setSearch(String value) {
    if (_search == value) {
      return;
    }

    _search = value;
    notifyListeners();
  }

  void setStatusFilter(String value) {
    _statusFilter = value;
    notifyListeners();
  }

  void setPriorityFilter(String value) {
    _priorityFilter = value;
    notifyListeners();
  }

  void setShowArchived(bool value) {
    _showArchived = value;
    notifyListeners();
  }

  void clearFilters() {
    _search = '';
    _statusFilter = kFilterAll;
    _priorityFilter = kFilterAll;
    _showArchived = false;
    notifyListeners();
  }

  // ------------------------------------------------------------------- load

  Future<void> load({bool silent = false}) async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;

    if (!silent) {
      _error = null;
      notifyListeners();
    }

    try {
      _all = await ProjectService.getProjects();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(silent: _all.isNotEmpty);

  /// Loads once - used by screens that may open outside a panel shell.
  Future<void> ensureLoaded() async {
    if (_all.isEmpty && !_isLoading) {
      await load();
    }
  }

  // -------------------------------------------------------------------- CRUD

  Future<ProjectModel?> createProject({
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
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final ProjectModel created = await ProjectService.createProject(
        name: name,
        description: description,
        startDate: startDate,
        endDate: endDate,
        priority: priority,
        status: status,
        manager: manager,
        team: team,
        isArchived: isArchived,
      );

      _all = <ProjectModel>[created, ..._all];

      return created;
    } catch (e) {
      _error = e.toString();

      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<ProjectModel?> updateProject({
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
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final ProjectModel updated = await ProjectService.updateProject(
        id: id,
        name: name,
        description: description,
        startDate: startDate,
        endDate: endDate,
        priority: priority,
        status: status,
        manager: manager,
        team: team,
        isArchived: isArchived,
      );

      _replaceLocally(updated);

      return updated;
    } catch (e) {
      _error = e.toString();

      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Archive / unarchive without opening the form.
  ///
  /// `updateProject` needs manager and team, so a project that was created
  /// without them cannot be toggled from the list.
  Future<bool> toggleArchive(ProjectModel project) async {
    if (project.manager == null || project.team == null) {
      _error = 'This project has no manager or team yet. '
          'Open it and set them before archiving.';
      notifyListeners();

      return false;
    }

    final ProjectModel? updated = await updateProject(
      id: project.id,
      name: project.name,
      description: project.description,
      startDate: apiDateOrNull(project.startDate),
      endDate: apiDateOrNull(project.endDate),
      priority: project.priority,
      status: project.status,
      manager: project.manager!,
      team: project.team!,
      isArchived: !project.isArchived,
    );

    return updated != null;
  }

  Future<bool> deleteProject(int id) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await ProjectService.deleteProject(id);
      _all = _all.where((ProjectModel p) => p.id != id).toList();

      return true;
    } catch (e) {
      _error = e.toString();

      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Called by the detail screen so the list stays in sync.
  void replaceLocally(ProjectModel project) {
    _replaceLocally(project);
    notifyListeners();
  }

  void _replaceLocally(ProjectModel project) {
    _all = _all
        .map((ProjectModel p) => p.id == project.id ? project : p)
        .toList();
  }

  void clearError() {
    _error = null;
  }

  /// Clears everything on sign out.
  void reset() {
    _all = <ProjectModel>[];
    _isLoading = false;
    _isSaving = false;
    _error = null;
    clearFilters();
  }
}
