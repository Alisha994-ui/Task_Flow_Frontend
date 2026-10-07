import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/project_constants.dart';
import '../../core/utils/app_date_utils.dart';
import '../../models/project_model.dart';
import '../../providers/team_provider.dart';
import '../admin/admin_widgets.dart';

/// Project card used on the manager dashboard and My projects list.
class ManagerProjectCard extends StatelessWidget {
  const ManagerProjectCard({
    super.key,
    required this.project,
    required this.onTap,
    this.compact = false,
  });

  final ProjectModel project;
  final VoidCallback onTap;

  /// Compact drops the team row - used on the dashboard preview.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TeamProvider teams = context.watch<TeamProvider>();
    final bool overdue = isOverdue(project.endDate, project.status);
    final Color statusColor = ProjectStatus.color(project.status);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 4,
                    height: 34,
                    margin: const EdgeInsets.only(right: 12, top: 2),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          project.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ProjectStatus.label(project.status),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  LabelChip(
                    text: ProjectPriority.label(project.priority),
                    color: ProjectPriority.color(project.priority),
                    icon: Icons.flag_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (project.progress / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: statusColor.withValues(alpha: 0.14),
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${project.progress}%',
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(
                    overdue ? Icons.warning_amber_rounded : Icons.event_outlined,
                    size: 15,
                    color: overdue
                        ? theme.colorScheme.error
                        : theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    dueLabel(
                      project.endDate,
                      closed: project.status == ProjectStatus.completed ||
                          project.status == ProjectStatus.cancelled,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: overdue
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: overdue ? FontWeight.w600 : null,
                    ),
                  ),
                  if (!compact) ...<Widget>[
                    const SizedBox(width: 14),
                    Icon(
                      Icons.groups_outlined,
                      size: 15,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        teams.nameFor(project.team),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
