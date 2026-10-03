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
import 'task_actions.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/notification_bell.dart';
import '../../screens/profile/profile_screen.dart';
import 'tabs/manager_calendar_tab.dart';
import 'tabs/manager_dashboard_tab.dart';
import 'tabs/manager_more_tab.dart';
import 'tabs/manager_projects_tab.dart';
import 'tabs/manager_tasks_tab.dart';

/// Entry point for the Project Manager experience.
///
/// Pass the signed-in manager's id when pushing this route:
/// `Navigator.pushReplacementNamed(context, AppRoutes.managerPanel,
///   arguments: ManagerPanelArgs(managerId: user.id, managerName: user.fullName));`
class ManagerPanelScreen extends StatefulWidget {
  const ManagerPanelScreen({
    super.key,
    required this.managerId,
    this.managerName = '',
  });

  static const String routeName = '/manager';

  final int managerId;
  final String managerName;

  @override
  State<ManagerPanelScreen> createState() => _ManagerPanelScreenState();
}

/// Route arguments holder, so the route stays type safe.
class ManagerPanelArgs {
  const ManagerPanelArgs({required this.managerId, this.managerName = ''});

  final int managerId;
  final String managerName;
}

class _ManagerPanelScreenState extends State<ManagerPanelScreen> {
  int _index = 0;

  static const List<String> _titles = <String>[
    'Dashboard',
    'My projects',
    'Tasks',
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
            id: widget.managerId,
            name: widget.managerName,
            roleLabel: 'Project manager',
          );

      // Counts come from the manager endpoint, not the team-lead one.
      context.read<TaskProvider>().setStatsScope(TaskStatsScope.manager);

      await _loadAll();

      if (!mounted) {
        return;
      }

      // Fill in the display name if the route did not carry one.
      final ManagerProvider manager = context.read<ManagerProvider>();

      if (manager.managerName.isEmpty) {
        final String resolved =
            context.read<UserProvider>().nameFor(widget.managerId, fallback: '');

        if (resolved.isNotEmpty && !resolved.startsWith('User #')) {
          manager.setName(resolved);
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
      context.read<TimeLogProvider>().load(silent: true),
      tasks.load(silent: true),
      tasks.loadStats(),
    ]);
  }

  /// Projects this manager may file a task against.
  List<ProjectModel> _myProjects() {
    final ManagerProvider manager = context.read<ManagerProvider>();
    final Set<int> ledTeamIds = context
        .read<TeamProvider>()
        .allTeams
        .where((TeamModel t) => t.teamLead == manager.managerId)
        .map((TeamModel t) => t.id)
        .toSet();

    return manager.myProjects(
      context.read<ProjectProvider>().allProjects,
      ledTeamIds: ledTeamIds,
    );
  }

  void _goToProjects() => setState(() => _index = 1);

  void _goToTasks() => setState(() => _index = 2);

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
          ManagerDashboardTab(
            onSeeAllProjects: _goToProjects,
            onSeeAllTasks: _goToTasks,
          ),
          const ManagerProjectsTab(),
          const ManagerTasksTab(),
          const ManagerCalendarTab(),
          const ManagerMoreTab(),
        ],
      ),
      floatingActionButton: _index == 2 || _index == 3
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
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'Tasks',
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
