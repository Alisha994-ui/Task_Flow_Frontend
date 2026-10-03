import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/task_constants.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../models/task_model.dart';
import '../../../providers/task_provider.dart';
import '../../../widgets/admin/async_view.dart';
import '../../../widgets/manager/task_tile.dart';
import '../task_actions.dart';
import '../task_detail_screen.dart';

/// Month grid of task due dates. Tapping a day lists that day's tasks.
class ManagerCalendarTab extends StatefulWidget {
  const ManagerCalendarTab({super.key, this.canManage = true});

  /// False hides edit, reassign and delete - used by the employee panel.
  final bool canManage;

  @override
  State<ManagerCalendarTab> createState() => _ManagerCalendarTabState();
}

class _ManagerCalendarTabState extends State<ManagerCalendarTab> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  static const List<String> _monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekdayLabels = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _shiftMonth(int months) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + months,
      );
    });
  }

  void _goToToday() {
    final DateTime now = DateTime.now();

    setState(() {
      _visibleMonth = DateTime(now.year, now.month);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final TaskProvider tasks = context.watch<TaskProvider>();
    final List<TaskModel> dayTasks = tasks.dueOn(_selectedDay);

    return AsyncView(
      isLoading: tasks.isLoading && tasks.allTasks.isEmpty,
      error: tasks.allTasks.isEmpty ? tasks.error : null,
      isEmpty: false,
      onRetry: tasks.refresh,
      child: Column(
        children: <Widget>[
          _MonthHeader(
            label: '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
            onPrevious: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
            onToday: _goToToday,
          ),
          _WeekdayRow(labels: _weekdayLabels),
          _MonthGrid(
            month: _visibleMonth,
            selectedDay: _selectedDay,
            tasks: tasks.allTasks,
            onSelect: (DateTime day) => setState(() => _selectedDay = day),
          ),
          const Divider(height: 1),
          Expanded(
            child: dayTasks.isEmpty
                ? _EmptyDay(day: _selectedDay)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: dayTasks.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 2),
                          child: Text(
                            '${dayTasks.length} due on ${formatDate(_selectedDay)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        );
                      }

                      final TaskModel task = dayTasks[index - 1];

                      return TaskTile(
                        task: task,
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => TaskDetailScreen(
                              taskId: task.id,
                              canManage: widget.canManage,
                            ),
                          ),
                        ),
                        onStatusTap: () =>
                            TaskActions.changeStatus(context, task),
                        onAssignTap: widget.canManage
                            ? () => TaskActions.reassign(context, task)
                            : null,
                        onEdit: widget.canManage
                            ? () => TaskActions.edit(context, task)
                            : null,
                        onDelete: widget.canManage
                            ? () => TaskActions.delete(context, task)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Previous month',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
          TextButton(onPressed: onToday, child: const Text('Today')),
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: labels
            .map(
              (String label) => Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDay,
    required this.tasks,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selectedDay;
  final List<TaskModel> tasks;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final DateTime firstOfMonth = DateTime(month.year, month.month);
    final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // DateTime.weekday is 1 for Monday, so this many blanks come first.
    final int leadingBlanks = firstOfMonth.weekday - 1;
    final int cellCount = leadingBlanks + daysInMonth;
    final int rows = (cellCount / 7).ceil();

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        children: List<Widget>.generate(rows, (int row) {
          return Row(
            children: List<Widget>.generate(7, (int column) {
              final int cellIndex = row * 7 + column;
              final int dayNumber = cellIndex - leadingBlanks + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const Expanded(child: SizedBox(height: 46));
              }

              final DateTime day =
                  DateTime(month.year, month.month, dayNumber);

              final List<TaskModel> dayTasks =
                  tasks.where((TaskModel t) => t.isDueOn(day)).toList();

              final bool hasOverdue =
                  dayTasks.any((TaskModel t) => t.isOverdue);
              final bool isSelected = day == selectedDay;
              final bool isToday = day == today;

              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onSelect(day),
                  child: Container(
                    height: 46,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : (isToday
                              ? theme.colorScheme.primary
                                  .withValues(alpha: 0.10)
                              : null),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          '$dayNumber',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isToday || isSelected
                                ? FontWeight.w700
                                : null,
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : null,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (dayTasks.isEmpty)
                          const SizedBox(height: 6)
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List<Widget>.generate(
                              dayTasks.length > 3 ? 3 : dayTasks.length,
                              (int i) => Container(
                                width: 5,
                                height: 5,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : (hasOverdue
                                          ? theme.colorScheme.error
                                          : TaskStatus.color(
                                              dayTasks[i].status)),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.event_available_outlined,
              size: 36,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 10),
            Text(
              'Nothing due on ${formatDate(day)}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
