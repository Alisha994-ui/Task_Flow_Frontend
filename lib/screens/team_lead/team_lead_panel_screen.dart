import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/auto_refresh.dart';
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
import '../../widgets/admin/admin_widgets.dart';
import '../../widgets/notification_bell.dart';
import '../../screens/profile/profile_screen.dart';
import 'tabs/team_lead_dashboard_tab.dart';
import 'tabs/team_lead_members_tab.dart';
import 'tabs/team_lead_more_tab.dart';
import '../../screens/assistant/assistant_panel.dart';

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
  State<TeamLeadPanelScreen> createState() =>
      _TeamLeadPanelScreenState();
}

class TeamLeadPanelArgs {
  const TeamLeadPanelArgs({
    required this.userId,
    this.userName = '',
  });

  final int userId;
  final String userName;
}

class _TeamLeadPanelScreenState
    extends State<TeamLeadPanelScreen> {
  int _index = 0;

  late final AutoRefresher _auto;

  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

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

    _auto = AutoRefresher(onRefresh: _loadAll);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      context.read<ManagerProvider>().setManager(
            id: widget.userId,
            name: widget.userName,
            roleLabel: 'Team lead',
          );

      context
          .read<TaskProvider>()
          .setStatsScope(TaskStatsScope.teamLead);

      context
          .read<TimeLogProvider>()
          .setCurrentUser(widget.userId);

      await _loadAll();

      _auto.start();

      if (!mounted) {
        return;
      }

      final ManagerProvider scope =
          context.read<ManagerProvider>();

      if (scope.managerName.isEmpty) {
        final String resolved =
            context.read<UserProvider>().nameFor(
                  widget.userId,
                  fallback: '',
                );

        if (resolved.isNotEmpty &&
            !resolved.startsWith('User #')) {
          scope.setName(resolved);
        }
      }
    });
  }

  @override
  void dispose() {
    _auto.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) {
      return;
    }

    final TaskProvider tasks =
        context.read<TaskProvider>();

    await Future.wait<void>(<Future<void>>[
      context.read<ProjectProvider>().load(
            silent: true,
          ),
      context.read<UserProvider>().load(
            silent: true,
          ),
      context.read<NotificationProvider>().load(
            silent: true,
          ),
      context.read<TeamProvider>().load(
            silent: true,
          ),
      tasks.load(
        silent: true,
      ),
      tasks.loadStats(),
      context.read<TimeLogProvider>().load(
            silent: true,
          ),
    ]);
  }

  /// Returns only the active, non-archived projects
  /// belonging to teams led by this Team Lead.
  List<ProjectModel> _myProjects() {
    final TeamProvider teams =
        context.read<TeamProvider>();

    final ProjectProvider projects =
        context.read<ProjectProvider>();

    final Set<int> ledTeamIds = teams.allTeams
        .where(
          (TeamModel team) =>
              team.isActive &&
              team.teamLead == widget.userId,
        )
        .map(
          (TeamModel team) => team.id,
        )
        .toSet();

    return projects.allProjects
        .where(
          (ProjectModel project) =>
              !project.isArchived &&
              project.team != null &&
              ledTeamIds.contains(project.team),
        )
        .toList();
  }

  void _goToTasks() {
    setState(() {
      _index = 1;
    });
  }

  void _goToTeam() {
    setState(() {
      _index = 2;
    });
  }

  void _createTask() {
    final List<ProjectModel> projects =
        _myProjects();

    if (projects.isEmpty) {
      return;
    }

    TaskActions.create(
      context,
      selectableProjects: projects,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ProjectModel> myProjects =
        _myProjects();

    return Scaffold(
      key: _scaffoldKey,

      endDrawer: AssistantPanel(
        destinations: const <String, int>{
          'dashboard': 0,
          'tasks': 1,
          'team': 2,
          'my_team': 2,
          'calendar': 3,
          'more': 4,
        },
        onGoTo: (int index) {
          setState(() {
            _index = index;
          });
        },
      ),

      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: <Widget>[
          IconButton(
            tooltip: 'Assistant',
            onPressed: () {
              _scaffoldKey.currentState
                  ?.openEndDrawer();
            },
            icon: const Icon(
              Icons.auto_awesome,
            ),
          ),
          const NotificationBell(),
          IconButton(
            tooltip: 'Profile',
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const ProfileScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.account_circle_outlined,
            ),
          ),
        ],
      ),

      body: Column(
        children: <Widget>[
          const OfflineBanner(),

          Expanded(
            child: IndexedStack(
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
          ),
        ],
      ),

      floatingActionButton:
          (_index == 1 || _index == 3) &&
                  myProjects.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: _createTask,
                  icon: const Icon(
                    Icons.add,
                  ),
                  label: const Text(
                    'New task',
                  ),
                )
              : null,

      bottomNavigationBar:
          NavigationBar(
        selectedIndex: _index,

        onDestinationSelected:
            (int value) {
          setState(() {
            _index = value;
          });
        },

        destinations:
            const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(
              Icons
                  .space_dashboard_outlined,
            ),
            selectedIcon: Icon(
              Icons.space_dashboard,
            ),
            label: 'Dashboard',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.task_alt_outlined,
            ),
            selectedIcon: Icon(
              Icons.task_alt,
            ),
            label: 'Tasks',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.groups_outlined,
            ),
            selectedIcon: Icon(
              Icons.groups,
            ),
            label: 'My team',
          ),

          NavigationDestination(
            icon: Icon(
              Icons
                  .calendar_month_outlined,
            ),
            selectedIcon: Icon(
              Icons.calendar_month,
            ),
            label: 'Calendar',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.more_horiz,
            ),
            label: 'More',
          ),
        ],
      ),
    );
  }
}