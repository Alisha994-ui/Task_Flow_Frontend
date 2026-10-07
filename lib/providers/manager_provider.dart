import 'package:flutter/foundation.dart';

import '../core/constants/project_constants.dart';
import '../core/utils/app_date_utils.dart';
import '../models/project_model.dart';

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

  /// Only projects assigned to this Project Manager.
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

    // Project Manager can only see projects
    // directly assigned to them.
    return p.manager == id;
  }).toList();

  mine.sort((ProjectModel a, ProjectModel b) {
    final DateTime aEnd =
        a.endDate ?? DateTime(2999);

    final DateTime bEnd =
        b.endDate ?? DateTime(2999);

    return aEnd.compareTo(bEnd);
  });

  return mine;
}

  List<ProjectModel> visibleProjects(List<ProjectModel> all) {
    final String query = _search.trim().toLowerCase();

    return myProjects(all).where((ProjectModel p) {
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

    due.sort(
      (ProjectModel a, ProjectModel b) =>
          a.endDate!.compareTo(b.endDate!),
    );

    return due;
  }

  void reset() {
    _managerId = null;
    _managerName = '';
    _roleLabel = 'Project manager';
    clearFilters();
  }
}