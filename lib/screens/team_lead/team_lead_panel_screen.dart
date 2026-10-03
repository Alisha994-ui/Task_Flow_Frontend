import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/project_model.dart';
import '../../models/team_model.dart';
import '../../providers/manager_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_provider.dart';
import '../../providers/time_log_provider.dart';
import '../../providers/user_provider.dart';
import '../manager/tabs/manager_calendar_tab.dart';
import '../manager/tabs/manager_tasks_tab.dart';
import '../manager/task_actions.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/notification_bell.dart';
import '../../screens/profile/profile_screen.dart';
import 'tabs/team_lead_dashboard_tab.dart';
import 'tabs/team_lead_members_tab.dart';
import 'tabs/team_lead_more_tab.dart';

/// Entry point for the Team Lead experience.
///
/// Push it with the signed-in lead's id:
/// `Navigator.pushReplacementNamed(context, AppRoutes.teamLeadPanel,
///   arguments: TeamLeadPanelArgs(userId: user.id, userName: user.fullName));`
///
/// The Tasks and Calendar tabs are the same widgets the manager panel uses -
/// the backend already narrows `/tasks/` to the projects whose team this
/// user leads, so no extra scoping is needed on top.
class TeamLeadPanelScreen extends StatefulWidget {
  const TeamLeadPanelScreen({
    super.key,
    required this.userId,
    this.userName = '',
  });

  static const String routeName = '/team-lead';

  final int userId;
  final String userName;

  @override
  State<TeamLeadPanelScreen> createState() => _TeamLeadPanelScreenState();
}

/// Route arguments holder.
class TeamLeadPanelArgs {
  const TeamLeadPanelArgs({required this.userId, this.userName = ''});

  final int userId;
  final String userName;
}

class _TeamLeadPanelScreenState extends State<TeamLeadPanelScreen> {
  int _index = 0;

  static const List<String> _titles = <String>[
    'Dashboard',
    'Tasks',
    'My team',
    'Calendar',
    'More',
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      context.read<ManagerProvider>().setManager(
            id: widget.userId,
            name: widget.userName,
            roleLabel: 'Team lead',
          );

      // Counts come from the team-lead endpoint, not the manager one.
      context.read<TaskProvider>().setStatsScope(TaskStatsScope.teamLead);
      context.read<TimeLogProvider>().setCurrentUser(widget.userId);

      await _loadAll();

      if (!mounted) {
        return;
      }

      final ManagerProvider scope = context.read<ManagerProvider>();

      if (scope.managerName.isEmpty) {
        final String resolved =
            context.read<UserProvider>().nameFor(widget.userId, fallback: '');

        if (resolved.isNotEmpty && !resolved.startsWith('User #')) {
          scope.setName(resolved);
        }
      }
    });
  }

  Future<void> _loadAll() async {
    if (!mounted) {
      return;
    }

    final TaskProvider tasks = context.read<TaskProvider>();

    await Future.wait<void>(<Future<void>>[
      context.read<ProjectProvider>().load(silent: true),
      context.read<UserProvider>().load(silent: true),
      context.read<NotificationProvider>().load(silent: true),
      context.read<TeamProvider>().load(silent: true),
      tasks.load(silent: true),
      tasks.loadStats(),
      context.read<TimeLogProvider>().load(silent: true),
    ]);
  }

  /// Projects on the teams this user leads.
  List<ProjectModel> _myProjects() {
    final ManagerProvider scope = context.read<ManagerProvider>();
    final Set<int> ledTeamIds = context
        .read<TeamProvider>()
        .allTeams
        .where((TeamModel t) => t.teamLead == scope.managerId)
        .map((TeamModel t) => t.id)
        .toSet();

    return scope.myProjects(
      context.read<ProjectProvider>().allProjects,
      ledTeamIds: ledTeamIds,
    );
  }

  void _goToTasks() => setState(() => _index = 1);

  void _goToTeam() => setState(() => _index = 2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: <Widget>[
          const NotificationBell(),
          IconButton(
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const ProfileScreen(),
              ),
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          TeamLeadDashboardTab(
            onSeeAllTasks: _goToTasks,
            onSeeTeam: _goToTeam,
          ),
          const ManagerTasksTab(),
          const TeamLeadMembersTab(),
          const ManagerCalendarTab(),
          const TeamLeadMoreTab(),
        ],
      ),
      floatingActionButton: _index == 1 || _index == 3
          ? FloatingActionButton.extended(
              onPressed: () => TaskActions.create(
                context,
                selectableProjects: _myProjects(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('New task'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'My team',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
