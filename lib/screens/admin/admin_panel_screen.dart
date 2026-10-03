import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_dashboard_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_provider.dart';
import '../../providers/time_log_provider.dart';
import '../../providers/user_provider.dart';
import '../manager/task_actions.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/notification_bell.dart';
import '../../screens/profile/profile_screen.dart';
import 'project_form_screen.dart';
import 'user_form_screen.dart';
import 'tabs/admin_dashboard_tab.dart';
import 'tabs/admin_projects_tab.dart';
import 'tabs/admin_tasks_tab.dart';
import 'tabs/admin_teams_tab.dart';
import 'tabs/admin_users_tab.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  static const String routeName = '/admin';

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  int _index = 0;

  static const List<String> _titles = <String>[
    'Overview',
    'Projects',
    'Tasks',
    'Users',
    'Teams',
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    if (!mounted) {
      return;
    }

    // Users and teams load up front because projects, tasks and the create
    // forms all need them to resolve names.
    await Future.wait<void>(<Future<void>>[
      context.read<AdminDashboardProvider>().load(silent: true),
      context.read<ProjectProvider>().load(silent: true),
      context.read<UserProvider>().load(silent: true),
      context.read<NotificationProvider>().load(silent: true),
      context.read<TeamProvider>().load(silent: true),
      context.read<TimeLogProvider>().load(silent: true),
      // No stats call here: the role dashboards are per-manager, and the
      // admin counts already come from /admin-dashboard/.
      context.read<TaskProvider>().load(silent: true),
    ]);
  }

  Future<void> _openCreateProject() async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const ProjectFormScreen(),
      ),
    );

    if (saved == true && mounted) {
      await context.read<AdminDashboardProvider>().refresh();
    }
  }

  Future<void> _openCreateUser() async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const UserFormScreen(),
      ),
    );

    if (saved == true && mounted) {
      await context.read<AdminDashboardProvider>().refresh();
    }
  }

  Widget? _buildFab() {
    if (_index == 1) {
      return FloatingActionButton.extended(
        onPressed: _openCreateProject,
        icon: const Icon(Icons.add),
        label: const Text('New project'),
      );
    }

    if (_index == 2) {
      return FloatingActionButton.extended(
        onPressed: () => TaskActions.create(context),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      );
    }

    if (_index == 3) {
      return FloatingActionButton.extended(
        onPressed: _openCreateUser,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('New user'),
      );
    }

    return null;
  }

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
        children: const <Widget>[
          AdminDashboardTab(),
          AdminProjectsTab(),
          AdminTasksTab(),
          AdminUsersTab(),
          AdminTeamsTab(),
        ],
      ),
      floatingActionButton: _buildFab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
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
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Teams',
          ),
        ],
      ),
    );
  }
}
