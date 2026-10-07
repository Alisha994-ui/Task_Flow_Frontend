import '../core/utils/errors.dart';
import 'package:flutter/foundation.dart';

import '../models/team_member_model.dart';
import '../models/team_model.dart';
import '../services/team_service.dart';

class TeamProvider extends ChangeNotifier {
  List<TeamModel> _all = <TeamModel>[];

  /// Every TeamMember row returned by the API.
  /// Needed because removing someone requires the row id.
  List<TeamMemberModel> _memberRows = <TeamMemberModel>[];

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  String _search = '';

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  String? get error => _error;

  String get search => _search;

  List<TeamModel> get allTeams =>
      List<TeamModel>.unmodifiable(_all);

  int get activeCount =>
      _all.where((TeamModel t) => t.isActive).length;

  List<TeamMemberModel> membersOf(int teamId) {
    return _memberRows
        .where((TeamMemberModel m) => m.team == teamId)
        .toList();
  }

  /// Returns only the teams where this user is the Team Lead.
  List<TeamModel> teamsForTeamLead(int teamLeadId) {
    return _all.where((TeamModel team) {
      return team.isActive && team.teamLead == teamLeadId;
    }).toList();
  }

  /// Returns only members belonging to the Team Lead's own teams.
  List<TeamMemberModel> membersForTeamLead(int teamLeadId) {
    final Set<int> teamIds = teamsForTeamLead(teamLeadId)
        .map((TeamModel team) => team.id)
        .toSet();

    return _memberRows
        .where((TeamMemberModel member) => teamIds.contains(member.team))
        .toList();
  }

  /// Returns user IDs belonging only to the Team Lead's own teams.
  Set<int> memberIdsForTeamLead(int teamLeadId) {
    return membersForTeamLead(teamLeadId)
        .map((TeamMemberModel member) => member.user)
        .toSet();
  }

  /// The TeamMember row for one person on one team.
  TeamMemberModel? memberRow({
    required int teamId,
    required int userId,
  }) {
    for (final TeamMemberModel row in _memberRows) {
      if (row.team == teamId && row.user == userId) {
        return row;
      }
    }

    return null;
  }

  List<TeamModel> get teams {
    final String query = _search.trim().toLowerCase();

    if (query.isEmpty) {
      return allTeams;
    }

    return _all
        .where(
          (TeamModel t) =>
              t.name.toLowerCase().contains(query) ||
              t.description.toLowerCase().contains(query),
        )
        .toList();
  }

  TeamModel? byId(int? id) {
    if (id == null) {
      return null;
    }

    for (final TeamModel team in _all) {
      if (team.id == id) {
        return team;
      }
    }

    return null;
  }

  String nameFor(int? id, {String fallback = 'No team'}) {
    if (id == null) {
      return fallback;
    }

    final TeamModel? team = byId(id);

    return team?.name ?? 'Team #$id';
  }

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

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
      _all = await TeamService.getTeams();
      _error = null;
    } catch (e) {
      _error = friendlyError(e);
    }

    // Membership rows are required for team-member filtering.
    try {
      _memberRows = await TeamService.getMembers();
    } catch (_) {
      // Keep existing membership data if refresh fails.
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => load(silent: _all.isNotEmpty);

  Future<void> ensureLoaded() async {
    if (_all.isEmpty && !_isLoading) {
      await load();
    }
  }

  /// Clears everything on sign out.
  void reset() {
    _all = <TeamModel>[];
    _memberRows = <TeamMemberModel>[];
    _isLoading = false;
    _isSaving = false;
    _error = null;
    _search = '';
    notifyListeners();
  }

  // -----------------------------------------------------------------
  // CRUD
  // -----------------------------------------------------------------

  Future<TeamModel?> createTeam({
    required String name,
    String description = '',
    int? teamLead,
    bool isActive = true,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final TeamModel created = await TeamService.createTeam(
        name: name,
        description: description,
        teamLead: teamLead,
        isActive: isActive,
      );

      _all = <TeamModel>[
        created,
        ..._all,
      ];

      return created;
    } catch (e) {
      _error = friendlyError(e);
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<TeamModel?> updateTeam({
    required int id,
    String? name,
    String? description,
    int? teamLead,
    bool clearLead = false,
    bool? isActive,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final TeamModel updated = await TeamService.updateTeam(
        id: id,
        name: name,
        description: description,
        teamLead: teamLead,
        clearLead: clearLead,
        isActive: isActive,
      );

      _all = _all
          .map(
            (TeamModel t) =>
                t.id == updated.id ? updated : t,
          )
          .toList();

      return updated;
    } catch (e) {
      _error = friendlyError(e);
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> setActive(int id, bool active) async {
    return await updateTeam(
          id: id,
          isActive: active,
        ) !=
        null;
  }

  Future<bool> deleteTeam(int id) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await TeamService.deleteTeam(id);

      _all = _all
          .where((TeamModel t) => t.id != id)
          .toList();

      _memberRows = _memberRows
          .where((TeamMemberModel m) => m.team != id)
          .toList();

      return true;
    } catch (e) {
      _error = friendlyError(e);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // -----------------------------------------------------------
  // Membership
  // -----------------------------------------------------------

  Future<bool> addMember({
    required int teamId,
    required int userId,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final TeamMemberModel row =
          await TeamService.addMember(
        teamId: teamId,
        userId: userId,
      );

      _memberRows = <TeamMemberModel>[
        ..._memberRows,
        row,
      ];

      await _refreshTeam(teamId);

      return true;
    } catch (e) {
      _error = friendlyError(e);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> removeMember({
    required int teamId,
    required int memberRowId,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await TeamService.removeMember(memberRowId);

      _memberRows = _memberRows
          .where(
            (TeamMemberModel m) =>
                m.id != memberRowId,
          )
          .toList();

      await _refreshTeam(teamId);

      return true;
    } catch (e) {
      _error = friendlyError(e);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _refreshTeam(int teamId) async {
    try {
      final TeamModel fresh =
          await TeamService.getTeam(teamId);

      _all = _all
          .map(
            (TeamModel t) =>
                t.id == teamId ? fresh : t,
          )
          .toList();
    } catch (_) {
      // Keep existing team data if refresh fails.
    }
  }
}