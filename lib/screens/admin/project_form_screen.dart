import 'package:flutter/material.dart';
import '../../core/coach/coach_target.dart';
import 'package:provider/provider.dart';

import '../../core/constants/project_constants.dart';
import '../../core/utils/app_date_utils.dart';
import '../../models/project_model.dart';
import '../../models/team_model.dart';
import '../../models/user_model.dart';
import '../../providers/coach_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/team_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/admin/admin_widgets.dart';

/// Create a project when [project] is null, otherwise edit it.
class ProjectFormScreen extends StatefulWidget {
  const ProjectFormScreen({super.key, this.project});

  final ProjectModel? project;

  bool get isEdit => project != null;

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Errors stay hidden until the first submit attempt; after that the form
  // re-validates on every change, so an error clears as soon as the field is filled.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  DateTime? _startDate;
  DateTime? _endDate;
  String _priority = ProjectPriority.medium;
  String _status = ProjectStatus.planning;
  int? _managerId;
  int? _teamId;
  bool _isArchived = false;

  @override
  void initState() {
    super.initState();

    final ProjectModel? project = widget.project;

    _nameController = TextEditingController(text: project?.name ?? '');
    _descriptionController =
        TextEditingController(text: project?.description ?? '');

    if (project != null) {
      _startDate = project.startDate;
      _endDate = project.endDate;
      _priority = project.priority;
      _status = project.status;
      _managerId = project.manager;
      _teamId = project.team;
      _isArchived = project.isArchived;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().ensureLoaded();
      // Refresh (not just ensureLoaded) so a team deactivated a moment
      // ago - here or on another device - is not offered from stale data.
      context.read<TeamProvider>().refresh();
    });

