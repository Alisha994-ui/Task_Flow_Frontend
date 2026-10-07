import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/assistant_message_model.dart';
import '../../providers/assistant_provider.dart';
import '../../providers/auth_provider.dart';

/// Ask questions about your own work.
///
/// Everything it knows comes from the server, scoped to whoever is
/// signed in - an employee's assistant cannot see anybody else's tasks,
/// because the server never sends them.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AssistantProvider>().load();
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

    final String? problem =
        await context.read<AssistantProvider>().ask(text);

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
    }
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
  /// type into an empty box.
  ///
  /// The first one is always a how-to: on day one "show me around" is
  /// a more useful question than anything about the data.
  List<String> _suggestions(String role) {
    switch (role) {
      case 'ADMIN':
        return <String>[
          'Show me around the app',
          'How do I create a team and add people?',
          'Which projects are behind schedule?',
          'Who has the most open work?',
        ];
      case 'PROJECT_MANAGER':
        return <String>[
          'Show me around the app',
          'How do I assign a task to someone?',
          'How are my projects doing?',
          'What is overdue right now?',
        ];
      case 'TEAM_LEAD':
        return <String>[
          'Show me around the app',
          'What is my team working on?',
          'What is overdue in my team?',
          'How do I reopen a completed task?',
        ];
      default:
        return <String>[
          'Show me around the app',
          'What should I do first today?',
          'How do I track time on a task?',
          'Am I late on anything?',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AssistantProvider assistant = context.watch<AssistantProvider>();
    final String role = context.read<AuthProvider>().user?.role ?? '';
    final List<AssistantMessageModel> messages = assistant.messages;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant'),
        actions: <Widget>[
          if (messages.isNotEmpty)
            IconButton(
              tooltip: 'Clear conversation',
              onPressed: _confirmClear,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
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
                        itemCount:
                            messages.length + (assistant.isThinking ? 1 : 0),
                        itemBuilder: (BuildContext context, int index) {
                          if (index >= messages.length) {
                            return const _Thinking();
                          }

                          return _Bubble(message: messages[index]);
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
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
    );
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
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: <Widget>[
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 28,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Ask about your work',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'It knows your tasks and deadlines - and only yours. It can '
          'also show you how to use the app.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 26),
        ...suggestions.map(
          (String text) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: () => onPick(text),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
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
  const _Bubble({required this.message});

  final AssistantMessageModel message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool mine = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!mine) ...<Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 15,
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
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: mine
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
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
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 15,
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
