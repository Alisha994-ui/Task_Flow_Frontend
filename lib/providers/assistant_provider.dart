import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/errors.dart';
import '../models/assistant_message_model.dart';
import '../services/assistant_service.dart';

class AssistantProvider extends ChangeNotifier {
  List<AssistantMessageModel> _messages = <AssistantMessageModel>[];
  bool _isLoading = false;
  bool _isThinking = false;
  String? _error;

  /// Bumped on every new ask() and every cancel(), so a reply that
  /// finally arrives for a question the person already cancelled (or
  /// replaced with a new one) is recognised as stale and dropped
  /// instead of appearing minutes later out of nowhere.
  int _requestId = 0;

  List<AssistantMessageModel> get messages =>
      List<AssistantMessageModel>.unmodifiable(_messages);

  bool get isLoading => _isLoading;

  /// True between sending a question and the answer arriving.
  bool get isThinking => _isThinking;

  String? get error => _error;

  static const Duration _askTimeout = Duration(seconds: 30);

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _messages = await AssistantService.getThread();
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns null on success, or something to show the person.
  Future<String?> ask(String question) async {
    final String text = question.trim();

    if (text.isEmpty || _isThinking) {
      return null;
    }

    final int requestId = ++_requestId;

    // Show the question immediately. Waiting for the round trip makes
    // the app feel broken on a slow connection.
    _messages = <AssistantMessageModel>[
      ..._messages,
      AssistantMessageModel.pending(text),
    ];
    _isThinking = true;
    _error = null;
    notifyListeners();

    try {
      final String answer = await AssistantService.ask(text).timeout(
        _askTimeout,
        onTimeout: () => throw TimeoutException(
          "Couldn't get an answer in time.",
        ),
      );

      // Cancelled, or superseded by a newer question, while this was
      // in flight - the spinner has already moved on, so do not splice
      // an old answer into whatever is on screen now.
      if (requestId != _requestId) {
        return null;
      }

      _messages = <AssistantMessageModel>[
        ..._messages,
        AssistantMessageModel(
          id: -2,
          role: 'assistant',
          text: answer,
          createdAt: DateTime.now(),
        ),
      ];

      return null;
    } catch (e) {
      if (requestId != _requestId) {
        return null;
      }

      // Drop the optimistic question - it never got an answer, and
      // leaving it there suggests it did.
      _messages = _messages
          .where((AssistantMessageModel m) => m.id != -1)
          .toList();
      _error = friendlyError(e);

      return _friendly(e.toString());
    } finally {
      if (requestId == _requestId) {
        _isThinking = false;
        notifyListeners();
      }
    }
  }

  /// Stops waiting on whatever `ask()` call is in flight. The real HTTP
  /// request may still finish on its own, but its result is now stale
  /// (see the requestId check in `ask`) and is ignored.
  void cancelAsk() {
    if (!_isThinking) {
      return;
    }

    _requestId++;
    _isThinking = false;
    _messages = _messages.where((AssistantMessageModel m) => m.id != -1).toList();
    _error = "Cancelled - didn't wait for an answer.";
    notifyListeners();
  }

  Future<void> clear() async {
    try {
      await AssistantService.clear();
      _messages = <AssistantMessageModel>[];
      _error = null;
    } catch (e) {
      _error = friendlyError(e);
    }

    notifyListeners();
  }

  void reset() {
    _requestId++;
    _messages = <AssistantMessageModel>[];
    _isLoading = false;
    _isThinking = false;
    _error = null;
    notifyListeners();
  }

  String _friendly(String raw) {
    final String message = raw.replaceFirst('Exception: ', '');

    if (message.contains('not configured')) {
      return 'The assistant is not set up on the server yet.';
    }

    return message;
  }
}
