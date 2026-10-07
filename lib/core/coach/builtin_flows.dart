import '../../providers/coach_provider.dart';

/// Walkthroughs the app knows by heart.
///
/// The assistant can build these too, but it costs a request and the
/// free tier allows few of them a day - so the handful of things people
/// ask about constantly are written out here. They start instantly,
/// work with no network, and never drift from the screens because they
/// live beside them.
///
/// Anything not in this list still goes to the assistant.
class BuiltinFlow {
  const BuiltinFlow({
    required this.title,
    required this.destination,
    required this.keywords,
    required this.roles,
    required this.steps,
  });

  final String title;

  /// Which tab to open first - the same names the assistant uses.
  final String destination;

  /// Lower-case words that, taken together, mean this flow. A question
  /// matches when it contains the subject and something asking how.
  final List<String> keywords;

  final List<String> roles;

  final List<CoachStep> steps;
}

const List<BuiltinFlow> _flows = <BuiltinFlow>[
  // ------------------------------------------------------------- admin
  BuiltinFlow(
    title: 'New team',
    destination: 'teams',
    keywords: <String>['team'],
    roles: <String>['ADMIN'],
    steps: <CoachStep>[
      CoachStep('Tap the + button to start a new team.',
          target: 'teams_fab'),
      CoachStep('Type the team name here.', target: 'team_name'),
      CoachStep(
        'Pick the Team lead. They get the team lead panel for this team.',
        target: 'team_lead',
      ),
      CoachStep(
        'Press this. The team has to exist before people can be added '
        'to it.',
        target: 'team_save_and_members',
      ),
      CoachStep(
        'Now press Add, pick a person, and repeat for everyone. They get '
        'every project this team owns.',
      ),
      CoachStep('Press Save when the team is complete.',
          target: 'team_save'),
    ],
  ),
  BuiltinFlow(
    title: 'New project',
    destination: 'projects',
    keywords: <String>['project'],
    roles: <String>['ADMIN'],
    steps: <CoachStep>[
      CoachStep('Tap the + button to start a new project.',
          target: 'projects_fab'),
      CoachStep('Type the project name here.', target: 'project_name'),
      CoachStep(
        'Pick the Manager and the Team. The team\u2019s members get this '
        'project, its tasks and its discussion automatically.',
      ),
      CoachStep('Set the dates, priority and status, then press Create.'),
    ],
  ),
  BuiltinFlow(
    title: 'New user',
    destination: 'users',
    keywords: <String>['user', 'account', 'employee', 'login'],
    roles: <String>['ADMIN'],
    steps: <CoachStep>[
      CoachStep('Tap the + button to add someone.', target: 'users_fab'),
      CoachStep('Type the username they will sign in with.',
          target: 'user_username'),
      CoachStep('Type their email address.', target: 'user_email'),
      CoachStep('Set a password. You will need to tell them what it is.',
          target: 'user_password'),
      CoachStep('Pick their Role - it decides what they can see.',
          target: 'user_role'),
      CoachStep('Leave Active on and press Create.'),
    ],
  ),
  BuiltinFlow(
    title: 'Deactivate someone',
    destination: 'users',
    keywords: <String>['deactivate', 'disable', 'remove user', 'band'],
    roles: <String>['ADMIN'],
    steps: <CoachStep>[
      CoachStep('Find the person in this list.'),
      CoachStep('Tap the three dots on their row.'),
      CoachStep(
        'Choose Deactivate. They stay in the history but cannot sign in. '
        'Prefer this to Delete.',
      ),
    ],
  ),
  BuiltinFlow(
    title: 'People on a project',
    destination: 'projects',
    keywords: <String>['member', 'add people', 'add someone to'],
    roles: <String>['ADMIN'],
    steps: <CoachStep>[
      CoachStep('Tap the project you want.'),
      CoachStep('Open the Members tab.'),
      CoachStep(
        'The team\u2019s people are listed first - they come from the team '
        'itself. Press Add for anyone outside it.',
      ),
      CoachStep('Pick the person. They get the project straight away.'),
    ],
  ),

  // ---------------------------------------------- admin, manager, lead
  BuiltinFlow(
    title: 'New task',
    destination: 'tasks',
    keywords: <String>['task', 'assign'],
    roles: <String>['ADMIN', 'PROJECT_MANAGER', 'TEAM_LEAD'],
    steps: <CoachStep>[
      CoachStep('Tap the + button to start a new task.',
          target: 'tasks_fab'),
      CoachStep('Pick the project it belongs to.', target: 'task_project'),
      CoachStep('Type the task title here.', target: 'task_title'),
      CoachStep(
        'Pick who does it. They get a notification on their phone.',
        target: 'task_assignee',
      ),
      CoachStep('Set the due date and priority, then press Create.'),
    ],
  ),
  BuiltinFlow(
    title: 'Move a task',
    destination: 'tasks',
    keywords: <String>['status', 'board', 'progress', 'move', 'drag'],
    roles: <String>['ADMIN', 'PROJECT_MANAGER', 'TEAM_LEAD'],
    steps: <CoachStep>[
      CoachStep(
        'Tap the board icon at the top right to switch from list to '
        'columns.',
      ),
      CoachStep(
        'Long press a card and drag it to another column. A plain drag '
        'scrolls the board instead.',
      ),
      CoachStep(
        'Or tap the status icon at the bottom of a card and pick a '
        'status - it lands in that column by itself.',
      ),
    ],
  ),
  BuiltinFlow(
    title: 'Project discussion',
    destination: 'projects',
    keywords: <String>['discussion', 'chat', 'message the team', 'baat'],
    roles: <String>['ADMIN', 'PROJECT_MANAGER', 'TEAM_LEAD'],
    steps: <CoachStep>[
      CoachStep('Tap the project you want to talk about.'),
      CoachStep('Open the Discussion tab.'),
      CoachStep(
        'Type a message, or use the paperclip to send a file. Everyone '
        'on the project gets a notification.',
      ),
      CoachStep(
        'For something about one task only, use that task\u2019s Comments '
        'tab instead.',
      ),
    ],
  ),
  BuiltinFlow(
    title: 'Reopen a task',
    destination: 'tasks',
    keywords: <String>['reopen', 'undo complete', 'wapas', 'khol'],
    roles: <String>['ADMIN', 'PROJECT_MANAGER', 'TEAM_LEAD'],
    steps: <CoachStep>[
      CoachStep('Find the completed task in this list.'),
      CoachStep('Tap its status icon.'),
      CoachStep(
        'Pick To do or In progress. Employees cannot do this themselves - '
        'that is why they ask you.',
      ),
    ],
  ),

  // ----------------------------------------------------------- manager
  BuiltinFlow(
    title: 'Reports',
    destination: 'more',
    keywords: <String>['report', 'stats', 'numbers'],
    roles: <String>['PROJECT_MANAGER', 'TEAM_LEAD'],
    steps: <CoachStep>[
      CoachStep('Tap Reports.'),
      CoachStep(
        'Workload, status and overdue counts across everything you can '
        'see. Pull down to refresh.',
      ),
    ],
  ),

  // --------------------------------------------------------- team lead
  BuiltinFlow(
    title: 'Your team',
    destination: 'team',
    keywords: <String>['team', 'workload', 'who is busy', 'kaam'],
    roles: <String>['TEAM_LEAD'],
    steps: <CoachStep>[
      CoachStep('These are your members.'),
      CoachStep(
        'Tap one for their open tasks, their tracked time and how much '
        'they are carrying.',
      ),
      CoachStep(
        'The Dashboard tab shows who has a timer running right now.',
      ),
    ],
  ),

  // ---------------------------------------------------------- employee
  BuiltinFlow(
    title: 'Track time',
    destination: 'tasks',
    keywords: <String>['timer', 'time', 'waqt', 'track'],
    roles: <String>['EMPLOYEE'],
    steps: <CoachStep>[
      CoachStep('Find the task you are working on.'),
      CoachStep(
        'Press Start timer on it. The Today tab has the same button.',
      ),
      CoachStep(
        'Press it again to stop. Your total is on More, under Time logs.',
      ),
    ],
  ),
  BuiltinFlow(
    title: 'Change a status',
    destination: 'tasks',
    keywords: <String>['status', 'complete', 'done', 'mukammal', 'board'],
    roles: <String>['EMPLOYEE'],
    steps: <CoachStep>[
      CoachStep('Find your task here.'),
      CoachStep('Tap the status icon on it and pick one.'),
      CoachStep(
        'Or use the board icon at the top right and drag the card between '
        'columns - long press first.',
      ),
      CoachStep(
        'Once you mark it Completed it is final for you. Your team lead '
        'or manager can reopen it.',
      ),
    ],
  ),
  BuiltinFlow(
    title: 'Attach a file',
    destination: 'tasks',
    keywords: <String>['file', 'attach', 'upload', 'photo', 'screenshot'],
    roles: <String>['EMPLOYEE', 'ADMIN', 'PROJECT_MANAGER', 'TEAM_LEAD'],
    steps: <CoachStep>[
      CoachStep('Tap the task.'),
      CoachStep('On the Overview tab, find the Files section.'),
      CoachStep('Use the paperclip to pick a file from your phone.'),
      CoachStep(
        'Or send it with a comment: Comments tab, paperclip, then send.',
      ),
    ],
  ),
  BuiltinFlow(
    title: 'Who to ask',
    destination: 'more',
    keywords: <String>['who', 'contact', 'lead', 'manager', 'help', 'poochh'],
    roles: <String>['EMPLOYEE', 'PROJECT_MANAGER', 'TEAM_LEAD'],
    steps: <CoachStep>[
      CoachStep('Scroll down to "Who to ask".'),
      CoachStep(
        'Your team lead, your manager and the administrators are listed.',
      ),
      CoachStep(
        'Tap anyone to email them - your mail app opens with their '
        'address filled in.',
      ),
    ],
  ),
  BuiltinFlow(
    title: 'Your projects',
    destination: 'more',
    keywords: <String>['project', 'discussion', 'chat'],
    roles: <String>['EMPLOYEE'],
    steps: <CoachStep>[
      CoachStep('Tap "My projects".'),
      CoachStep('Tap a project to open its discussion.'),
      CoachStep(
        'Type a message or use the paperclip. Everyone on the project '
        'sees it.',
      ),
    ],
  ),
];

