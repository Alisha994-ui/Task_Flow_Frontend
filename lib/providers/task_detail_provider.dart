import 'package:flutter/foundation.dart';

import '../models/activity_log_model.dart';
import '../models/attachment_model.dart';
import '../models/comment_model.dart';
import '../models/subtask_model.dart';
import '../models/task_model.dart';
import '../services/attachment_service.dart';
import '../services/task_service.dart';

class TaskDetailProvider extends ChangeNotifier {
  TaskDetailProvider(this.taskId);

  final int taskId;

  TaskModel? _task;
  List<SubtaskModel> _subtasks = <SubtaskModel>[];
  List<CommentModel> _comments = <CommentModel>[];
  List<ActivityLogModel> _activity = <ActivityLogModel>[];
  List<AttachmentModel> _attachments = <AttachmentModel>[];

  bool _isLoading = false;
  bool _isBusy = false;
  String? _error;

  TaskModel? get task => _task;

  List<SubtaskModel> get subtasks => List<SubtaskModel>.unmodifiable(_subtasks);

  List<CommentModel> get comments => List<CommentModel>.unmodifiable(_comments);

  List<ActivityLogModel> get activity =>
      List<ActivityLogModel>.unmodifiable(_activity);

  List<AttachmentModel> get attachments =>
      List<AttachmentModel>.unmodifiable(_attachments);

  /// Files posted with one particular comment.
  List<AttachmentModel> attachmentsFor(int commentId) => _attachments
      .where((AttachmentModel a) => a.comment == commentId)
      .toList();

  bool _isUploading = false;

  bool get isUploading => _isUploading;

  bool get isLoading => _isLoading;

  bool get isBusy => _isBusy;

  String? get error => _error;

  int get doneSubtasks => _subtasks.where((SubtaskModel s) => s.isDone).length;

  Future<void> load({bool silent = false}) async {
    _isLoading = true;

    if (!silent) {
      _error = null;
      notifyListeners();
    }

    try {
      _task = await TaskService.getTask(taskId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();

      return;
    }

    // Side panels are optional - a failure there must not blank the screen.
    try {
      _subtasks = await TaskService.getSubtasks(taskId);
    } catch (_) {
      _subtasks = <SubtaskModel>[];
    }

    try {
      _comments = await TaskService.getComments(taskId);
    } catch (_) {
      _comments = <CommentModel>[];
    }

    try {
      _activity = await TaskService.getActivityLogs(taskId: taskId);
    } catch (_) {
      _activity = <ActivityLogModel>[];
    }

    try {
      _attachments = await AttachmentService.getForTask(taskId);
    } catch (_) {
      _attachments = <AttachmentModel>[];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => load(silent: _task != null);

  // -------------------------------------------------------------- subtasks

  Future<bool> addSubtask(String title) async {
    _isBusy = true;
    notifyListeners();

    try {
      final SubtaskModel created = await TaskService.createSubtask(
        taskId: taskId,
        title: title,
      );

      _subtasks = <SubtaskModel>[..._subtasks, created];

      return true;
    } catch (e) {
      _error = e.toString();

      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> toggleSubtask(SubtaskModel subtask) async {
    _isBusy = true;
    notifyListeners();

    try {
      final SubtaskModel updated = await TaskService.setSubtaskDone(
        subtaskId: subtask.id,
        isDone: !subtask.isDone,
      );

      _subtasks = _subtasks
          .map((SubtaskModel s) => s.id == updated.id ? updated : s)
          .toList();

      return true;
    } catch (e) {
      _error = e.toString();

      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteSubtask(int subtaskId) async {
    _isBusy = true;
    notifyListeners();

    try {
      await TaskService.deleteSubtask(subtaskId);
      _subtasks =
          _subtasks.where((SubtaskModel s) => s.id != subtaskId).toList();

      return true;
    } catch (e) {
      _error = e.toString();

      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------- comments

  /// Posts a comment, optionally with a file.
  ///
  /// The comment goes first because the attachment needs its id. If the
  /// upload then fails, the comment still stands - better than losing
  /// what the person wrote.
  Future<bool> addComment(String text, {String? filePath}) async {
    _isBusy = true;
    notifyListeners();

    try {
      final CommentModel created = await TaskService.addComment(
        taskId: taskId,
        text: text,
      );

      _comments = <CommentModel>[..._comments, created];

      if (filePath != null) {
        try {
          final AttachmentModel file = await AttachmentService.upload(
            taskId: taskId,
            filePath: filePath,
            commentId: created.id,
          );

          _attachments = <AttachmentModel>[..._attachments, file];
        } catch (e) {
          _error = 'Comment posted, but the file did not upload.';
        }
      }

      // The backend writes a COMMENT_ADDED entry, so pull the log again.
      try {
        _activity = await TaskService.getActivityLogs(taskId: taskId);
      } catch (_) {
        // Keep the old log if the refresh fails.
      }

      return true;
    } catch (e) {
      _error = e.toString();

      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Called after the task itself changes elsewhere on the screen.
  void setTask(TaskModel task) {
    _task = task;
    notifyListeners();
  }

  Future<void> reloadActivity() async {
    try {
      _activity = await TaskService.getActivityLogs(taskId: taskId);
      notifyListeners();
    } catch (_) {
      // Non-critical.
    }
  }

  // ----------------------------------------------------------- attachments

  /// Returns null on success, or a message to show the user.
  Future<String?> uploadAttachment(String filePath) async {
    _isUploading = true;
    _error = null;
    notifyListeners();

    try {
      final AttachmentModel created = await AttachmentService.upload(
        taskId: taskId,
        filePath: filePath,
      );

      _attachments = <AttachmentModel>[..._attachments, created];

      // The backend writes an ATTACHMENT_ADDED entry.
      await reloadActivity();

      return null;
    } catch (e) {
      _error = e.toString();

      return 'Could not upload the file.';
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAttachment(int attachmentId) async {
    _isBusy = true;
    notifyListeners();

    try {
      await AttachmentService.delete(attachmentId);
      _attachments = _attachments
          .where((AttachmentModel a) => a.id != attachmentId)
          .toList();

      return true;
    } catch (e) {
      _error = e.toString();

      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
