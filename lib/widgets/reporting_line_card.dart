import 'package:flutter/material.dart';

import '../core/constants/project_constants.dart';
import '../core/utils/contact.dart';
import '../core/utils/reporting_line.dart';
import '../models/user_model.dart';
import 'admin/admin_widgets.dart';

/// "Who to ask" - the person's lead, manager and admins, each one tap
/// away from an email.
class ReportingLineCard extends StatelessWidget {
  const ReportingLineCard({
    super.key,
    required this.line,
    this.subjectPrefix = 'TaskFlow',
  });

  final ReportingLine line;
  final String subjectPrefix;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (line.isEmpty) {
      return Card(
        child: ListTile(
          leading: Icon(
            Icons.help_outline,
            color: theme.colorScheme.outline,
          ),
          title: const Text('No reporting line yet'),
          subtitle: Text(
            'Once you are added to a team, your lead and manager appear '
            'here.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    final List<Widget> rows = <Widget>[];

    void addGroup(String label, List<UserModel> people) {
      for (final UserModel person in people) {
        rows.add(
          _ContactRow(
            label: label,
            person: person,
            subjectPrefix: subjectPrefix,
          ),
        );
      }
    }

    addGroup(line.leads.length > 1 ? 'Team lead' : 'Your team lead', line.leads);
    addGroup(
      line.managers.length > 1 ? 'Project manager' : 'Your manager',
      line.managers,
    );
    addGroup('Administrator', line.admins.take(2).toList());

    return Card(
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            rows[i],
            if (i != rows.length - 1) const Divider(height: 1, indent: 68),
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.label,
    required this.person,
    required this.subjectPrefix,
  });

  final String label;
  final UserModel person;
  final String subjectPrefix;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasEmail = person.email.isNotEmpty;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: UserAvatar(
        name: person.fullName,
        imageUrl: person.profileImage,
        color: UserRoles.color(person.role),
      ),
      title: Text(
        person.fullName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        hasEmail ? '$label · ${person.email}' : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: hasEmail
          ? IconButton(
              tooltip: 'Email ${person.fullName}',
              icon: Icon(
                Icons.mail_outline,
                color: theme.colorScheme.primary,
              ),
              onPressed: () => openMail(
                context,
                person.email,
                subject: subjectPrefix,
              ),
            )
          : null,
      onTap: hasEmail
          ? () => openMail(context, person.email, subject: subjectPrefix)
          : null,
    );
  }
}
