import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/project_constants.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../models/project_model.dart';
import '../../../providers/admin_dashboard_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/team_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/admin/admin_widgets.dart';
import '../../../widgets/admin/async_view.dart';
import '../project_detail_screen.dart';
import '../project_form_screen.dart';

class AdminProjectsTab extends StatefulWidget {
  const AdminProjectsTab({super.key});

  @override
  State<AdminProjectsTab> createState() => _AdminProjectsTabState();
}

class _AdminProjectsTabState extends State<AdminProjectsTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController(
      text: context.read<ProjectProvider>().search,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  Future<void> _openDetail(ProjectModel project) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailScreen(projectId: project.id),
      ),
    );
  }

  Future<void> _openEdit(ProjectModel project) async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProjectFormScreen(project: project),
      ),
    );

    if (saved == true) {
      _snack('Project updated');
    }
  }

  Future<void> _toggleArchive(ProjectModel project) async {
    final ProjectProvider provider = context.read<ProjectProvider>();
    final bool ok = await provider.toggleArchive(project);

    if (ok) {
      _snack(project.isArchived ? 'Project restored' : 'Project archived');
    } else {
      _snack(
        provider.error ?? 'Could not update the project',
        isError: true,
      );
    }
  }

  Future<void> _confirmDelete(ProjectModel project) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete this project?'),
          content: Text(
            '"${project.name}" and its member links will be removed. '
            'This cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep it'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final ProjectProvider provider = context.read<ProjectProvider>();
    final bool ok = await provider.deleteProject(project.id);

    if (ok) {
      _snack('Project deleted');

      if (mounted) {
        await context.read<AdminDashboardProvider>().refresh();
      }
    } else {
      _snack(
        provider.error ?? 'Could not delete the project',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProjectProvider provider = context.watch<ProjectProvider>();
    final List<ProjectModel> projects = provider.projects;

    return Column(
      children: <Widget>[
        _FilterBar(controller: _searchController),
        Expanded(
          child: AsyncView(
            isLoading: provider.isLoading && provider.allProjects.isEmpty,
            error: provider.allProjects.isEmpty ? provider.error : null,
            isEmpty: projects.isEmpty,
            onRetry: provider.refresh,
            emptyIcon: Icons.folder_off_outlined,
            emptyTitle: provider.hasActiveFilters
                ? 'No projects match these filters'
                : 'No projects yet',
            emptyMessage: provider.hasActiveFilters
                ? 'Clear the filters to see everything again.'
                : 'Tap "New project" to create the first one.',
            emptyAction: provider.hasActiveFilters
                ? TextButton(
                    onPressed: () {
                      _searchController.clear();
                      provider.clearFilters();
                    },
                    child: const Text('Clear filters'),
                  )
                : null,
            child: RefreshIndicator(
              onRefresh: provider.refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 180),
                itemCount: projects.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) {
                  final ProjectModel project = projects[index];

                  return _ProjectCard(
                    project: project,
                    onTap: () => _openDetail(project),
                    onEdit: () => _openEdit(project),
                    onArchive: () => _toggleArchive(project),
                    onDelete: () => _confirmDelete(project),
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ProjectProvider provider = context.watch<ProjectProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: <Widget>[
          TextField(
            controller: controller,
            onChanged: provider.setSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search projects',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: provider.search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        controller.clear();
                        provider.setSearch('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _DropdownFilter(
                  icon: Icons.flag_outlined,
                  value: provider.statusFilter,
                  allLabel: 'All statuses',
                  values: ProjectStatus.all,
                  labelBuilder: ProjectStatus.label,
                  onChanged: provider.setStatusFilter,
                ),
                const SizedBox(width: 8),
                _DropdownFilter(
                  icon: Icons.priority_high,
                  value: provider.priorityFilter,
                  allLabel: 'All priorities',
                  values: ProjectPriority.all,
                  labelBuilder: ProjectPriority.label,
                  onChanged: provider.setPriorityFilter,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: const Text('Include archived'),
                  selected: provider.showArchived,
                  onSelected: provider.setShowArchived,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  const _DropdownFilter({
    required this.icon,
    required this.value,
    required this.allLabel,
    required this.values,
    required this.labelBuilder,
    required this.onChanged,
  });

  final IconData icon;
  final String value;
  final String allLabel;
  final List<String> values;
  final String Function(String) labelBuilder;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.expand_more, size: 18),
          borderRadius: BorderRadius.circular(12),
          style: theme.textTheme.bodyMedium,
          items: <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(
              value: kFilterAll,
              child: Row(
                children: <Widget>[
                  Icon(
                    icon,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Text(allLabel),
                ],
              ),
            ),
            ...values.map(
              (String item) => DropdownMenuItem<String>(
                value: item,
                child: Text(labelBuilder(item)),
              ),
            ),
          ],
          onChanged: (String? selected) {
            if (selected != null) {
              onChanged(selected);
            }
          },
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  final ProjectModel project;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final UserProvider users = context.watch<UserProvider>();
    final TeamProvider teams = context.watch<TeamProvider>();
    final bool overdue = isOverdue(project.endDate, project.status);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      project.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Project actions',
                    onSelected: (String action) {
                      switch (action) {
                        case 'edit':
                          onEdit();
                          break;
                        case 'archive':
                          onArchive();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'archive',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            project.isArchived
                                ? Icons.unarchive_outlined
                                : Icons.archive_outlined,
                          ),
                          title: Text(
                            project.isArchived ? 'Restore' : 'Archive',
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                          ),
                          title: Text(
                            'Delete',
                            style: TextStyle(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (project.description.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 10),
                  child: Text(
                    project.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  LabelChip(
                    text: ProjectStatus.label(project.status),
                    color: ProjectStatus.color(project.status),
                  ),
                  LabelChip(
                    text: ProjectPriority.label(project.priority),
                    color: ProjectPriority.color(project.priority),
                    icon: Icons.flag_outlined,
                  ),
                  if (project.isArchived)
                    const LabelChip(
                      text: 'Archived',
                      color: Color(0xFF6B7280),
                      icon: Icons.inventory_2_outlined,
                    ),
                  if (overdue)
                    const LabelChip(
                      text: 'Past due date',
                      color: Color(0xFFDC2626),
                      icon: Icons.schedule,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (project.progress / 100).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${project.progress}%',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      users.nameFor(project.manager),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.groups_outlined,
                    size: 14,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      teams.nameFor(project.team),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${formatDate(project.startDate)}  to  ${formatDate(project.endDate)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}