    _initialStartDate = _startDate;
    _initialEndDate = _endDate;
    _initialPriority = _priority;
    _initialStatus = _status;
    _initialManagerId = _managerId;
    _initialTeamId = _teamId;
    _initialIsArchived = _isArchived;
  }

  // Snapshot of what the form looked like when it opened, compared
  // against on Back so a clean form never triggers "Discard changes?".
  late final DateTime? _initialStartDate;
  late final DateTime? _initialEndDate;
  late final String _initialPriority;
  late final String _initialStatus;
  late final int? _initialManagerId;
  late final int? _initialTeamId;
  late final bool _initialIsArchived;

  bool get _isDirty {
    final ProjectModel? project = widget.project;

    return _nameController.text != (project?.name ?? '') ||
        _descriptionController.text != (project?.description ?? '') ||
        _startDate != _initialStartDate ||
        _endDate != _initialEndDate ||
        _priority != _initialPriority ||
        _status != _initialStatus ||
        _managerId != _initialManagerId ||
        _teamId != _initialTeamId ||
        _isArchived != _initialIsArchived;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime initial =
        (isStart ? _startDate : _endDate) ?? _startDate ?? DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: isStart ? 'Select start date' : 'Select end date',
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _startDate = picked;

        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      } else {
        _endDate = picked;
      }
    });
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

  Future<void> _save() async {
    setState(() => _autovalidateMode = AutovalidateMode.always);

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_managerId == null) {
      _snack('Pick a project manager first', isError: true);

      return;
    }

    if (_teamId == null) {
      _snack('Pick a team first', isError: true);

      return;
    }

    // Last line of defence behind the dropdown filter: never save a new
    // assignment to an inactive or empty team. A project already on such
    // a team may keep it while other fields are edited.
    final TeamModel? chosenTeam = context.read<TeamProvider>().byId(_teamId);
    final bool keepingCurrentTeam =
        widget.isEdit && _teamId == _initialTeamId;

    if (chosenTeam != null &&
        !keepingCurrentTeam &&
        (!chosenTeam.isActive || chosenTeam.members.isEmpty)) {
      _snack(
        chosenTeam.isActive
            ? '"${chosenTeam.name}" has no members. Pick a team with people in it.'
            : '"${chosenTeam.name}" is inactive. Pick an active team.',
        isError: true,
      );

      return;
    }

    if (_startDate != null && _endDate != null && _endDate!.isBefore(_startDate!)) {
      _snack('The end date cannot be before the start date', isError: true);

      return;
    }

    final ProjectProvider provider = context.read<ProjectProvider>();
    ProjectModel? result;

    if (widget.isEdit) {
      result = await provider.updateProject(
        id: widget.project!.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        startDate: apiDateOrNull(_startDate),
        endDate: apiDateOrNull(_endDate),
        priority: _priority,
        status: _status,
        manager: _managerId!,
        team: _teamId!,
        isArchived: _isArchived,
      );
    } else {
      result = await provider.createProject(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        startDate: apiDateOrNull(_startDate),
        endDate: apiDateOrNull(_endDate),
        priority: _priority,
        status: _status,
        manager: _managerId!,
        team: _teamId!,
        isArchived: _isArchived,
      );
    }

    if (!mounted) {
      return;
    }

    if (result == null) {
      _snack(provider.error ?? 'Could not save the project', isError: true);

      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ProjectProvider projects = context.watch<ProjectProvider>();
    final UserProvider users = context.watch<UserProvider>();
    final TeamProvider teams = context.watch<TeamProvider>();

    return DiscardGuard(
      isDirty: () => _isDirty,
      child: Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (BuildContext guardContext) => IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => DiscardGuard.handleBack(guardContext),
          ),
        ),
      title: Text(widget.isEdit ? 'Edit project' : 'New project'),
    ),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            CoachTarget(
              name: 'project_name',
              child: TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Project name',
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Give the project a name';
                  }
  
                  if (value.trim().length < 3) {
                    return 'Use at least 3 characters';
                  }
  
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            CoachTarget(
              name: 'project_description',
              child: TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Describe what this project covers';
                }

                return null;
              },
            ),
            ),
            const SizedBox(height: 16),
            CoachTarget(
              name: 'project_dates',
              child: Row(
              children: <Widget>[
                Expanded(
                  child: _DateField(
                    label: 'Start date',
                    value: _startDate,
                    onTap: () => _pickDate(isStart: true),
                    onClear: _startDate == null
                        ? null
                        : () => setState(() => _startDate = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'End date',
                    value: _endDate,
                    onTap: () => _pickDate(isStart: false),
                    onClear: _endDate == null
                        ? null
                        : () => setState(() => _endDate = null),
                  ),
                ),
              ],
            ),
            ),
            const SizedBox(height: 16),
            CoachTarget(
              name: 'project_status',
              child: Column(
                children: <Widget>[
            DropdownButtonFormField<String>(
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: ProjectStatus.all
                  .map(
                    (String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(ProjectStatus.label(value)),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
              items: ProjectPriority.all
                  .map(
                    (String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(ProjectPriority.label(value)),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _priority = value);
                }
              },
            ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CoachTarget(
              name: 'project_manager',
              child: _ManagerField(
                users: users,
                value: _managerId,
                onChanged: (int? value) {
                  setState(() => _managerId = value);
                  context.read<CoachProvider>().done('project_manager');
                },
              ),
            ),
            const SizedBox(height: 16),
            CoachTarget(
              name: 'project_team',
              child: _TeamField(
                teams: teams,
                value: _teamId,
                onChanged: (int? value) {
                  setState(() => _teamId = value);
                  context.read<CoachProvider>().done('project_team');
                },
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Archived'),
              subtitle: Text(
                'Hidden from the default project list',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              value: _isArchived,
              onChanged: (bool value) => setState(() => _isArchived = value),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: CoachTarget(
            name: 'project_save',
            child: FilledButton.icon(
            onPressed: projects.isSaving ? null : _save,
            icon: projects.isSaving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(
              widget.isEdit ? 'Save changes' : 'Create project',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: onClear == null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear,
                ),
        ),
        child: Text(
          formatDate(value, fallback: 'Not set'),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ManagerField extends StatelessWidget {
  const _ManagerField({
    required this.users,
    required this.value,
    required this.onChanged,
  });

  final UserProvider users;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (users.isLoading && users.allUsers.isEmpty) {
      return const _LoadingField(label: 'Project manager');
    }

    // Only people who can actually own a project - an Employee or Team
    // Lead picked here would have no manager-level access to it.
    final List<UserModel> list = users.allUsers
        .where((UserModel u) =>
            u.role == UserRoles.projectManager || u.isAdmin)
        .toList();
    final bool valueExists = list.any((UserModel u) => u.id == value);

    return DropdownButtonFormField<int>(
      initialValue: valueExists ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Project manager',
        border: const OutlineInputBorder(),
        helperText: value != null && !valueExists
            ? 'Current manager (#$value) is not a Project manager or Admin'
            : null,
      ),
      items: list
          .map(
            (UserModel user) => DropdownMenuItem<int>(
              value: user.id,
              child: Text(
                '${user.fullName} - ${UserRoles.label(user.role)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (int? selected) =>
          selected == null ? 'Select a manager' : null,
    );
  }
}

class _TeamField extends StatelessWidget {
  const _TeamField({
    required this.teams,
    required this.value,
    required this.onChanged,
  });

  final TeamProvider teams;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (teams.isLoading && teams.allTeams.isEmpty) {
      return const _LoadingField(label: 'Team');
    }

    // An inactive or empty team should not be handed a new project - it
    // was deactivated, or has nobody in it to do the work. The one
    // exception is the team this project is already on; it still has to
    // show so editing the rest of the form does not silently clear it.
    final List<TeamModel> list = teams.allTeams
        .where((TeamModel t) =>
            (t.isActive && t.members.isNotEmpty) || t.id == value)
        .toList();
    final bool valueExists = list.any((TeamModel t) => t.id == value);
    final TeamModel? selected = teams.byId(value);

    return DropdownButtonFormField<int>(
      initialValue: valueExists ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Team',
        border: const OutlineInputBorder(),
        helperText: value != null && !valueExists
            ? 'Current team (#$value) is not in the loaded list'
            : (selected != null && !selected.isActive)
                ? 'This team is inactive. Pick an active team to change it.'
                : null,
      ),
      items: list
          .map(
            (TeamModel team) => DropdownMenuItem<int>(
              value: team.id,
              child: Text(
                '${team.name} (${team.members.length})'
                '${team.isActive ? '' : ' - inactive'}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (int? selected) => selected == null ? 'Select a team' : null,
    );
  }
}

class _LoadingField extends StatelessWidget {
  const _LoadingField({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: Row(
        children: const <Widget>[
          SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('Loading'),
        ],
      ),
    );
  }
}
