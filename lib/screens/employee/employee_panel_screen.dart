import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/manager_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_provider.dart';
import '../../providers/time_log_provider.dart';
import '../../providers/user_provider.dart';
import '../manager/tabs/manager_calendar_tab.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/notification_bell.dart';
import '../../screens/profile/profile_screen.dart';
import 'tabs/employee_dashboard_tab.dart';
import 'tabs/employee_more_tab.dart';
import 'tabs/employee_tasks_tab.dart';

/// Entry point for the Employee experience.
///
/// Push it with the signed-in user's id:
/// `Navigator.pushReplacementNamed(context, AppRoutes.employeePanel,
///   arguments: EmployeePanelArgs(userId: user.id, userName: user.fullName));`
///
/// The backend narrows `/tasks/` to `assignee=user` for this role, so every
/// list in here is already personal.
class EmployeePanelScreen extends StatefulWidget {
  const EmployeePanelScreen({
    super.key,
    required this.userId,
    this.userName = '',
  });

  static const String routeName = '/employee';

  final int userId;
  final String userName;

  @override
  State<EmployeePanelScreen> createState() => _EmployeePanelScreenState();
}

/// Route arguments holder.
class EmployeePanelArgs {
  const EmployeePanelArgs({required this.userId, this.userName = ''});

  final int userId;
  final String userName;
}

class _EmployeePanelScreenState extends State<EmployeePanelScreen> {
  int _index = 0;

  static const List<String> _titles = <String>[
    'Today',
    'My tasks',
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
            roleLabel: 'Employee',
          );

      final TaskProvider tasks = context.read<TaskProvider>();

      // Counts come from /tasks/dashboard/, and a status change must go
      // through /tasks/{id}/status/ - the only task write an employee has.
      tasks.setStatsScope(TaskStatsScope.assignee);
      tasks.setStatusEndpoint(TaskStatusEndpoint.assigneeAction);
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
      context.read<TimeLogProvider>().load(silent: true),
      tasks.load(silent: true),
      tasks.loadStats(),
    ]);
  }

  void _goToTasks() => setState(() => _index = 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: <Widget>[
          const NotificationBell(canManageTasks: false),
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
          EmployeeDashboardTab(onSeeAllTasks: _goToTasks),
          const EmployeeTasksTab(),
          const ManagerCalendarTab(canManage: false),
          const EmployeeMoreTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'My tasks',
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
