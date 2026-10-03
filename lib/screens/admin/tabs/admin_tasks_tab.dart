import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/project_constants.dart';
import '../../../core/constants/task_constants.dart';
import '../../../models/project_model.dart';
import '../../../models/task_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/admin/async_view.dart';
import '../../../widgets/manager/task_tile.dart';
import '../../manager/task_actions.dart';
import '../../manager/task_detail_screen.dart';

/// Every task in the system. The backend returns all of them for an ADMIN,
/// so the filters here are the only narrowing.
class AdminTasksTab extends StatefulWidget {
  const AdminTasksTab({super.key});

  @override
  State<AdminTasksTab> createState() => _AdminTasksTabState();
}

class _AdminTasksTabState extends State<AdminTasksTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController(
      text: context.read<TaskProvider>().search,
    );

    // Load on our own so this tab works inside any shell.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<TaskProvider>().ensureLoaded();
      context.read<ProjectProvider>().ensureLoaded();
      context.read<UserProvider>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TaskProvider tasks = context.watch<TaskProvider>();
    final ProjectProvider projects = context.watch<ProjectProvider>();
    final UserProvider users = context.watch<UserProvider>();

    final List<ProjectModel> allProjects = projects.allProjects;
    final List<TaskModel> visible = tasks.tasks;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: <Widget>[
              TextField(
                controller: _searchController,
                onChanged: tasks.setSearch,
                decoration: InputDecoration(
                  hintText: 'Search tasks',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: tasks.search.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            tasks.setSearch('');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    FilterChip(
                      avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                      label: const Text('Overdue'),
                      selected: tasks.overdueOnly,
                      onSelected: tasks.setOverdueOnly,
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('All'),
                      selected: tasks.statusFilter == kFilterAll,
                      onSelected: (_) => tasks.setStatusFilter(kFilterAll),
                    ),
                    ...TaskStatus.all.map(
                      (String status) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(TaskStatus.label(status)),
                          selected: tasks.statusFilter == status,
                          onSelected: (_) => tasks.setStatusFilter(status),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: allProjects
                              .any((ProjectModel p) => p.id == tasks.projectFilter)
                          ? tasks.projectFilter
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Project',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All projects'),
                        ),
                        ...allProjects.map(
                          (ProjectModel p) => DropdownMenuItem<int?>(
                            value: p.id,
                            child:
                                Text(p.name, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: tasks.setProjectFilter,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: users.allUsers
                              .any((UserModel u) => u.id == tasks.assigneeFilter)
                          ? tasks.assigneeFilter
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Assignee',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Anyone'),
                        ),
                        ...users.allUsers.map(
                          (UserModel u) => DropdownMenuItem<int?>(
                            value: u.id,
                            child: Text(
                              u.fullName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: tasks.setAssigneeFilter,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (visible.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(
              children: <Widget>[
                Text(
                  '${visible.length} of ${tasks.allTasks.length} tasks',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (tasks.hasFilters)
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      tasks.clearFilters();
                    },
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
          ),
        Expanded(
          child: AsyncView(
            isLoading: tasks.isLoading && tasks.allTasks.isEmpty,
            error: tasks.allTasks.isEmpty ? tasks.error : null,
            isEmpty: visible.isEmpty,
            onRetry: tasks.refresh,
            emptyIcon: Icons.task_alt,
            emptyTitle: tasks.hasFilters
                ? 'No tasks match these filters'
                : 'No tasks yet',
            emptyMessage: tasks.hasFilters
                ? 'Clear the filters to see everything again.'
                : 'Tasks created in any project show up here.',
            emptyAction: tasks.hasFilters
                ? TextButton(
                    onPressed: () {
                      _searchController.clear();
                      tasks.clearFilters();
                    },
                    child: const Text('Clear filters'),
                  )
                : null,
            child: RefreshIndicator(
              onRefresh: tasks.refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) {
                  final TaskModel task = visible[index];

                  return TaskTile(
                    task: task,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => TaskDetailScreen(taskId: task.id),
                      ),
                    ),
                    onStatusTap: () => TaskActions.changeStatus(context, task),
                    onAssignTap: () => TaskActions.reassign(context, task),
                    onEdit: () => TaskActions.edit(context, task),
                    onDelete: () => TaskActions.delete(context, task),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
