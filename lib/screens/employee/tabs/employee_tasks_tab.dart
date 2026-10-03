import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/project_constants.dart';
import '../../../core/constants/task_constants.dart';
import '../../../models/task_model.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/time_log_provider.dart';
import '../../../widgets/admin/async_view.dart';
import '../../../widgets/manager/task_tile.dart';
import '../../manager/task_actions.dart';
import '../../manager/task_detail_screen.dart';

/// Everything assigned to the signed-in employee.
class EmployeeTasksTab extends StatefulWidget {
  const EmployeeTasksTab({super.key});

  @override
  State<EmployeeTasksTab> createState() => _EmployeeTasksTabState();
}

class _EmployeeTasksTabState extends State<EmployeeTasksTab> {
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

  Future<void> _startTimer(TaskModel task) async {
    final TimeLogProvider timer = context.read<TimeLogProvider>();
    final String? problem = await timer.start(task.id);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(problem ?? 'Timer started on "${task.title}"'),
          backgroundColor:
              problem == null ? null : Theme.of(context).colorScheme.error,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final TaskProvider tasks = context.watch<TaskProvider>();
    final TimeLogProvider timer = context.watch<TimeLogProvider>();
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
                  hintText: 'Search your tasks',
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
                : 'Nothing assigned to you',
            emptyMessage: tasks.hasFilters
                ? 'Clear the filters to see everything again.'
                : 'Your manager or team lead will assign work here.',
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
              onRefresh: () async {
                await Future.wait<void>(<Future<void>>[
                  tasks.refresh(),
                  timer.refresh(),
                ]);
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) {
                  final TaskModel task = visible[index];
                  final bool isTiming = timer.activeLog?.task == task.id;

                  return Column(
                    children: <Widget>[
                      TaskTile(
                        task: task,
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => TaskDetailScreen(
                              taskId: task.id,
                              canManage: false,
                            ),
                          ),
                        ),
                        // Completed is final for an employee.
                        onStatusTap: task.isCompleted
                            ? null
                            : () => TaskActions.changeStatus(context, task),
                      ),
                      if (!task.isCompleted)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: timer.isBusy || isTiming
                                ? null
                                : () => _startTimer(task),
                            icon: Icon(
                              isTiming ? Icons.timer : Icons.play_arrow,
                              size: 16,
                            ),
                            label: Text(
                              isTiming ? 'Timer running' : 'Start timer',
                            ),
                          ),
                        ),
                    ],
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
