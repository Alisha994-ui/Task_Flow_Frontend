import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/coach/builtin_flows.dart';
import '../../models/assistant_message_model.dart';
import '../../providers/assistant_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/coach_provider.dart';

/// The assistant, as a panel that slides in over whatever you were
/// doing.
///
/// A drawer rather than a page on purpose: asking "where do I add a
/// project?" and then being taken away from the app to read the answer
/// is backwards. This way the answer and the screen it talks about are
/// one swipe apart.
///
/// [destinations] maps the names the assistant may use - "projects",
/// "tasks" - to the tab index in the panel that hosts it. The assistant
/// can only point at what is in this map, so there is no way for it to
/// send somebody to a screen their role does not have.
class AssistantPanel extends StatefulWidget {
  const AssistantPanel({
    super.key,
    required this.destinations,
    required this.onGoTo,
  });

  final Map<String, int> destinations;

  /// Called with a tab index when the person taps the button. The host
  /// panel switches tab and closes the drawer.
  final void Function(int index) onGoTo;

  @override
  State<AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<AssistantPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final AssistantProvider assistant = context.read<AssistantProvider>();

      if (assistant.messages.isEmpty) {
        assistant.load();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final String text = preset ?? _controller.text;

    if (text.trim().isEmpty) {
      return;
    }

    _controller.clear();
    FocusScope.of(context).unfocus();

    // The common walkthroughs are written into the app. Starting one
    // costs nothing and works with no network - and the free tier only
    // allows a handful of model requests a day, which is no way to
    // learn where a button is.
    final String role = context.read<AuthProvider>().user?.role ?? '';
    final BuiltinFlow? known = matchBuiltinFlow(text, role);

    if (known != null && widget.destinations.containsKey(known.destination)) {
      context.read<CoachProvider>().start(
            known.steps,
            title: known.title,
          );

      Navigator.of(context).pop();
      widget.onGoTo(widget.destinations[known.destination]!);

      return;
    }

    final AssistantProvider assistant = context.read<AssistantProvider>();
    final String? problem = await assistant.ask(text);

    if (!mounted) {
      return;
    }

    _scrollToEnd();

    if (problem != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(problem),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );

      return;
    }

