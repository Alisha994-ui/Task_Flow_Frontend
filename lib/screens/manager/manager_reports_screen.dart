import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/task_constants.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../models/team_model.dart';
import '../../providers/manager_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/admin/admin_widgets.dart';
import 'task_detail_screen.dart';

/// Everything here is computed from the task list already in memory, so no
/// extra endpoint is needed.
class ManagerReportsScreen extends StatelessWidget {
  const ManagerReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TaskProvider tasks = context.watch<TaskProvider>();
    final ProjectProvider projects = context.watch<ProjectProvider>();
    final ManagerProvider manager = context.watch<ManagerProvider>();
    final TeamProvider teams = context.watch<TeamProvider>();
    final UserProvider users = context.watch<UserProvider>();

    final Set<int> ledTeamIds = teams.allTeams
        .where((TeamModel t) => t.teamLead == manager.managerId)
        .map((TeamModel t) => t.id)
        .toSet();

    final List<ProjectModel> myProjects =
        manager.myProjects(projects.allProjects, ledTeamIds: ledTeamIds);

    final int total = tasks.allTasks.length;
    final Map<String, int> byStatus = tasks.countsByStatus;
    final Map<String, int> byPriority = tasks.countsByPriority;
    final Map<int, int> workload = tasks.workload;

    final List<MapEntry<int, int>> sortedWorkload = workload.entries.toList()
      ..sort((MapEntry<int, int> a, MapEntry<int, int> b) =>
          b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: RefreshIndicator(
        onRefresh: tasks.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: StatCard(
                    label: 'Total tasks',
                    value: total,
                    icon: Icons.checklist_outlined,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Completed',
                    value: byStatus[TaskStatus.completed] ?? 0,
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Overdue',
                    value: tasks.overdueTasks.length,
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'By status',
              subtitle: 'Where the work sits right now',
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  children: TaskStatus.all
                      .map(
                        (String status) => ProgressRow(
                          label: TaskStatus.label(status),
                          value: byStatus[status] ?? 0,
                          total: total,
                          color: TaskStatus.color(status),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'By priority',
              subtitle: 'How much of the load is urgent',
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  children: TaskPriority.all
                      .map(
                        (String priority) => ProgressRow(
                          label: TaskPriority.label(priority),
                          value: byPriority[priority] ?? 0,
                          total: total,
                          color: TaskPriority.color(priority),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Workload',
              subtitle: 'Open tasks per person',
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: sortedWorkload.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No open tasks right now.'),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      child: Column(
                        children: sortedWorkload.map((MapEntry<int, int> entry) {
                          final bool unassigned = entry.key == -1;

                          return ProgressRow(
                            label: unassigned
                                ? 'Unassigned'
                                : users.nameFor(entry.key),
                            value: entry.value,
                            total: sortedWorkload.first.value,
                            color: unassigned
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF2563EB),
                          );
                        }).toList(),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Project completion',
              subtitle: 'Tasks completed in each of your projects',
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: myProjects.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No projects assigned to you.'),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      child: Column(
                        children: myProjects.map((ProjectModel project) {
                          final List<TaskModel> projectTasks =
                              tasks.forProject(project.id);

                          return ProgressRow(
                            label: project.name,
                            value: tasks.completedCountFor(project.id),
                            total: projectTasks.length,
                            color: const Color(0xFF7C3AED),
                          );
                        }).toList(),
                      ),
                    ),
            ),
            if (tasks.overdueTasks.isNotEmpty) ...<Widget>[
              const SizedBox(height: 24),
              SectionHeader(
                title: 'Needs attention',
                subtitle: '${tasks.overdueTasks.length} overdue',
              ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: tasks.overdueTasks.take(8).map((TaskModel task) {
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                      title: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${projects.byId(task.project)?.name ?? 'Project'} · '
                        '${users.nameFor(task.assignee)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => TaskDetailScreen(taskId: task.id),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            if (tasks.unassignedTasks.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.person_off_outlined),
                  title: Text(
                    '${tasks.unassignedTasks.length} open '
                    '${tasks.unassignedTasks.length == 1 ? 'task has' : 'tasks have'} '
                    'no assignee',
                  ),
                  subtitle: const Text('Assign them so they show up on someone\'s list.'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
