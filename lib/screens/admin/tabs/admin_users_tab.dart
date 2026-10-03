import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/project_constants.dart';
import '../../../core/utils/contact.dart';
import '../../../models/user_model.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/admin/admin_widgets.dart';
import '../../../widgets/admin/async_view.dart';
import '../user_form_screen.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController(
      text: context.read<UserProvider>().search,
    );

    // Load on our own so this tab works inside any shell, not just
    // AdminPanelScreen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<UserProvider>().ensureLoaded();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UserProvider provider = context.watch<UserProvider>();
    final List<UserModel> users = provider.users;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: <Widget>[
              TextField(
                controller: _searchController,
                onChanged: provider.setSearch,
                decoration: InputDecoration(
                  hintText: 'Search by name, username or email',
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
                            _searchController.clear();
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
                    ChoiceChip(
                      label: const Text('Everyone'),
                      selected: provider.roleFilter == kFilterAll,
                      onSelected: (_) => provider.setRoleFilter(kFilterAll),
                    ),
                    ...UserRoles.all.map(
                      (String role) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(UserRoles.label(role)),
                          selected: provider.roleFilter == role,
                          onSelected: (_) => provider.setRoleFilter(role),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView(
            isLoading: provider.isLoading && provider.allUsers.isEmpty,
            error: provider.allUsers.isEmpty ? provider.error : null,
            isEmpty: users.isEmpty,
            onRetry: provider.refresh,
            emptyIcon: Icons.person_search_outlined,
            emptyTitle: 'No users match this search',
            emptyMessage: 'Try a different name or clear the role filter.',
            child: RefreshIndicator(
              onRefresh: provider.refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                itemCount: users.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int index) {
                  return _UserTile(user: users[index]);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final UserModel user;

  void _snack(BuildContext context, String message, {bool isError = false}) {
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

  Future<void> _edit(BuildContext context) async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UserFormScreen(user: user),
      ),
    );

    if (saved == true && context.mounted) {
      _snack(context, 'Account updated');
    }
  }

  Future<void> _toggleActive(BuildContext context) async {
    final UserProvider users = context.read<UserProvider>();
    final bool ok = await users.setActive(user.id, !user.status);

    if (!context.mounted) {
      return;
    }

    _snack(
      context,
      ok
          ? (user.status ? 'Account deactivated' : 'Account activated')
          : (users.error ?? 'Could not update the account'),
      isError: !ok,
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final UserProvider users = context.read<UserProvider>();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete this account?'),
          content: Text(
            '${user.fullName} will be removed, and so will the tasks, '
            'comments and time logs attached to them. Deactivating is '
            'usually the safer choice.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
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

    if (confirmed != true || !context.mounted) {
      return;
    }

    final bool ok = await users.deleteUser(user.id);

    if (!context.mounted) {
      return;
    }

    _snack(
      context,
      ok ? 'Account deleted' : (users.error ?? 'Could not delete the account'),
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: UserAvatar(
          name: user.fullName,
          imageUrl: user.profileImage,
          color: UserRoles.color(user.role),
        ),
        title: Text(
          user.fullName,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              user.email.isEmpty ? '@${user.username}' : user.email,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: <Widget>[
                LabelChip(
                  text: UserRoles.label(user.role),
                  color: UserRoles.color(user.role),
                ),
                LabelChip(
                  text: user.status ? 'Active' : 'Inactive',
                  color: user.status
                      ? const Color(0xFF059669)
                      : const Color(0xFF9CA3AF),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Account actions',
          onSelected: (String action) {
            switch (action) {
              case 'edit':
                _edit(context);
                break;
              case 'active':
                _toggleActive(context);
                break;
              case 'delete':
                _confirmDelete(context);
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
              value: 'active',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  user.status
                      ? Icons.person_off_outlined
                      : Icons.person_outline,
                ),
                title: Text(user.status ? 'Deactivate' : 'Activate'),
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
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
          ],
        ),
        onTap: () => _showUserSheet(context, user),
      ),
    );
  }

  void _showUserSheet(BuildContext context, UserModel user) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    UserAvatar(
                      name: user.fullName,
                      imageUrl: user.profileImage,
                      radius: 26,
                      color: UserRoles.color(user.role),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            user.fullName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '@${user.username}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _DetailRow(
                  icon: Icons.badge_outlined,
                  label: 'Role',
                  value: UserRoles.label(user.role),
                ),
                _DetailRow(
                  icon: Icons.mail_outline,
                  label: 'Email',
                  value: user.email.isEmpty ? 'Not provided' : user.email,
                  onTap: user.email.isEmpty
                      ? null
                      : () => openMail(sheetContext, user.email),
                ),
                _DetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: (user.phone == null || user.phone!.isEmpty)
                      ? 'Not provided'
                      : user.phone!,
                  onTap: (user.phone == null || user.phone!.isEmpty)
                      ? null
                      : () => openDialer(sheetContext, user.phone!),
                ),
                _DetailRow(
                  icon: Icons.toggle_on_outlined,
                  label: 'Account',
                  value: user.status ? 'Active' : 'Inactive',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: onTap == null
                  ? theme.colorScheme.outline
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 86,
              child: Text(label, style: theme.textTheme.bodySmall),
            ),
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onTap == null ? null : theme.colorScheme.primary,
                  fontWeight: onTap == null ? null : FontWeight.w600,
                ),
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.north_east,
                size: 14,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
