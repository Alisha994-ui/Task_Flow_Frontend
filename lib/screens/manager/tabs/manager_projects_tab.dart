import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/project_constants.dart';
import '../../../models/project_model.dart';
import '../../../models/team_model.dart';
import '../../../providers/manager_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/team_provider.dart';
import '../../../widgets/admin/async_view.dart';
import '../../../widgets/manager/manager_project_card.dart';
import '../manager_project_detail_screen.dart';

class ManagerProjectsTab extends StatefulWidget {
  const ManagerProjectsTab({super.key});

  @override
  State<ManagerProjectsTab> createState() => _ManagerProjectsTabState();
}

class _ManagerProjectsTabState extends State<ManagerProjectsTab> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController(
      text: context.read<ManagerProvider>().search,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ProjectProvider projects = context.watch<ProjectProvider>();
    final ManagerProvider manager = context.watch<ManagerProvider>();
    final TeamProvider teams = context.watch<TeamProvider>();

    final Set<int> ledTeamIds = teams.allTeams
        .where((TeamModel t) => t.teamLead == manager.managerId)
        .map((TeamModel t) => t.id)
        .toSet();

    final List<ProjectModel> visible =
        manager.visibleProjects(projects.allProjects, ledTeamIds: ledTeamIds);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: <Widget>[
              TextField(
                controller: _searchController,
                onChanged: manager.setSearch,
                decoration: InputDecoration(
                  hintText: 'Search your projects',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: manager.search.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            manager.setSearch('');
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
                      label: const Text('All'),
                      selected: manager.statusFilter == kFilterAll,
                      onSelected: (_) => manager.setStatusFilter(kFilterAll),
                    ),
                    ...ProjectStatus.all.map(
                      (String status) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(ProjectStatus.label(status)),
                          selected: manager.statusFilter == status,
                          onSelected: (_) => manager.setStatusFilter(status),
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
            isLoading: projects.isLoading && projects.allProjects.isEmpty,
            error: projects.allProjects.isEmpty ? projects.error : null,
            isEmpty: visible.isEmpty,
            onRetry: projects.refresh,
            emptyIcon: Icons.folder_off_outlined,
            emptyTitle: manager.hasFilters
                ? 'No projects match these filters'
                : 'No projects assigned to you',
            emptyMessage: manager.hasFilters
                ? 'Clear the filters to see everything again.'
                : 'Projects show up here once an admin assigns you as manager.',
            emptyAction: manager.hasFilters
                ? TextButton(
                    onPressed: () {
                      _searchController.clear();
                      manager.clearFilters();
                    },
                    child: const Text('Clear filters'),
                  )
                : null,
            child: RefreshIndicator(
              onRefresh: projects.refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) {
                  final ProjectModel project = visible[index];

                  return ManagerProjectCard(
                    project: project,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => ManagerProjectDetailScreen(
                          projectId: project.id,
                        ),
                      ),
                    ),
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
