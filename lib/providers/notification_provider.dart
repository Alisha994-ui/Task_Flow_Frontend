import '../core/utils/errors.dart';
import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationModel> _all = <NotificationModel>[];
  bool _isLoading = false;
  bool _isBusy = false;
  String? _error;
  bool _unreadOnly = false;

  bool get isLoading => _isLoading;

  bool get isBusy => _isBusy;

  String? get error => _error;

  bool get unreadOnly => _unreadOnly;

  List<NotificationModel> get allNotifications =>
      List<NotificationModel>.unmodifiable(_all);

  /// The list the screen renders.
  List<NotificationModel> get notifications => _unreadOnly
      ? _all.where((NotificationModel n) => !n.isRead).toList()
      : allNotifications;

  /// Drives the badge on the bell icon.
  int get unreadCount =>
      _all.where((NotificationModel n) => !n.isRead).length;

  bool get hasUnread => unreadCount > 0;

  void setUnreadOnly(bool value) {
    _unreadOnly = value;
    notifyListeners();
  }

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
      _all = await NotificationService.getNotifications();
      _error = null;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(silent: _all.isNotEmpty);

  Future<void> ensureLoaded() async {
    if (_all.isEmpty && !_isLoading) {
      await load();
    }
  }

  /// Marks one as read. Already-read ones are skipped, so tapping a read
  /// notification costs nothing.
  Future<bool> markRead(NotificationModel notification) async {
    if (notification.isRead) {
      return true;
    }

    // Update locally first so the badge reacts immediately.
    _all = _all
        .map((NotificationModel n) =>
            n.id == notification.id ? n.asRead() : n)
        .toList();
    notifyListeners();

    try {
      await NotificationService.markRead(notification.id);

      return true;
    } catch (e) {
      _error = friendlyError(e);

      // Put it back the way it was.
      _all = _all
          .map((NotificationModel n) =>
              n.id == notification.id ? notification : n)
          .toList();
      notifyListeners();

      return false;
    }
  }

  Future<bool> markAllRead() async {
    if (!hasUnread) {
      return true;
    }

    _isBusy = true;
    notifyListeners();

    try {
      await NotificationService.markAllRead();
      _all = _all.map((NotificationModel n) => n.asRead()).toList();

      return true;
    } catch (e) {
      _error = friendlyError(e);

      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Clears everything on sign out.
  void reset() {
    _all = <NotificationModel>[];
    _isLoading = false;
    _isBusy = false;
    _error = null;
    _unreadOnly = false;
    notifyListeners();
  }
}
