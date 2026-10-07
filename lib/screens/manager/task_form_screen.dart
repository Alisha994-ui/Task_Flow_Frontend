import 'package:flutter/material.dart';
import '../../core/coach/coach_target.dart';
import 'package:provider/provider.dart';

import '../../core/constants/project_constants.dart';
import '../../core/constants/task_constants.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/project_rules.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../models/team_model.dart';
import '../../models/user_model.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_provider.dart';
import '../../providers/user_provider.dart';

/// Create a task when [task] is null, otherwise edit it.
///
/// [initialProjectId] preselects the project when the form is opened from a
/// project screen.
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    super.key,
    this.task,
    this.initialProjectId,
    this.selectableProjects,
  });

  final TaskModel? task;
  final int? initialProjectId;

  /// Projects offered in the dropdown.
  ///
  /// When provided, ONLY these projects can be selected.
  /// Admin can leave this null to use all active projects.
  final List<ProjectModel>? selectableProjects;

  bool get isEdit => task != null;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  int? _projectId;
  int? _assigneeId;
  String _priority = TaskPriority.medium;
  String _status = TaskStatus.todo;
  DateTime? _startDate;
  DateTime? _dueDate;
  int _progress = 0;

  @override
  void initState() {
    super.initState();

    final TaskModel? task = widget.task;

    _titleController =
        TextEditingController(text: task?.title ?? '');

    _descriptionController =
        TextEditingController(text: task?.description ?? '');

    if (task != null) {
      _projectId = task.project;
      _assigneeId = task.assignee;
      _priority = task.priority;
      _status = task.status;
      _startDate = task.startDate;
      _dueDate = task.dueDate;
      _progress = task.progress;
    } else {
      _projectId = widget.initialProjectId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// People who can take this task are limited to the selected
  /// project's team members and team lead.
  List<UserModel> _candidates() {
    if (_projectId == null) {
      return const <UserModel>[];
    }

    final UserProvider users =
        context.read<UserProvider>();

    final TeamProvider teams =
        context.read<TeamProvider>();

    final ProjectProvider projects =
        context.read<ProjectProvider>();

    final ProjectModel? project =
        projects.byId(_projectId!);

    if (project == null || project.team == null) {
      return const <UserModel>[];
    }

    final TeamModel? team =
        teams.byId(project.team);

    if (team == null) {
      return const <UserModel>[];
    }

    final Set<int> memberIds = <int>{
      ...team.members,
      if (team.teamLead != null) team.teamLead!,
    };

    return users.allUsers
        .where(
          (UserModel user) =>
              memberIds.contains(user.id),
        )
        .toList();
  }

  Future<void> _pickDate({
    required bool isStart,
  }) async {
    final DateTime initial =
        (isStart ? _startDate : _dueDate) ??
            _startDate ??
            DateTime.now();

    final DateTime? picked =
        await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText:
          isStart
              ? 'Select start date'
              : 'Select due date',
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _startDate = picked;

        if (_dueDate != null &&
            _dueDate!.isBefore(picked)) {
          _dueDate = null;
        }
      } else {
        _dueDate = picked;
      }
    });
  }

  void _snack(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : null,
        ),
      );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ??
        false)) {
      return;
    }

    if (_projectId == null) {
      _snack(
        'Pick the project this task belongs to',
        isError: true,
      );
      return;
    }

    /*
     * If selectableProjects was supplied, the task MUST belong
     * to one of those projects.
     *
     * This prevents Team Lead / Project Manager from changing
     * the project to another project through the form state.
     */
    if (widget.selectableProjects != null) {
      final bool projectAllowed =
          widget.selectableProjects!.any(
        (ProjectModel project) =>
            project.id == _projectId,
      );

      if (!projectAllowed) {
        _snack(
          'You cannot create a task in this project',
          isError: true,
        );
        return;
      }
    }

    // The serializer rejects this too; catching it here saves a round trip.
    if (_startDate != null &&
        _dueDate != null &&
        _dueDate!.isBefore(_startDate!)) {
      _snack(
        'The due date cannot be before the start date',
        isError: true,
      );
      return;
    }

    /*
     * Assignee must belong to the selected project's team.
     */
    if (_assigneeId != null) {
      final List<UserModel> candidates =
          _candidates();

      final bool assigneeAllowed =
          candidates.any(
        (UserModel user) =>
            user.id == _assigneeId,
      );

      if (!assigneeAllowed) {
        _snack(
          'This user is not a member of the selected project team',
          isError: true,
        );
        return;
      }
    }

    final TaskProvider tasks =
        context.read<TaskProvider>();

    Object? result;

    if (widget.isEdit) {
      result = await tasks.patchTask(
        widget.task!.id,
        <String, dynamic>{
          'project': _projectId,
          'title': _titleController.text.trim(),
          'description':
              _descriptionController.text.trim(),
          'assignee': _assigneeId,
          'priority': _priority,
          'status': _status,
          'start_date':
              apiDateOrNull(_startDate),
          'due_date':
              apiDateOrNull(_dueDate),
          'progress': _progress,
        },
      );
    } else {
      result = await tasks.createTask(
        project: _projectId!,
        title: _titleController.text.trim(),
        description:
            _descriptionController.text.trim(),
        assignee: _assigneeId,
        priority: _priority,
        status: _status,
        startDate:
            apiDateOrNull(_startDate),
        dueDate:
            apiDateOrNull(_dueDate),
        progress: _progress,
      );
    }

    if (!mounted) {
      return;
    }

    if (result == null) {
      _snack(
        tasks.error ?? 'Could not save the task',
        isError: true,
      );
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    final TaskProvider tasks =
        context.watch<TaskProvider>();

    final ProjectProvider projects =
        context.watch<ProjectProvider>();

    /*
     * IMPORTANT:
     *
     * If selectableProjects is provided by Team Lead / Manager,
     * ONLY that list is used.
     *
     * Admin can leave selectableProjects null and gets all projects.
     */
    final List<ProjectModel> myProjects =
        (widget.selectableProjects ??
                projects.allProjects)
            .where(
              (ProjectModel p) =>
                  !isProjectClosed(p),
            )
            .toList();

    final List<UserModel> candidates =
        _candidates();

    final bool assigneeExists =
        candidates.any(
      (UserModel u) =>
          u.id == _assigneeId,
    );

    /*
     * Make sure the current project is actually
     * available in the allowed project list.
     */
    final bool projectExists =
        myProjects.any(
      (ProjectModel p) =>
          p.id == _projectId,
    );

    /*
     * If an invalid project was supplied through
     * initialProjectId/task, don't allow it to remain selected.
     */
    if (_projectId != null &&
        !projectExists) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        if (_projectId != null &&
            !myProjects.any(
              (ProjectModel p) =>
                  p.id == _projectId,
            )) {
          setState(() {
            _projectId = null;
            _assigneeId = null;
          });
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEdit
              ? 'Edit task'
              : 'New task',
        ),
      ),

      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            32,
          ),
          children: <Widget>[
            if (myProjects.isEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme
                      .colorScheme
                      .errorContainer,
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Text(
                  "You have no open projects yet, so there's nothing to "
                  'put a task on. Ask an admin to add you to a team first.',
                  style: TextStyle(
                    color: theme.colorScheme
                        .onErrorContainer,
                  ),
                ),
              )
            else
              CoachTarget(
                name: 'task_project',
                child:
                    DropdownButtonFormField<int>(
                  initialValue:
                      myProjects.any(
                    (ProjectModel p) =>
                        p.id == _projectId,
                  )
                          ? _projectId
                          : null,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(
                    labelText: 'Project',
                    border:
                        OutlineInputBorder(),
                  ),
                  items: myProjects
                      .map(
                        (
                          ProjectModel p,
                        ) =>
                            DropdownMenuItem<int>(
                          value: p.id,
                          child: Text(
                            p.name,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: tasks.isSaving
                      ? null
                      : (int? value) {
                          setState(() {
                            _projectId =
                                value;

                            /*
                             * Changing project means
                             * previous assignee may no
                             * longer belong to this team.
                             */
                            _assigneeId =
                                null;
                          });
                        },
                  validator:
                      (int? value) =>
                          value == null
                              ? 'Select a project'
                              : null,
                ),
              ),

            const SizedBox(height: 16),

            CoachTarget(
              name: 'task_title',
              child: TextFormField(
                controller:
                    _titleController,
                textCapitalization:
                    TextCapitalization
                        .sentences,
                decoration:
                    const InputDecoration(
                  labelText: 'Title',
                  border:
                      OutlineInputBorder(),
                ),
                validator:
                    (String? value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Give the task a title';
                  }

                  if (value.trim().length >
                      200) {
                    return 'Keep the title under 200 characters';
                  }

                  return null;
                },
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller:
                  _descriptionController,
              maxLines: 4,
              textCapitalization:
                  TextCapitalization.sentences,
              decoration:
                  const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            CoachTarget(
              name: 'task_assignee',
              child:
                  DropdownButtonFormField<int?>(
                initialValue:
                    assigneeExists
                        ? _assigneeId
                        : null,
                isExpanded: true,
                decoration:
                    InputDecoration(
                  labelText: 'Assignee',
                  border:
                      const OutlineInputBorder(),
                  helperText:
                      _projectId == null
                          ? 'Pick a project first to narrow this list'
                          : 'Only members of the selected project team can be assigned',
                ),
                items:
                    <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<
                      int?>(
                    value: null,
                    child:
                        Text('Unassigned'),
                  ),
                  ...candidates.map(
                    (
                      UserModel user,
                    ) =>
                        DropdownMenuItem<
                            int?>(
                      value: user.id,
                      child: Text(
                        '${user.fullName} - ${UserRoles.label(user.role)}',
                        overflow:
                            TextOverflow
                                .ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged:
                    (int? value) {
                  setState(
                    () =>
                        _assigneeId =
                            value,
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: <Widget>[
                Expanded(
                  child:
                      DropdownButtonFormField<
                          String>(
                    initialValue:
                        _status,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Status',
                      border:
                          OutlineInputBorder(),
                    ),
                    items: TaskStatus.all
                        .map(
                          (
                            String value,
                          ) =>
                              DropdownMenuItem<
                                  String>(
                            value:
                                value,
                            child: Text(
                              TaskStatus.label(
                                value,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged:
                        (String? value) {
                      if (value ==
                          null) {
                        return;
                      }

                      setState(() {
                        _status =
                            value;

                        if (value ==
                            TaskStatus
                                .completed) {
                          _progress = 100;
                        } else if (value ==
                            TaskStatus.todo) {
                          _progress = 0;
                        }
                      });
                    },
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child:
                      DropdownButtonFormField<
                          String>(
                    initialValue:
                        _priority,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Priority',
                      border:
                          OutlineInputBorder(),
                    ),
                    items: TaskPriority.all
                        .map(
                          (
                            String value,
                          ) =>
                              DropdownMenuItem<
                                  String>(
                            value:
                                value,
                            child: Text(
                              TaskPriority.label(
                                value,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged:
                        (String? value) {
                      if (value !=
                          null) {
                        setState(
                          () =>
                              _priority =
                                  value,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: <Widget>[
                Expanded(
                  child: _DateField(
                    label:
                        'Start date',
                    value:
                        _startDate,
                    onTap: () =>
                        _pickDate(
                      isStart: true,
                    ),
                    onClear:
                        _startDate ==
                                null
                            ? null
                            : () {
                                setState(
                                  () =>
                                      _startDate =
                                          null,
                                );
                              },
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child: _DateField(
                    label:
                        'Due date',
                    value:
                        _dueDate,
                    onTap: () =>
                        _pickDate(
                      isStart: false,
                    ),
                    onClear:
                        _dueDate ==
                                null
                            ? null
                            : () {
                                setState(
                                  () =>
                                      _dueDate =
                                          null,
                                );
                              },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: <Widget>[
                Text(
                  'Progress',
                  style: theme
                      .textTheme
                      .bodyMedium,
                ),
                const Spacer(),
                Text(
                  '$_progress%',
                  style: theme
                      .textTheme
                      .labelLarge,
                ),
              ],
            ),

            Slider(
              value:
                  _progress.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label:
                  '$_progress%',
              onChanged:
                  (double value) =>
                      setState(
                () => _progress =
                    value.round(),
              ),
            ),

            Text(
              'Project progress is recalculated by the backend from completed '
              'tasks, so this number only describes this task.',
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: theme.colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar:
          SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16,
          ),
          child:
              FilledButton.icon(
            onPressed:
                tasks.isSaving ||
                        myProjects.isEmpty
                    ? null
                    : _save,
            icon: tasks.isSaving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.check,
                  ),
            label: Text(
              widget.isEdit
                  ? 'Save changes'
                  : 'Create task',
            ),
            style:
                FilledButton.styleFrom(
              minimumSize:
                  const Size
                      .fromHeight(
                48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(4),
      child: InputDecorator(
        decoration:
            InputDecoration(
          labelText: label,
          border:
              const OutlineInputBorder(),
          suffixIcon:
              onClear == null
                  ? const Icon(
                      Icons
                          .calendar_today_outlined,
                      size: 18,
                    )
                  : IconButton(
                      icon:
                          const Icon(
                        Icons.close,
                        size: 18,
                      ),
                      onPressed:
                          onClear,
                    ),
        ),
        child: Text(
          formatDate(
            value,
            fallback:
                'Not set',
          ),
          overflow:
              TextOverflow.ellipsis,
        ),
      ),
    );
  }
}