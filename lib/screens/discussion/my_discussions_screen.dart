import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/admin/async_view.dart';
import 'project_discussion_screen.dart';

/// The projects a person can talk in.
///
/// Built from their tasks: an employee has no project list of their own.
/// If /projects/ does not return the project - which happens when the
/// backend scopes that endpoint more tightly than /tasks/ - the entry
/// still appears, named by its id, so the discussion stays reachable.
class MyDiscussionsScreen extends StatelessWidget {
  const MyDiscussionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TaskProvider tasks = context.watch<TaskProvider>();
    final ProjectProvider projects = context.watch<ProjectProvider>();

    // Keep the first-seen order rather than sorting by id - the project
    // with the most recent task tends to be the one wanted.
    final List<int> projectIds = <int>[];

    for (final TaskModel task in tasks.allTasks) {
      if (!projectIds.contains(task.project)) {
        projectIds.add(task.project);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My projects')),
      body: AsyncView(
        isLoading: tasks.isLoading && tasks.allTasks.isEmpty,
        error: tasks.allTasks.isEmpty ? tasks.error : null,
        isEmpty: projectIds.isEmpty,
        onRetry: tasks.refresh,
        emptyIcon: Icons.forum_outlined,
        emptyTitle: 'No projects yet',
        emptyMessage:
            'Once you have a task on a project, it appears here.',
        child: RefreshIndicator(
          onRefresh: tasks.refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: projectIds.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final int id = projectIds[index];
              final ProjectModel? project = projects.byId(id);
              final String name = project?.name ?? 'Project #$id';

              final int open = tasks
                  .forProject(id)
                  .where((TaskModel t) => !t.isCompleted)
                  .length;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.forum_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '$open open ${open == 1 ? 'task' : 'tasks'} · '
                    'tap to open the discussion',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ProjectDiscussionScreen(
                        projectId: id,
                        projectName: name,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
