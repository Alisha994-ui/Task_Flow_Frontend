import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/project_constants.dart';
import '../../../core/constants/task_constants.dart';
import '../../../models/project_model.dart';
import '../../../models/task_model.dart';
import '../../../models/team_model.dart';
import '../../../providers/manager_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/team_provider.dart';
import '../../../widgets/admin/async_view.dart';
import '../../../widgets/manager/task_tile.dart';
import '../task_actions.dart';
import '../task_detail_screen.dart';

class ManagerTasksTab extends StatefulWidget {
  const ManagerTasksTab({super.key});

  @override
  State<ManagerTasksTab> createState() => _ManagerTasksTabState();
}

class _ManagerTasksTabState extends State<ManagerTasksTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController(
      text: context.read<TaskProvider>().search,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TaskProvider tasks = context.watch<TaskProvider>();
    final ProjectProvider projects = context.watch<ProjectProvider>();
    final ManagerProvider manager = context.watch<ManagerProvider>();
    final TeamProvider teams = context.watch<TeamProvider>();

    final Set<int> ledTeamIds = teams.allTeams
        .where((TeamModel t) => t.teamLead == manager.managerId)
        .map((TeamModel t) => t.id)
        .toSet();

    final List<ProjectModel> myProjects =
        manager.myProjects(projects.allProjects, ledTeamIds: ledTeamIds);

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
                      initialValue: myProjects
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
                        ...myProjects.map(
                          (ProjectModel p) => DropdownMenuItem<int?>(
                            value: p.id,
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: tasks.setProjectFilter,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: tasks.priorityFilter,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: kFilterAll,
                          child: Text('Any'),
                        ),
                        ...TaskPriority.all.map(
                          (String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(TaskPriority.label(value)),
                          ),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          tasks.setPriorityFilter(value);
                        }
                      },
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
                  '${visible.length} ${visible.length == 1 ? 'task' : 'tasks'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                : 'Create the first task for one of your projects.',
            emptyAction: tasks.hasFilters
                ? TextButton(
                    onPressed: () {
                      _searchController.clear();
                      tasks.clearFilters();
                    },
                    child: const Text('Clear filters'),
                  )
                : FilledButton.tonalIcon(
                    onPressed: () => TaskActions.create(context),
                    icon: const Icon(Icons.add),
                    label: const Text('New task'),
                  ),
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
