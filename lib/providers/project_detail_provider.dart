import 'package:flutter/foundation.dart';

import '../models/project_member_model.dart';
import '../models/project_model.dart';
import '../services/project_service.dart';

class ProjectDetailProvider extends ChangeNotifier {
  ProjectDetailProvider(this.projectId);

  final int projectId;

  ProjectModel? _project;
  List<ProjectMemberModel> _members = <ProjectMemberModel>[];
  Map<String, dynamic> _progress = <String, dynamic>{};

  bool _isLoading = false;
  bool _isMemberBusy = false;
  String? _error;

  ProjectModel? get project => _project;

  List<ProjectMemberModel> get members =>
      List<ProjectMemberModel>.unmodifiable(_members);

  Map<String, dynamic> get progress => Map<String, dynamic>.from(_progress);

  bool get isLoading => _isLoading;

  bool get isMemberBusy => _isMemberBusy;

  String? get error => _error;

  Set<int> get memberUserIds =>
      _members.map((ProjectMemberModel m) => m.user).toSet();

  Future<void> load({bool silent = false}) async {
    _isLoading = true;

    if (!silent) {
      _error = null;
      notifyListeners();
    }

    try {
      _project = await ProjectService.getProject(projectId);
      _members = await ProjectService.getProjectMembers(projectId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    // The progress endpoint is optional - a failure here should not blank
    // out the whole screen.
    try {
      _progress = await ProjectService.getProjectProgress(projectId);
    } catch (_) {
      _progress = <String, dynamic>{};
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => load(silent: _project != null);

  Future<bool> addMember(int userId) async {
    _isMemberBusy = true;
    _error = null;
    notifyListeners();

    try {
      final ProjectMemberModel member = await ProjectService.addMember(
        projectId: projectId,
        userId: userId,
      );

      _members = <ProjectMemberModel>[..._members, member];

      return true;
    } catch (e) {
      _error = e.toString();

      return false;
    } finally {
      _isMemberBusy = false;
      notifyListeners();
    }
  }

  Future<bool> removeMember(int memberId) async {
    _isMemberBusy = true;
    _error = null;
    notifyListeners();

    try {
      await ProjectService.removeMember(memberId);
      _members = _members
          .where((ProjectMemberModel m) => m.id != memberId)
          .toList();

      return true;
    } catch (e) {
      _error = e.toString();

      return false;
    } finally {
      _isMemberBusy = false;
      notifyListeners();
    }
  }

  void setProject(ProjectModel project) {
    _project = project;
    notifyListeners();
  }
}
