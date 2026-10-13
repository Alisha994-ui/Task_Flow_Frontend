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
    this.needs = const <String>[],
  });

  /// When not empty, one of these must also be in the question. The
  /// "new X" tours use it: "how do I move a task" names a task too, and
  /// used to start the New task tour instead of Move a task.
  final List<String> needs;

  final String title;

  /// Which tab to open first - the same names the assistant uses.
  final String destination;

  /// Lower-case words that, taken together, mean this flow. A question
  /// matches when it contains the subject and something asking how.
  final List<String> keywords;

  final List<String> roles;

  final List<CoachStep> steps;
}

/// Words that mean "make a new one" - required by the creation tours.
const List<String> _creating = <String>[
  'add',
  'create',
  'make',
  'new',
  'set up',
  'setup',
  'assign',
  'naya',
  'nayi',
  'naye',
  'bana',
  'banau',
  'banaun',
  'banana',
  'banao',
  'dalna',
  'daalna',
];

const List<BuiltinFlow> _flows = <BuiltinFlow>[
  // ------------------------------------------------------------- admin
  BuiltinFlow(
    title: 'New team',
    destination: 'teams',
    keywords: <String>['team'],
    roles: <String>['ADMIN'],
    needs: _creating,
    steps: <CoachStep>[
      CoachStep('Tap New team to start.', target: 'teams_fab'),
      CoachStep(
        'Type the team name. The description below it is optional.',
        target: 'team_name',
      ),
      CoachStep(
        'Pick the Team lead - they get the team lead panel for this team. '
        '"No lead yet" is fine if you have not decided.',
        target: 'team_lead',
      ),
      CoachStep(
        'Press "Save and add members". The team has to exist before '
        'people can be added to it.',
        target: 'team_save_and_members',
      ),
      CoachStep(
        'Press Add, pick a person, and repeat for everyone on the team. '
        'They get every project this team owns. Press Next when done.',
        target: 'team_add_member',
      ),
      CoachStep('Press Save. The team is ready.', target: 'team_save'),
    ],
  ),  BuiltinFlow(
    title: 'New project',
    destination: 'projects',
    keywords: <String>['project'],
    roles: <String>['ADMIN'],
    needs: _creating,
    steps: <CoachStep>[
      CoachStep('Tap New project to start.', target: 'projects_fab'),
      CoachStep(
        'Type the project name - at least 3 characters.',
        target: 'project_name',
      ),
      CoachStep(
        'Describe what the project covers. This one is required.',
        target: 'project_description',
      ),
      CoachStep(
        'Set the start and end dates if you know them. Both are optional.',
        target: 'project_dates',
      ),
      CoachStep(
        'Check the Status and Priority. Change them only if the defaults '
        'do not fit.',
        target: 'project_status',
      ),
      CoachStep(
        'Pick the Project manager - the person who runs it.',
        target: 'project_manager',
      ),
      CoachStep(
        'Pick the Team. Only active teams with people in them are listed; '
        'their members get this project automatically.',
        target: 'project_team',
      ),
      CoachStep('Press Create project.', target: 'project_save'),
    ],
  ),  BuiltinFlow(
    title: 'New user',
    destination: 'users',
    keywords: <String>['user', 'account', 'employee', 'login'],
    roles: <String>['ADMIN'],
    needs: _creating,
    steps: <CoachStep>[
      CoachStep('Tap New user to start.', target: 'users_fab'),
      CoachStep(
        'Type the username they will sign in with. First and last name '
        'below it are optional.',
        target: 'user_username',
      ),
      CoachStep('Type their email address.', target: 'user_email'),
      CoachStep(
        'Pick their Role - it decides what they can see and do.',
        target: 'user_role',
      ),
      CoachStep(
        'Set a password, at least 8 characters. It is e-mailed to them.',
        target: 'user_password',
      ),
      CoachStep(
        'Leave Active on, then press Create user.',
        target: 'user_save',
      ),
    ],
  ),  BuiltinFlow(
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
    needs: _creating,
    steps: <CoachStep>[
      CoachStep('Tap New task to start.', target: 'tasks_fab'),
      CoachStep(
        'Pick the project it belongs to. Do this first - the people you '
        'can assign come from that project.',
        target: 'task_project',
      ),
      CoachStep('Type the task title.', target: 'task_title'),
      CoachStep(
        'Pick who does it. They get a notification on their phone.',
        target: 'task_assignee',
      ),
      CoachStep(
        'Check the Status and Priority. Change them only if the defaults '
        'do not fit.',
        target: 'task_priority',
      ),
      CoachStep(
        'Set the Due date so it shows on the calendar. The start date is '
        'optional.',
        target: 'task_dates',
      ),
      CoachStep('Press Create task.', target: 'task_save'),
    ],
  ),  BuiltinFlow(
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
  "who's my",
  'whos my',
  'what tasks',
  'which tasks',
  'what projects',
  'which projects',
  'list my',
  'tell me',
  'overdue',
  'do i have',
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

/// True when [word] starts a word in [text] - so "add" matches "add a
/// task" and "added", but not "address", and "time" does not fire on
/// "sometimes". (Prefix match on purpose: "task" must still catch
/// "tasks".)
bool _hasWord(String text, String word) {
  return RegExp('(?<![a-z0-9])${RegExp.escape(word)}').hasMatch(text);
}

/// The flow this question is asking for, if the app already knows it.
///
/// Deliberately strict: the subject has to be named and the sentence
/// has to read like a request for instructions. "Which teams are
/// behind?" is a question about data and belongs to the assistant.
BuiltinFlow? matchBuiltinFlow(String question, String role) {
  final String text = question.toLowerCase();

  if (_dataQuestionHints.any((String hint) => _hasWord(text, hint))) {
    return null;
  }

  final bool asking = _asking.any((String word) => _hasWord(text, word));

  if (!asking) {
    return null;
  }

  // A task lives inside a project and is usually for a team, so "add a
  // task to the project" and "team ke liye task banana" name all three.
  // The task is what they are making - check it first. Otherwise the
  // list order decides.
  final List<BuiltinFlow> ordered = <BuiltinFlow>[
    ..._flows.where((BuiltinFlow f) => f.title == 'New task'),
    ..._flows.where((BuiltinFlow f) => f.title != 'New task'),
  ];

  for (final BuiltinFlow flow in ordered) {
    if (!flow.roles.contains(role)) {
      continue;
    }

    if (flow.needs.isNotEmpty &&
        !flow.needs.any((String word) => _hasWord(text, word))) {
      continue;
    }

    if (flow.keywords.any((String word) => _hasWord(text, word))) {
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
