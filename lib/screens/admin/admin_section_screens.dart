import 'package:flutter/material.dart';

import '../manager/task_actions.dart';
import 'tabs/admin_tasks_tab.dart';
import 'tabs/admin_teams_tab.dart';
import 'tabs/admin_users_tab.dart';
import 'user_form_screen.dart';

/// Full-screen wrappers around the admin tabs.
///
/// AdminPanelScreen shows these tabs inside its bottom bar. These wrappers
/// are for pushing one section on its own - for example from the quick
/// action tiles on a custom dashboard:
///
/// ```dart
/// onTap: () => Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
/// ),
/// ```
///
/// Each tab loads its own data, so nothing else has to be wired up.
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  static const String routeName = '/admin/users';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: const AdminUsersTab(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => const UserFormScreen(),
          ),
        ),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('New user'),
      ),
    );
  }
}

class AdminTeamsScreen extends StatelessWidget {
  const AdminTeamsScreen({super.key});

  static const String routeName = '/admin/teams';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teams')),
      body: const AdminTeamsTab(),
    );
  }
}

class AdminTasksScreen extends StatelessWidget {
  const AdminTasksScreen({super.key});

  static const String routeName = '/admin/tasks';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: const AdminTasksTab(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => TaskActions.create(context),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
    );
  }
}
