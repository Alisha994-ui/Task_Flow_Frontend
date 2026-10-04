import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/project_constants.dart';
import '../../models/team_member_model.dart';
import '../../models/team_model.dart';
import '../../models/user_model.dart';
import '../../providers/team_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/admin/admin_widgets.dart';

/// Create a team when [team] is null, otherwise edit it.
///
/// Members are a separate table on the backend and the serializer keeps
/// them read-only, so a new team is saved first and people are added
/// afterwards. On an existing team both happen on this screen.
class TeamFormScreen extends StatefulWidget {
  const TeamFormScreen({super.key, this.team});

  final TeamModel? team;

  bool get isEdit => team != null;

  @override
  State<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends State<TeamFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  int? _teamLead;
  bool _isActive = true;

  /// Set once a new team has been saved, so the member section can
  /// appear without leaving the screen.
  int? _savedTeamId;

  @override
  void initState() {
    super.initState();

    final TeamModel? team = widget.team;

    _nameController = TextEditingController(text: team?.name ?? '');
    _descriptionController =
        TextEditingController(text: team?.description ?? '');

    if (team != null) {
      _teamLead = team.teamLead;
      _isActive = team.isActive;
      _savedTeamId = team.id;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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

  Future<void> _save({bool closeAfter = true}) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final TeamProvider teams = context.read<TeamProvider>();
    TeamModel? result;

    if (_savedTeamId != null) {
      result = await teams.updateTeam(
        id: _savedTeamId!,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        teamLead: _teamLead,
        clearLead: _teamLead == null,
        isActive: _isActive,
      );
    } else {
      result = await teams.createTeam(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        teamLead: _teamLead,
        isActive: _isActive,
      );
    }

    if (!mounted) {
      return;
    }

    if (result == null) {
      _snack(teams.error ?? 'Could not save the team', isError: true);

      return;
    }

    if (closeAfter) {
      Navigator.of(context).pop(true);

      return;
    }

    // Stay put so members can be added to the team just created.
    setState(() => _savedTeamId = result!.id);
    _snack('Team saved. Add its members below.');
  }

  Future<void> _addMember() async {
    final int? teamId = _savedTeamId;

    if (teamId == null) {
      return;
    }

    final TeamProvider teams = context.read<TeamProvider>();
    final UserProvider users = context.read<UserProvider>();

    final Set<int> already = teams
        .membersOf(teamId)
        .map((TeamMemberModel m) => m.user)
        .toSet();

    final int? picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final List<UserModel> candidates = users.allUsers
            .where((UserModel u) => !already.contains(u.id))
            .toList();

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.65,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Add to the team',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                Expanded(
                  child: candidates.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Everyone is already on this team.',
                              textAlign: TextAlign.center,
                              style:
                                  Theme.of(sheetContext).textTheme.bodySmall,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: candidates.length,
                          itemBuilder: (BuildContext context, int index) {
                            final UserModel user = candidates[index];

                            return ListTile(
                              leading: UserAvatar(
                                name: user.fullName,
                                imageUrl: user.profileImage,
                                radius: 18,
                                color: UserRoles.color(user.role),
                              ),
                              title: Text(user.fullName),
                              subtitle: Text(UserRoles.label(user.role)),
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(user.id),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    final bool ok = await teams.addMember(teamId: teamId, userId: picked);

    if (!mounted) {
      return;
    }

    _snack(
      ok ? 'Added to the team' : (teams.error ?? 'Could not add them'),
      isError: !ok,
    );
  }

  Future<void> _removeMember(TeamMemberModel row) async {
    final TeamProvider teams = context.read<TeamProvider>();
    final bool ok = await teams.removeMember(
      teamId: row.team,
      memberRowId: row.id,
    );

    if (!mounted) {
      return;
    }

    _snack(
      ok ? 'Removed from the team' : (teams.error ?? 'Could not remove them'),
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TeamProvider teams = context.watch<TeamProvider>();
    final UserProvider users = context.watch<UserProvider>();

    final int? teamId = _savedTeamId;
    final List<TeamMemberModel> members =
        teamId == null ? <TeamMemberModel>[] : teams.membersOf(teamId);

    final bool leadExists =
        users.allUsers.any((UserModel u) => u.id == _teamLead);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit team' : 'New team'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Team name',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Give the team a name';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
                helperText: 'Optional',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: leadExists ? _teamLead : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Team lead',
                border: OutlineInputBorder(),
                helperText: 'They get the team lead panel for this team',
              ),
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('No lead yet'),
                ),
                ...users.allUsers.map(
                  (UserModel user) => DropdownMenuItem<int?>(
                    value: user.id,
                    child: Text(
                      '${user.fullName} - ${UserRoles.label(user.role)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (int? value) => setState(() => _teamLead = value),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: Text(
                _isActive
                    ? 'Can be picked when creating a project'
                    : 'Hidden from new projects',
                style: theme.textTheme.bodySmall,
              ),
              value: _isActive,
              onChanged: (bool value) => setState(() => _isActive = value),
            ),

            const SizedBox(height: 22),

            // ------------------------------------------------- members
            if (teamId == null)
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.group_add_outlined,
                    color: theme.colorScheme.outline,
                  ),
                  title: const Text('Members come after saving'),
                  subtitle: Text(
                    'The API creates the team first, then its people. '
                    'Save and they can be added right here.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              )
            else ...<Widget>[
              SectionHeader(
                title: 'Members',
                subtitle: members.isEmpty
                    ? 'Nobody on this team yet'
                    : '${members.length} on the team',
                trailing: FilledButton.tonalIcon(
                  onPressed: teams.isSaving ? null : _addMember,
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Add'),
                ),
              ),
              const SizedBox(height: 8),
              if (members.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'Add people here and they get access to every project '
                      'this team owns - its tasks and its discussion.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: members.map((TeamMemberModel row) {
                      final UserModel? user = users.byId(row.user);
                      final String name = row.userName.isNotEmpty
                          ? row.userName
                          : users.nameFor(row.user);
                      final bool isLead = _teamLead == row.user;
                      final bool isLast = row == members.last;

                      return Column(
                        children: <Widget>[
                          ListTile(
                            leading: UserAvatar(
                              name: name,
                              imageUrl: user?.profileImage,
                              color: user == null
                                  ? null
                                  : UserRoles.color(user.role),
                            ),
                            title: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              user == null
                                  ? 'Member'
                                  : UserRoles.label(user.role),
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (isLead)
                                  const LabelChip(
                                    text: 'Lead',
                                    color: Color(0xFF0D9488),
                                    icon: Icons.star_outline,
                                  ),
                                IconButton(
                                  tooltip: 'Remove from team',
                                  onPressed: teams.isSaving
                                      ? null
                                      : () => _removeMember(row),
                                  icon: Icon(
                                    Icons.person_remove_outlined,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isLast) const Divider(height: 1, indent: 68),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: <Widget>[
              if (_savedTeamId == null)
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        teams.isSaving ? null : () => _save(closeAfter: false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Save and add members'),
                  ),
                ),
              if (_savedTeamId == null) const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: teams.isSaving ? null : () => _save(),
                  icon: teams.isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_savedTeamId == null ? 'Create' : 'Save'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
