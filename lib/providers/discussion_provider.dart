import 'package:flutter/foundation.dart';

import '../models/project_message_model.dart';
import '../services/discussion_service.dart';

/// One project's conversation. Created per screen, like
/// ProjectDetailProvider.
class DiscussionProvider extends ChangeNotifier {
  DiscussionProvider(this.projectId);

  final int projectId;

  List<ProjectMessageModel> _messages = <ProjectMessageModel>[];
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;

  List<ProjectMessageModel> get messages =>
      List<ProjectMessageModel>.unmodifiable(_messages);

  bool get isLoading => _isLoading;

  bool get isSending => _isSending;

  String? get error => _error;

  Future<void> load({bool silent = false}) async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;

    if (!silent) {
      _error = null;
      notifyListeners();
    }

    try {
      _messages = await DiscussionService.getMessages(projectId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(silent: _messages.isNotEmpty);

  /// Returns null on success, or a message to show the person.
  Future<String?> send({String text = '', String? filePath}) async {
    if (text.trim().isEmpty && filePath == null) {
      return null;
    }

    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final ProjectMessageModel sent = filePath == null
          ? await DiscussionService.send(
              projectId: projectId,
              text: text.trim(),
            )
          : await DiscussionService.sendWithFile(
              projectId: projectId,
              filePath: filePath,
              text: text.trim(),
            );

      _messages = <ProjectMessageModel>[..._messages, sent];

      return null;
    } catch (e) {
      _error = e.toString();

      return 'Could not send that.';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<bool> delete(int messageId) async {
    try {
      await DiscussionService.delete(messageId);
      _messages = _messages
          .where((ProjectMessageModel m) => m.id != messageId)
          .toList();
      notifyListeners();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();

      return false;
    }
  }
}