    _followAnswer(assistant.messages.isEmpty ? '' : assistant.messages.last.text);
  }

  /// Acts on what the assistant just said.
  ///
  /// If the answer points somewhere, go there and leave the steps
  /// floating over that screen - reading instructions in a chat and
  /// then trying to remember them is the thing this avoids.
  void _followAnswer(String raw) {
    final _Parsed parsed = _Parsed.from(raw);
    final String? destination = parsed.destination;

    if (destination == null || !widget.destinations.containsKey(destination)) {
      return;
    }

    final List<CoachStep> steps = _stepsFrom(parsed.text);

    if (steps.isEmpty) {
      // A plain informational answer that only points somewhere (e.g.
      // naming a manager and suggesting the More tab) rather than a
      // real walkthrough. The text is already in the chat bubble above
      // this - closing the panel and jumping away right now would
      // swallow it before the person can read it. The bubble's own
      // shortcut button (destinations/onGoTo) is how they follow it
      // when they are ready.
      return;
    }

    context.read<CoachProvider>().start(
          steps,
          title: _label(destination),
        );

    Navigator.of(context).pop();
    widget.onGoTo(widget.destinations[destination]!);
  }

  /// Splits an answer into the steps it listed.
  ///
  /// Each step may carry [TARGET:team_name], naming the control it is
  /// about. That is stripped out here - to the reader it is a bubble
  /// pointing at something, not text.
  static final RegExp _targetTag = RegExp(
    r'\[TARGET:\s*([a-z0-9_]+)\s*\]',
    caseSensitive: false,
  );

  static List<CoachStep> _stepsFrom(String text) {
    final List<CoachStep> steps = <CoachStep>[];
    final RegExp numbered = RegExp(r'^\s*(?:\d+[.)]|[-*])\s+(.*)$');

    for (final String line in text.split('\n')) {
      final RegExpMatch? match = numbered.firstMatch(line);

      if (match == null) {
        continue;
      }

      final String raw = (match.group(1) ?? '').trim();

      if (raw.isEmpty) {
        continue;
      }

      final RegExpMatch? tag = _targetTag.firstMatch(raw);

      steps.add(
        CoachStep(
          raw.replaceAll(_targetTag, '').trim(),
          target: tag?.group(1)?.toLowerCase(),
        ),
      );
    }

    if (steps.isNotEmpty) {
      return steps;
    }

    final String trimmed = text.replaceAll(_targetTag, '').trim();

    return trimmed.isEmpty ? <CoachStep>[] : <CoachStep>[CoachStep(trimmed)];
  }

  /// Used by the button on an older answer, when they want to be taken
  /// back through something they asked earlier.
  void _goTo(String destination) {
    final int? index = widget.destinations[destination];

    if (index == null) {
      return;
    }

    final AssistantProvider assistant = context.read<AssistantProvider>();
    final AssistantMessageModel? message = assistant.messages
        .where((AssistantMessageModel m) => m.text.contains(destination))
        .lastOrNull;

    if (message != null) {
      final List<CoachStep> steps =
          _stepsFrom(_Parsed.from(message.text).text);

      if (steps.isNotEmpty) {
        context.read<CoachProvider>().start(
              steps,
              title: _label(destination),
            );
      }
    }

    Navigator.of(context).pop();
    widget.onGoTo(index);
  }

  Future<void> _confirmClear() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Clear this conversation?'),
          content: const Text(
            'The assistant will forget what you have asked so far.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep it'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await context.read<AssistantProvider>().clear();
    }
  }

  /// Openers, picked for the role - a new person has no idea what to
  /// type into an empty box. The first is always a how-to.
  /// Openers for an empty panel.
  ///
  /// The walkthroughs the app knows by heart come first: they start
  /// instantly, work with no network and cannot fail, which is what
  /// somebody opening this for the first time should meet. Questions
  /// about their data follow, and those go to the assistant.
  List<String> _suggestions(String role) {
    final List<String> walkthroughs = builtinFlowsFor(role)
        .take(4)
        .map((BuiltinFlow f) => 'How do I: ${f.title.toLowerCase()}')
        .toList();

    const Map<String, List<String>> questions = <String, List<String>>{
      'ADMIN': <String>[
        'Which projects are behind schedule?',
        'Who has the most open work?',
      ],
      'PROJECT_MANAGER': <String>[
        'How are my projects doing?',
        'What is overdue right now?',
      ],
      'TEAM_LEAD': <String>[
        'What is my team working on?',
        'What is overdue in my team?',
      ],
      'EMPLOYEE': <String>[
        'What should I do first today?',
        'Am I late on anything?',
      ],
    };

    return <String>[
      ...walkthroughs,
      ...(questions[role] ?? questions['EMPLOYEE']!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AssistantProvider assistant = context.watch<AssistantProvider>();
    final String role = context.read<AuthProvider>().user?.role ?? '';
    final List<AssistantMessageModel> messages = assistant.messages;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.92,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            // ------------------------------------------------- header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Assistant',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (messages.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear conversation',
                      onPressed: _confirmClear,
                      icon: const Icon(Icons.delete_sweep_outlined),
                    ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ----------------------------------------------- messages
            Expanded(
              child: assistant.isLoading && messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : messages.isEmpty
                      ? _Empty(
                          suggestions: _suggestions(role),
                          onPick: _send,
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          itemCount: messages.length +
                              (assistant.isThinking ? 1 : 0),
                          itemBuilder: (BuildContext context, int index) {
                            if (index >= messages.length) {
                              return const _Thinking();
                            }

                            return _Bubble(
                              message: messages[index],
                              destinations: widget.destinations,
                              onGoTo: _goTo,
                            );
                          },
                        ),
            ),

            // ------------------------------------------------ composer
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Ask about your work, or how to do it',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    // While thinking this doubles as Cancel - a stalled
                    // reply must never leave the person with no way out
                    // but to close the panel.
                    tooltip: assistant.isThinking ? 'Cancel' : null,
                    onPressed: assistant.isThinking
                        ? () => assistant.cancelAsk()
                        : () => _send(),
                    icon: assistant.isThinking
                        ? const Icon(Icons.close, size: 18)
                        : const Icon(Icons.send, size: 18),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'It can read your work, but not change it.',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Splits an answer into what to show and where it points.
///
/// The assistant ends a reply with [GOTO:tasks] when the next thing to
/// do is go somewhere. That line is for the app, never for the reader.
class _Parsed {
  const _Parsed(this.text, this.destination);

  final String text;
  final String? destination;

  static final RegExp _marker = RegExp(
    r'\[GOTO:\s*([a-z_]+)\s*\]',
    caseSensitive: false,
  );

  factory _Parsed.from(String raw) {
    final RegExpMatch? match = _marker.firstMatch(raw);

    if (match == null) {
      return _Parsed(raw.trim(), null);
    }

    return _Parsed(
      raw.replaceAll(_marker, '').trim(),
      match.group(1)?.toLowerCase(),
    );
  }

  /// What to show in the chat: the steps, without the target tags.
  String get display =>
      text.replaceAll(_AssistantPanelState._targetTag, '').trim();
}

String _label(String destination) {
  switch (destination) {
    case 'today':
      return 'Today';
    case 'my_team':
    case 'team':
      return 'My team';
    default:
      return destination[0].toUpperCase() + destination.substring(1);
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.suggestions, required this.onPick});

  final List<String> suggestions;
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      children: <Widget>[
        Text(
          'Ask about your work',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'It knows your tasks and deadlines - and only yours. It can '
          'also walk you through the app.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 22),
        ...suggestions.map(
          (String text) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: () => onPick(text),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(text, textAlign: TextAlign.left),
                  ),
                  const Icon(Icons.north_east, size: 14),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.destinations,
    required this.onGoTo,
  });

  final AssistantMessageModel message;
  final Map<String, int> destinations;
  final void Function(String) onGoTo;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool mine = message.isUser;
    final _Parsed parsed = _Parsed.from(message.text);

    // Only offer the button if this panel actually has that tab.
    final String? destination =
        (parsed.destination != null &&
                destinations.containsKey(parsed.destination))
            ? parsed.destination
            : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment:
                mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!mine) ...<Widget>[
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: mine
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(mine ? 16 : 4),
                      bottomRight: Radius.circular(mine ? 4 : 16),
                    ),
                    border: mine
                        ? null
                        : Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: SelectableText(
                    parsed.display,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: mine
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (destination != null)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 8),
              child: FilledButton.tonalIcon(
                onPressed: () => onGoTo(destination),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text('Take me to ${_label(destination)}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 14,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
