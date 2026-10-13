import '../core/utils/errors.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_dashboard_model.dart';
import '../services/admin_dashboard_service.dart';

class AdminDashboardProvider extends ChangeNotifier {
  AdminDashboardModel? _dashboard;
  bool _isLoading = false;
  String? _error;

  AdminDashboardModel? get dashboard => _dashboard;

  bool get isLoading => _isLoading;

  String? get error => _error;

  bool get hasData => _dashboard != null;

  /// Percentage of tasks that are completed, 0-100.
  int get completionRate {
    final AdminDashboardModel? data = _dashboard;

    if (data == null || data.totalTasks == 0) {
      return 0;
    }

    return ((data.completedTasks / data.totalTasks) * 100).round();
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
      _dashboard = await AdminDashboardService.getDashboard();
      _error = null;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(silent: _dashboard != null);

  /// Clears everything on sign out.
  void reset() {
    _dashboard = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
