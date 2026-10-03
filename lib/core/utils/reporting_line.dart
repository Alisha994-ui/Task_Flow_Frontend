import '../../models/project_model.dart';
import '../../models/team_model.dart';
import '../../models/user_model.dart';
import '../constants/project_constants.dart';

/// Who a person reports to.
///
/// Nothing in the API says "Ali reports to Sara" - the chain has to be
/// read out of the existing links:
///
///   employee -> the team they are a member of -> its team_lead
///   lead     -> the projects owned by their team -> project.manager
///   manager  -> whoever has the ADMIN role
class ReportingLine {
  const ReportingLine({
    required this.teams,
    required this.leads,
    required this.managers,
    required this.admins,
  });

  /// Teams the person belongs to or leads.
  final List<TeamModel> teams;

  /// Their team lead, or leads when they sit in more than one team.
  final List<UserModel> leads;

  /// Managers of the projects their team works on.
  final List<UserModel> managers;

  final List<UserModel> admins;

  bool get isEmpty =>
      leads.isEmpty && managers.isEmpty && admins.isEmpty;
}

ReportingLine resolveReportingLine({
  required int? userId,
  required String role,
  required List<UserModel> users,
  required List<TeamModel> teams,
  required List<ProjectModel> projects,
}) {
  if (userId == null) {
    return const ReportingLine(
      teams: <TeamModel>[],
      leads: <UserModel>[],
      managers: <UserModel>[],
      admins: <UserModel>[],
    );
  }

  UserModel? byId(int? id) {
    if (id == null) {
      return null;
    }

    for (final UserModel user in users) {
      if (user.id == id) {
        return user;
      }
    }

    return null;
  }

  // Teams they are part of, either as a member or as the lead.
  final List<TeamModel> myTeams = teams
      .where((TeamModel t) => t.members.contains(userId) || t.teamLead == userId)
      .toList();

  final Set<int> myTeamIds = myTeams.map((TeamModel t) => t.id).toSet();

  // The lead of each of those teams - never the person themself.
  final Map<int, UserModel> leads = <int, UserModel>{};

  for (final TeamModel team in myTeams) {
    if (team.teamLead == null || team.teamLead == userId) {
      continue;
    }

    final UserModel? lead = byId(team.teamLead);

    if (lead != null) {
      leads[lead.id] = lead;
    }
  }

  // Managers of the projects those teams work on.
  final Map<int, UserModel> managers = <int, UserModel>{};

  for (final ProjectModel project in projects) {
    if (project.manager == null || project.manager == userId) {
      continue;
    }

    final bool mine = (project.team != null && myTeamIds.contains(project.team));

    if (!mine) {
      continue;
    }

    final UserModel? manager = byId(project.manager);

    if (manager != null) {
      managers[manager.id] = manager;
    }
  }

  // A manager with no team link still reports upward - fall back to the
  // managers of any project they own, which is nobody, so they just get
  // the admins below.
  final List<UserModel> admins = users
      .where((UserModel u) => u.role == UserRoles.admin && u.id != userId)
      .toList();

  return ReportingLine(
    teams: myTeams,
    leads: leads.values.toList(),
    managers: managers.values.toList(),
    admins: admins,
  );
}
