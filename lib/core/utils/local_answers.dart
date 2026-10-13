import '../../models/user_model.dart';
import 'reporting_line.dart';

/// "Who is my manager / team lead?" is answered from data the app already
/// holds, so the reply names the person (with email) instantly and works
/// without the model - no waiting, no vague "see the More tab".
///
/// Returns null when [question] is not that kind of question, or when the
/// app has no reporting data yet (the server assistant then handles it).
final RegExp _whoIsMyBoss = RegExp(
  r"\bwho(?:'s|s| is| are)?\s+(?:my|the)\s+"
  r'(?:project\s+)?(?:manager|managers|lead|leads|team\s*lead|boss|supervisor)\b',
);

/// True when [question] is a "who is my manager / lead" question - the
/// only kind [localReportingAnswer] can answer. Lets the panel skip
/// loading users/teams/projects for every other question.
bool isReportingQuestion(String question) =>
    _whoIsMyBoss.hasMatch(question.toLowerCase());

String _person(UserModel user) {
  return user.email.trim().isEmpty
      ? user.fullName
      : '${user.fullName} (${user.email})';
}

String _names(List<UserModel> people) =>
    people.map(_person).join(', ');

String? localReportingAnswer(String question, ReportingLine line) {
  if (!_whoIsMyBoss.hasMatch(question.toLowerCase())) {
    return null;
  }

  if (line.isEmpty) {
    return null;
  }

  final List<String> lines = <String>[];

  if (line.managers.isNotEmpty) {
    lines.add(
      line.managers.length == 1
          ? 'Your project manager is ${_person(line.managers.first)}.'
          : 'Your project managers are ${_names(line.managers)}.',
    );
  }

  if (line.leads.isNotEmpty) {
    lines.add(
      line.leads.length == 1
          ? 'Your team lead is ${_person(line.leads.first)}.'
          : 'Your team leads are ${_names(line.leads)}.',
    );
  }

  if (lines.isEmpty && line.admins.isNotEmpty) {
    lines.add(
      "I couldn't find a team lead or project manager linked to you yet. "
      'The admin is ${_names(line.admins)}.',
    );
  }

  if (lines.isEmpty) {
    return null;
  }

  // The shortcut button to the "Who to ask" card is a bonus under the
  // answer; the answer itself is already in the text.
  return '${lines.join('\n')}\n[GOTO:more]';
}
