import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/admin_dashboard_model.dart';
import '../../../providers/admin_dashboard_provider.dart';
import '../../../widgets/admin/admin_widgets.dart';
import '../../../widgets/admin/async_view.dart';

class AdminDashboardTab extends StatelessWidget {
  const AdminDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AdminDashboardProvider provider =
        context.watch<AdminDashboardProvider>();
    final AdminDashboardModel? data = provider.dashboard;

    return AsyncView(
      isLoading: provider.isLoading && data == null,
      error: data == null ? provider.error : null,
      isEmpty: false,
      onRetry: provider.refresh,
      child: RefreshIndicator(
        onRefresh: provider.refresh,
        child: data == null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const <Widget>[SizedBox(height: 400)],
              )
            : _DashboardBody(data: data, completionRate: provider.completionRate),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data, required this.completionRate});

  final AdminDashboardModel data;
  final int completionRate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double width = MediaQuery.of(context).size.width;
    final int columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        _CompletionCard(
          completionRate: completionRate,
          completed: data.completedTasks,
          total: data.totalTasks,
        ),
        const SizedBox(height: 20),
        const SectionHeader(
          title: 'At a glance',
          subtitle: 'Live counts from the admin dashboard endpoint',
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: <Widget>[
            StatCard(
              label: 'Total users',
              value: data.totalUsers,
              icon: Icons.people_outline,
              color: const Color(0xFF2563EB),
            ),
            StatCard(
              label: 'Active users',
              value: data.activeUsers,
              icon: Icons.verified_user_outlined,
              color: const Color(0xFF059669),
            ),
            StatCard(
              label: 'Projects',
              value: data.totalProjects,
              icon: Icons.folder_outlined,
              color: const Color(0xFF7C3AED),
            ),
            StatCard(
              label: 'Total tasks',
              value: data.totalTasks,
              icon: Icons.checklist_outlined,
              color: const Color(0xFF0891B2),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionHeader(
          title: 'Task breakdown',
          subtitle: 'Where the work currently sits',
        ),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: <Widget>[
                ProgressRow(
                  label: 'Completed',
                  value: data.completedTasks,
                  total: data.totalTasks,
                  color: const Color(0xFF059669),
                ),
                ProgressRow(
                  label: 'In progress',
                  value: data.inProgressTasks,
                  total: data.totalTasks,
                  color: const Color(0xFF2563EB),
                ),
                ProgressRow(
                  label: 'Pending',
                  value: data.pendingTasks,
                  total: data.totalTasks,
                  color: const Color(0xFFD97706),
                ),
                ProgressRow(
                  label: 'Overdue',
                  value: data.overdueTasks,
                  total: data.totalTasks,
                  color: const Color(0xFFDC2626),
                ),
              ],
            ),
          ),
        ),
        if (data.overdueTasks > 0) ...<Widget>[
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            color: theme.colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.onErrorContainer,
              ),
              title: Text(
                '${data.overdueTasks} overdue ${data.overdueTasks == 1 ? 'task' : 'tasks'}',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
              subtitle: Text(
                'These passed their due date and are still open.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({
    required this.completionRate,
    required this.completed,
    required this.total,
  });

  final int completionRate;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            SizedBox(
              height: 78,
              width: 78,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  SizedBox(
                    height: 78,
                    width: 78,
                    child: CircularProgressIndicator(
                      value: total == 0 ? 0 : completed / total,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      backgroundColor: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  Text(
                    '$completionRate%',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Task completion',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total == 0
                        ? 'No tasks have been created yet.'
                        : '$completed of $total tasks are done.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
