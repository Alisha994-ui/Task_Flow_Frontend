import 'package:flutter/foundation.dart';

/// One instruction, and the thing on screen it points at.
class CoachStep {
  const CoachStep(this.text, {this.target});

  final String text;

  /// A name registered by a CoachTarget, or null when the step is not
  /// about one particular control.
  final String? target;
}

/// A walkthrough in progress.
///
/// The assistant answers "how do I add a team?" with steps, and the app
/// shows them one at a time next to the control each one is about.
class CoachProvider extends ChangeNotifier {
  List<CoachStep> _steps = <CoachStep>[];
  int _index = 0;
  String _title = '';

  List<CoachStep> get steps => List<CoachStep>.unmodifiable(_steps);

  bool get isActive => _steps.isNotEmpty;

  int get index => _index;

  int get total => _steps.length;

  String get title => _title;

  CoachStep? get currentStep => _steps.isEmpty ? null : _steps[_index];

  String get current => currentStep?.text ?? '';

  String? get target => currentStep?.target;

  bool get isFirst => _index == 0;

  bool get isLast => _index >= _steps.length - 1;

  void start(List<CoachStep> steps, {String title = ''}) {
    final List<CoachStep> cleaned =
        steps.where((CoachStep s) => s.text.trim().isNotEmpty).toList();

    if (cleaned.isEmpty) {
      return;
    }

    _steps = cleaned;
    _index = 0;
    _title = title;
    notifyListeners();
  }

  void next() {
    if (_index < _steps.length - 1) {
      _index++;
      notifyListeners();
    }
  }

  void previous() {
    if (_index > 0) {
      _index--;
      notifyListeners();
    }
  }

  void stop() {
    _steps = <CoachStep>[];
    _index = 0;
    _title = '';
    notifyListeners();
  }

  void reset() => stop();
}
