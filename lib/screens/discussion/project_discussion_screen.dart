import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/auto_refresh.dart';

import '../../models/project_message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/discussion_provider.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../../widgets/admin/async_view.dart';

/// One conversation per project, for the things that belong to the whole
/// project rather than to a single task.
class ProjectDiscussionScreen extends StatelessWidget {
  const ProjectDiscussionScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    this.embedded = false,
  });

  final int projectId;
  final String projectName;

  /// True when this sits inside a project's TabBarView. It then drops
  /// its own Scaffold and app bar, which would otherwise stack a second
  /// header inside the first.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DiscussionProvider>(
      create: (_) => DiscussionProvider(projectId)..load(),
      child: _DiscussionView(
        projectName: projectName,
        embedded: embedded,
      ),
    );
  }
}

class _DiscussionView extends StatefulWidget {
  const _DiscussionView({
    required this.projectName,
    required this.embedded,
  });

  final String projectName;
  final bool embedded;

  @override
  State<_DiscussionView> createState() => _DiscussionViewState();
}

class _DiscussionViewState extends State<_DiscussionView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  PlatformFile? _pending;

  /// A conversation goes stale faster than a dashboard, so it polls
  /// more often.
  late final AutoRefresher _auto;

  @override
  void initState() {
    super.initState();

    _auto = AutoRefresher(
      onRefresh: () => context.read<DiscussionProvider>().refresh(),
      interval: const Duration(seconds: 15),
    )..start();
  }

  @override
  void dispose() {
    _auto.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _pickFile() async {
    final List<PlatformFile> picked = await FilePicker.pickFiles();

    if (picked.isEmpty || picked.first.path == null) {
      return;
    }

    setState(() => _pending = picked.first);
  }

  Future<void> _send() async {
    final String text = _controller.text;
    final PlatformFile? file = _pending;

    if (text.trim().isEmpty && file == null) {
      return;
    }

    final DiscussionProvider discussion = context.read<DiscussionProvider>();
    final String? problem = await discussion.send(
      text: text,
      filePath: file?.path,
    );

    if (!mounted) {
      return;
    }

    if (problem == null) {
      _controller.clear();
      setState(() => _pending = null);
      _scrollToEnd();
    } else {
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DiscussionProvider discussion = context.watch<DiscussionProvider>();
    final int? myId = context.watch<AuthProvider>().user?.id;
    final List<ProjectMessageModel> messages = discussion.messages;

    final Widget body = Column(
        children: <Widget>[
          const _ScopeHint(
            icon: Icons.forum_outlined,
            text: 'Anything about the project as a whole. '
                'For one task, use its Comments tab.',
          ),
          Expanded(
            child: AsyncView(
              isLoading: discussion.isLoading && messages.isEmpty,
              error: messages.isEmpty ? discussion.error : null,
              isEmpty: messages.isEmpty,
              onRetry: discussion.refresh,
              emptyIcon: Icons.forum_outlined,
              emptyTitle: 'No messages yet',
              emptyMessage:
                  'Use this for anything about the project as a whole - '
                  'a decision, a call, a file the team needs.',
              child: RefreshIndicator(
                onRefresh: discussion.refresh,
                child: ListView.builder(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: messages.length,
                  itemBuilder: (BuildContext context, int index) {
                    final ProjectMessageModel message = messages[index];
                    final bool mine = message.user == myId;

                    // Only label a message when the speaker changes -
                    // a run from one person reads as one turn.
                    final bool showAuthor = index == 0 ||
                        messages[index - 1].user != message.user;

                    return _MessageBubble(
                      message: message,
                      mine: mine,
                      showAuthor: showAuthor,
                      onDelete: mine
                          ? () => discussion.delete(message.id)
                          : null,
                    );
                  },
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (_pending != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.attach_file,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _pending!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove file',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => _pending = null),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Attach a file',
                        onPressed: discussion.isSending ? null : _pickFile,
                        icon: const Icon(Icons.attach_file),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Message the team',
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
                        onPressed: discussion.isSending ? null : _send,
                        icon: discussion.isSending
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Discussion'),
            Text(
              widget.projectName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: body,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.showAuthor,
    this.onDelete,
  });

  final ProjectMessageModel message;
  final bool mine;
  final bool showAuthor;
  final VoidCallback? onDelete;

  String get _time {
    final DateTime? at = message.createdAt?.toLocal();

    if (at == null) {
      return '';
    }

    final String hour = at.hour.toString().padLeft(2, '0');
    final String minute = at.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Future<void> _openFile(BuildContext context) async {
    final bool opened = await launchUrl(
      Uri.parse(message.url),
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not open this file')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Color bubble = mine
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surface;
    final Color onBubble = mine
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Padding(
      padding: EdgeInsets.only(top: showAuthor ? 14 : 4),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (!mine) ...<Widget>[
            SizedBox(
              width: 32,
              child: showAuthor
                  ? UserAvatar(name: message.userFullName, radius: 16)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: onDelete == null
                  ? null
                  : () => _confirmDelete(context),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                decoration: BoxDecoration(
                  color: bubble,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (showAuthor && !mine) ...<Widget>[
                      Text(
                        message.userFullName,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (message.text.trim().isNotEmpty)
                      Text(
                        message.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: onBubble,
                        ),
                      ),
                    if (message.hasFile) ...<Widget>[
                      if (message.text.trim().isNotEmpty)
                        const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _openFile(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: onBubble.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                message.isImage
                                    ? Icons.image_outlined
                                    : Icons.insert_drive_file_outlined,
                                size: 16,
                                color: onBubble,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  message.fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      theme.textTheme.bodySmall?.copyWith(
                                    color: onBubble,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.north_east,
                                size: 12,
                                color: onBubble,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _time,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: onBubble.withValues(alpha: 0.6),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete this message?'),
          content: const Text('It disappears for everyone in the project.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep it'),
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

    if (confirmed == true) {
      onDelete?.call();
    }
  }
}

/// One quiet line saying what belongs on this screen. Comments and the
/// discussion look alike, so the difference has to be written down
/// rather than guessed.
class _ScopeHint extends StatelessWidget {
  const _ScopeHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
