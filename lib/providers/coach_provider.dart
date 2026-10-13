import 'package:flutter/foundation.dart';

/// One instruction, and the thing on screen it points at.
class CoachStep {
  const CoachStep(this.text, {this.target});

  final String text;

  /// A name registered by a CoachTarget, or null when the step is not
  /// about one particular control.
  final String? target;

  /// True when the step is "press this button" and pressing it is what
  /// moves the tour on: a + button opens the form (a new screen), a
  /// save button closes it or saves in place. For these the bubble
  /// hides Next while the button is on screen - pressing Next instead
  /// left the person on the list with "type the name here" pointing at
  /// nothing. Derived from the name, so steps written by the server
  /// assistant behave the same as the built-in ones.
  bool get waitsForTap {
    final String? name = target;

    if (name == null) {
      return false;
    }

    return name.endsWith('_fab') ||
        name.endsWith('_save') ||
        name == 'team_save_and_members';
  }
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

  /// Dropdown menus, dialogs, date pickers and bottom sheets open above
  /// the page. The overlay sits above the whole navigator, so without
  /// this it dimmed the open menu, lit up whatever menu item happened to
  /// cover the field, and parked the bubble on top of the choices.
  /// While one is open the overlay steps aside; it comes back when the
  /// popup closes.
  int _popups = 0;

  bool get popupOpen => _popups > 0;

  void popupOpened() {
    _popups++;

    if (_popups == 1) {
      notifyListeners();
    }
  }

  void popupClosed() {
    if (_popups == 0) {
      return;
    }

    _popups--;

    if (_popups == 0) {
      notifyListeners();
    }
  }

  /// Changes on every start and stop, so the navigator observer can tell
  /// "the screen this tour opened" from a screen a later tour opened.
  int _generation = 0;

  int get generation => _generation;

  /// The person used the control [name] (picked from a dropdown, saved
  /// the team). If the current step is about that control, move on -
  /// the step is done, and making them press Next as well is one tap
  /// too many. Text fields do not call this: typing is not finishing.
  void done(String name) {
    if (!isActive || target != name) {
      return;
    }

    if (isLast) {
      stop();
    } else {
      next();
    }
  }

  void start(List<CoachStep> steps, {String title = ''}) {
    final List<CoachStep> cleaned =
        steps.where((CoachStep s) => s.text.trim().isNotEmpty).toList();

    if (cleaned.isEmpty) {
      return;
    }

    _steps = cleaned;
    _index = 0;
    _title = title;
    _generation++;
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
    if (_steps.isEmpty) {
      return;
    }

    _generation++;
    _steps = <CoachStep>[];
    _index = 0;
    _title = '';
    notifyListeners();
  }

  void reset() => stop();
}
