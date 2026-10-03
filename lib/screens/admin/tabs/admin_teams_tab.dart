import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/team_model.dart';
import '../../../providers/team_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/admin/admin_widgets.dart';
import '../../../widgets/admin/async_view.dart';

class AdminTeamsTab extends StatefulWidget {
  const AdminTeamsTab({super.key});

  @override
  State<AdminTeamsTab> createState() => _AdminTeamsTabState();
}

class _AdminTeamsTabState extends State<AdminTeamsTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController(
      text: context.read<TeamProvider>().search,
    );

    // Load on our own so this tab works inside any shell. Users are needed
    // too, to turn member ids into names.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<TeamProvider>().ensureLoaded();
      context.read<UserProvider>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TeamProvider provider = context.watch<TeamProvider>();
    final List<TeamModel> teams = provider.teams;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: provider.setSearch,
            decoration: InputDecoration(
              hintText: 'Search teams',
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
        ),
        Expanded(
          child: AsyncView(
            isLoading: provider.isLoading && provider.allTeams.isEmpty,
            error: provider.allTeams.isEmpty ? provider.error : null,
            isEmpty: teams.isEmpty,
            onRetry: provider.refresh,
            emptyIcon: Icons.groups_outlined,
            emptyTitle: 'No teams found',
            emptyMessage:
                'Teams are created from the backend admin. Pull down to refresh.',
            child: RefreshIndicator(
              onRefresh: provider.refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                itemCount: teams.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int index) {
                  return _TeamCard(team: teams[index]);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team});

  final TeamModel team;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final UserProvider users = context.watch<UserProvider>();

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(
            Icons.groups,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          team.name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              LabelChip(
                text: '${team.members.length} '
                    '${team.members.length == 1 ? 'member' : 'members'}',
                color: const Color(0xFF2563EB),
                icon: Icons.person_outline,
              ),
              LabelChip(
                text: team.isActive ? 'Active' : 'Inactive',
                color: team.isActive
                    ? const Color(0xFF059669)
                    : const Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (team.description.trim().isNotEmpty) ...<Widget>[
            Text(
              team.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: <Widget>[
              Icon(
                Icons.star_outline,
                size: 16,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Text(
                'Lead: ${users.nameFor(team.teamLead, fallback: 'Not assigned')}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (team.members.isEmpty)
            Text(
              'No members in this team yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: team.members.map((int memberId) {
                return Chip(
                  avatar: UserAvatar(
                    name: users.nameFor(memberId, fallback: 'U'),
                    imageUrl: users.byId(memberId)?.profileImage,
                    radius: 10,
                  ),
                  label: Text(users.nameFor(memberId)),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
