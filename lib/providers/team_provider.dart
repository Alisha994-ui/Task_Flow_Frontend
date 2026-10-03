import 'package:flutter/foundation.dart';

import '../models/team_model.dart';
import '../services/team_service.dart';

class TeamProvider extends ChangeNotifier {
  List<TeamModel> _all = <TeamModel>[];
  bool _isLoading = false;
  String? _error;
  String _search = '';

  bool get isLoading => _isLoading;

  String? get error => _error;

  String get search => _search;

  List<TeamModel> get allTeams => List<TeamModel>.unmodifiable(_all);

  int get activeCount => _all.where((TeamModel t) => t.isActive).length;

  List<TeamModel> get teams {
    final String query = _search.trim().toLowerCase();

    if (query.isEmpty) {
      return allTeams;
    }

    return _all
        .where((TeamModel t) =>
            t.name.toLowerCase().contains(query) ||
            t.description.toLowerCase().contains(query))
        .toList();
  }

  TeamModel? byId(int? id) {
    if (id == null) {
      return null;
    }

    for (final TeamModel team in _all) {
      if (team.id == id) {
        return team;
      }
    }

    return null;
  }

  String nameFor(int? id, {String fallback = 'No team'}) {
    if (id == null) {
      return fallback;
    }

    final TeamModel? team = byId(id);

    return team?.name ?? 'Team #$id';
  }

  void setSearch(String value) {
    _search = value;
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
      _all = await TeamService.getTeams();
      _error = null;
    } catch (e) {
      _error = e.toString();
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

  /// Clears everything on sign out.
  void reset() {
    _all = <TeamModel>[];
    _isLoading = false;
    _error = null;
    _search = '';
    notifyListeners();
  }
}
