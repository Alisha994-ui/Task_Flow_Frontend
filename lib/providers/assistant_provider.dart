import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
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

  /// True while the person has paused a question that is still being
  /// answered. The request keeps running in the background; if the
  /// answer lands while paused it is held in [_heldAnswer] and only
  /// shown when they resume.
  bool _isPaused = false;
  String? _heldAnswer;

  /// The last question that got no answer (error or timeout). It stays in
  /// the chat (as a [_failedId] bubble) with the reason and a Retry
  /// button, instead of silently vanishing (BUG-27).
  String? _failedQuestion;

  static const int _failedId = -5;

  /// A question that got its answer. Must differ from -1 (pending):
  /// cancel, retry and failure all act on "every message with id -1",
  /// so an answered question left at -1 was deleted or marked failed
  /// along with the next one.
  static const int _answeredId = -6;

  /// Moves the pending question (-1) to [_answeredId].
  void _settlePending() {
    _messages = _messages
        .map(
          (AssistantMessageModel m) => m.id == -1
              ? AssistantMessageModel(
                  id: _answeredId,
                  role: m.role,
                  text: m.text,
                  createdAt: m.createdAt,
                )
              : m,
        )
        .toList();
  }

  List<AssistantMessageModel> get messages =>
      List<AssistantMessageModel>.unmodifiable(_messages);

  bool get isLoading => _isLoading;

  /// True while a question is paused (see [pauseAsk]).
  bool get isPaused => _isPaused;

  /// True between sending a question and the answer arriving.
  bool get isThinking => _isThinking;

  String? get error => _error;

  /// Non-null when the last question failed; the panel shows [error] and a
  /// Retry button under it.
  String? get failedQuestion => _failedQuestion;

  /// Drops the failed question bubble and its error note.
  void dismissFailed() {
    if (_failedQuestion == null) {
      return;
    }

    _failedQuestion = null;
    _error = null;
    _messages = _messages
        .where((AssistantMessageModel m) => m.id != _failedId)
        .toList();
    notifyListeners();
  }

  static const Duration _askTimeout = Duration(seconds: 90);

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

    // Asking something new while an old question sits paused replaces
    // it: the old one is dropped, its late answer ignored.
    if (_isPaused) {
      _isPaused = false;
      _heldAnswer = null;
      _messages =
          _messages.where((AssistantMessageModel m) => m.id != -1).toList();
    }

    // A new question (or a retry) replaces the last failed one.
    if (_failedQuestion != null) {
      _failedQuestion = null;
      _messages = _messages
          .where((AssistantMessageModel m) => m.id != _failedId)
          .toList();
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
      final Future<String> call = AssistantService.ask(text);
      final String answer = await call.timeout(
        _askTimeout,
        onTimeout: () {
          // A paused question must not time out while the person is
          // away from it - keep waiting on the same request.
          if (_isPaused && requestId == _requestId) {
            return call;
          }

          throw TimeoutException(
            "Couldn't get an answer in time.",
          );
        },
      );

      // Cancelled, or superseded by a newer question, while this was
      // in flight - the spinner has already moved on, so do not splice
      // an old answer into whatever is on screen now.
      if (requestId != _requestId) {
        return null;
      }

      // Paused: keep the answer back until they resume.
      if (_isPaused) {
        _heldAnswer = answer;

        return null;
      }

      _settlePending();

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

      // Keep the question on screen, marked as failed, so it can be
      // resent - removing it made the question just disappear.
      _messages = _messages
          .map(
            (AssistantMessageModel m) => m.id == -1
                ? AssistantMessageModel(
                    id: _failedId,
                    role: m.role,
                    text: m.text,
                    createdAt: m.createdAt,
                  )
                : m,
          )
          .toList();
      _isPaused = false;
      _heldAnswer = null;
      final String message = _messageFor(e);
      _error = message;
      _failedQuestion = text;

      return message;
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
    if (!_isThinking && !_isPaused) {
      return;
    }

    _requestId++;
    _isThinking = false;
    _isPaused = false;
    _heldAnswer = null;
    _messages = _messages.where((AssistantMessageModel m) => m.id != -1).toList();
    _error = "Cancelled - didn't wait for an answer.";
    notifyListeners();
  }

  /// Pauses the question being answered. The spinner stops and the
  /// question stays in the chat; nothing new appears until [resumeAsk].
  void pauseAsk() {
    if (!_isThinking) {
      return;
    }

    _isPaused = true;
    _isThinking = false;
    notifyListeners();
  }

  /// Carries on after [pauseAsk]. Returns true if the held answer was
  /// shown right now; false if it is still on its way (the spinner
  /// comes back and the answer appears when it arrives).
  bool resumeAsk() {
    if (!_isPaused) {
      return false;
    }

    _isPaused = false;

    final String? answer = _heldAnswer;
    _heldAnswer = null;

    if (answer == null) {
      _isThinking = true;
      notifyListeners();

      return false;
    }

    _settlePending();
    _messages = <AssistantMessageModel>[
      ..._messages,
      AssistantMessageModel(
        id: -2,
        role: 'assistant',
        text: answer,
        createdAt: DateTime.now(),
      ),
    ];
    notifyListeners();

    return true;
  }

  Future<void> clear() async {
    try {
      await AssistantService.clear();
      _requestId++;
      _messages = <AssistantMessageModel>[];
      _error = null;
      _failedQuestion = null;
      _isThinking = false;
      _isPaused = false;
      _heldAnswer = null;
    } catch (e) {
      _error = friendlyError(e);
    }

    notifyListeners();
  }

  void reset() {
    _requestId++;
    _failedQuestion = null;
    _isPaused = false;
    _heldAnswer = null;
    _messages = <AssistantMessageModel>[];
    _isLoading = false;
    _isThinking = false;
    _error = null;
    notifyListeners();
  }

  /// Adds a question and an answer the app produced itself (from data it
  /// already has), so it appears in the chat like any other reply.
  void addLocalExchange(String question, String answer) {
    final DateTime now = DateTime.now();

    _messages = <AssistantMessageModel>[
      ..._messages,
      AssistantMessageModel(
        id: -3,
        role: 'user',
        text: question,
        createdAt: now,
      ),
      AssistantMessageModel(
        id: -4,
        role: 'assistant',
        text: answer,
        createdAt: now,
      ),
    ];
    _error = null;
    notifyListeners();
  }

  String _messageFor(Object e) {
    // Checked before string-munging: "TimeoutException: ..." contains
    // "Exception: " and would otherwise come out as "Timeout...".
    if (e is TimeoutException || e is RequestTimeoutException) {
      return "Couldn't get an answer. Please try again.";
    }

    final String message = _friendly(friendlyError(e)).trim();

    // Never fail without saying so.
    return message.isEmpty
        ? "Couldn't get an answer. Please try again."
        : message;
  }

  String _friendly(String raw) {
    final String message = raw.replaceFirst('Exception: ', '');

    if (message.contains('not configured')) {
      return 'The assistant is not set up on the server yet.';
    }

    return message;
  }
}