/// Words that turn a sentence into a request for instructions.
///
/// Deliberately not a bare "how": "How many tasks do I have?" contains
/// "how" too, but it is a counting question, not a request to be
/// walked through a screen. Only the "how do/can/to ..." shapes that
/// actually ask for a method count here.
const List<String> _asking = <String>[
  'how do i',
  'how do you',
  'how can i',
  'how to',
  'add',
  'create',
  'make',
  'new',
  'kaise',
  'kese',
  'kesy',
  'kaisy',
  'banau',
  'banaun',
  'banana',
  'krna',
  'karna',
  'kron',
  'karun',
  'kahan',
  'kahaan',
  'kahn',
  'guide',
  'show me',
  'walk',
];

/// Phrases that mean the person wants data back, not a walkthrough -
/// checked first and always win, even if a flow's keyword also shows
/// up in the same sentence (e.g. "status" in "what is each status").
const List<String> _dataQuestionHints = <String>[
  'how many',
  'how much',
  'what is each',
  'what are my',
  'what is my',
  'which of my',
  'count',
  'am i late',
  'am i behind',
  'who is my',
];

/// The flow this question is asking for, if the app already knows it.
///
/// Deliberately strict: the subject has to be named and the sentence
/// has to read like a request for instructions. "Which teams are
/// behind?" is a question about data and belongs to the assistant.
BuiltinFlow? matchBuiltinFlow(String question, String role) {
  final String text = question.toLowerCase();

  if (_dataQuestionHints.any((String hint) => text.contains(hint))) {
    return null;
  }

  final bool asking = _asking.any((String word) => text.contains(word));

  if (!asking) {
    return null;
  }

  for (final BuiltinFlow flow in _flows) {
    if (!flow.roles.contains(role)) {
      continue;
    }

    if (flow.keywords.any((String word) => text.contains(word))) {
      return flow;
    }
  }

  return null;
}

/// Everything this role can be walked through, for the suggestions on
/// an empty assistant panel.
List<BuiltinFlow> builtinFlowsFor(String role) {
  return _flows.where((BuiltinFlow f) => f.roles.contains(role)).toList();
}
