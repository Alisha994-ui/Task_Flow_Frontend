import 'package:flutter/foundation.dart';

import '../core/constants/project_constants.dart';
import '../core/utils/app_date_utils.dart';
import '../models/project_model.dart';

/// Holds who the signed-in user is and scopes the project list to them.
///
/// Both the Project Manager and the Team Lead panels use this: a manager
/// owns projects through `project.manager`, a lead owns them through
/// `team.team_lead`, and [myProjects] covers both. The id is pushed in from
/// the route (AuthProvider owns the real session), so this provider never
/// talks to the API itself.
class ManagerProvider extends ChangeNotifier {
  int? _managerId;
  String _managerName = '';
  String _roleLabel = 'Project manager';

  String _search = '';
  String _statusFilter = kFilterAll;

  int? get managerId => _managerId;

  String get managerName => _managerName;

  String get search => _search;

  String get statusFilter => _statusFilter;

  bool get hasFilters =>
      _search.trim().isNotEmpty || _statusFilter != kFilterAll;

  /// Human-readable role, shown on profile headers.
  String get roleLabel => _roleLabel;

  void setManager({
    required int id,
    String name = '',
    String roleLabel = 'Project manager',
  }) {
    final bool same = _managerId == id &&
        (name.isEmpty || name == _managerName) &&
        roleLabel == _roleLabel;

    if (same) {
      return;
    }

    _managerId = id;
    _roleLabel = roleLabel;

    if (name.isNotEmpty) {
      _managerName = name;
    }

    notifyListeners();
  }

  void setName(String name) {
    if (name.isEmpty || name == _managerName) {
      return;
    }

    _managerName = name;
    notifyListeners();
  }

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  void setStatusFilter(String value) {
    _statusFilter = value;
    notifyListeners();
  }

  void clearFilters() {
    _search = '';
    _statusFilter = kFilterAll;
    notifyListeners();
  }

  /// Projects this manager owns, plus projects whose team they lead.
  /// Archived projects stay out of the manager view.
  List<ProjectModel> myProjects(
    List<ProjectModel> all, {
    Set<int> ledTeamIds = const <int>{},
  }) {
    final int? id = _managerId;

    if (id == null) {
      return const <ProjectModel>[];
    }

    final List<ProjectModel> mine = all.where((ProjectModel p) {
      if (p.isArchived) {
        return false;
      }

      if (p.manager == id) {
        return true;
      }

      return p.team != null && ledTeamIds.contains(p.team);
    }).toList();

    mine.sort((ProjectModel a, ProjectModel b) {
      // Anything with a due date comes first, soonest at the top.
      final DateTime aEnd = a.endDate ?? DateTime(2999);
      final DateTime bEnd = b.endDate ?? DateTime(2999);

      return aEnd.compareTo(bEnd);
    });

    return mine;
  }

  /// [myProjects] with the search box and status chip applied.
  List<ProjectModel> visibleProjects(
    List<ProjectModel> all, {
    Set<int> ledTeamIds = const <int>{},
  }) {
    final String query = _search.trim().toLowerCase();

    return myProjects(all, ledTeamIds: ledTeamIds).where((ProjectModel p) {
      if (_statusFilter != kFilterAll && p.status != _statusFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return p.name.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query);
    }).toList();
  }

  // ------------------------------------------------------------- summaries

  int activeCount(List<ProjectModel> mine) => mine
      .where((ProjectModel p) => p.status == ProjectStatus.active)
      .length;

  int completedCount(List<ProjectModel> mine) => mine
      .where((ProjectModel p) => p.status == ProjectStatus.completed)
      .length;

  int onHoldCount(List<ProjectModel> mine) =>
      mine.where((ProjectModel p) => p.status == ProjectStatus.onHold).length;

  int overdueCount(List<ProjectModel> mine) => mine
      .where((ProjectModel p) => isOverdue(p.endDate, p.status))
      .length;

  /// Average completion across the manager's projects, 0-100.
  int averageProgress(List<ProjectModel> mine) {
    if (mine.isEmpty) {
      return 0;
    }

    final int sum = mine.fold<int>(
      0,
      (int total, ProjectModel p) => total + p.progress,
    );

    return (sum / mine.length).round();
  }

  /// Projects due inside [withinDays], soonest first, overdue ones included.
  List<ProjectModel> upcomingDeadlines(
    List<ProjectModel> mine, {
    int withinDays = 30,
  }) {
    final List<ProjectModel> due = mine.where((ProjectModel p) {
      if (p.endDate == null) {
        return false;
      }

      if (p.status == ProjectStatus.completed ||
          p.status == ProjectStatus.cancelled) {
        return false;
      }

      final int? days = daysUntil(p.endDate);

      return days != null && days <= withinDays;
    }).toList();

    due.sort((ProjectModel a, ProjectModel b) => a.endDate!.compareTo(b.endDate!));

    return due;
  }

  /// Clears everything on sign out.
  void reset() {
    _managerId = null;
    _managerName = '';
    _roleLabel = 'Project manager';
    clearFilters();
  }
}
