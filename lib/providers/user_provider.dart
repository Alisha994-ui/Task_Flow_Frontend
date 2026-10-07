import '../core/utils/errors.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/project_constants.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class UserProvider extends ChangeNotifier {
  List<UserModel> _all = <UserModel>[];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  String _search = '';
  String _roleFilter = kFilterAll;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  String? get error => _error;

  String get search => _search;

  String get roleFilter => _roleFilter;

  List<UserModel> get allUsers => List<UserModel>.unmodifiable(_all);

  int get activeCount => _all.where((UserModel u) => u.status).length;

  List<UserModel> get users {
    final String query = _search.trim().toLowerCase();

    return _all.where((UserModel u) {
      if (_roleFilter != kFilterAll && u.role != _roleFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return u.fullName.toLowerCase().contains(query) ||
          u.username.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query);
    }).toList();
  }

  UserModel? byId(int? id) {
    if (id == null) {
      return null;
    }

    for (final UserModel user in _all) {
      if (user.id == id) {
        return user;
      }
    }

    return null;
  }

  /// Safe label for a foreign key that may point outside the loaded page.
  String nameFor(int? id, {String fallback = 'Unassigned'}) {
    if (id == null) {
      return fallback;
    }

    final UserModel? user = byId(id);

    return user?.fullName ?? 'User #$id';
  }

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  void setRoleFilter(String value) {
    _roleFilter = value;
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
      _all = await UserService.getUsers();
      _error = null;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(silent: _all.isNotEmpty);

  /// Loads once - used by pickers that just need the list to exist.
  Future<void> ensureLoaded() async {
    if (_all.isEmpty && !_isLoading) {
      await load();
    }
  }

  /// Clears everything on sign out.
  void reset() {
    _all = <UserModel>[];
    _isLoading = false;
    _error = null;
    _search = '';
    _roleFilter = kFilterAll;
    notifyListeners();
  }

  // ----------------------------------------------------------------- CRUD

  Future<UserModel?> createUser({
    required String username,
    required String email,
    required String password,
    String firstName = '',
    String lastName = '',
    String? phone,
    required String role,
    bool status = true,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final UserModel created = await UserService.createUser(
        username: username,
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        role: role,
        status: status,
      );

      _all = <UserModel>[created, ..._all];

      return created;
    } catch (e) {
      _error = friendlyError(e);

      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<UserModel?> updateUser({
    required int id,
    String? username,
    String? email,
    String? password,
    String? firstName,
    String? lastName,
    String? phone,
    String? role,
    bool? status,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final UserModel updated = await UserService.updateUser(
        id: id,
        username: username,
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        role: role,
        status: status,
      );

      _all =
          _all.map((UserModel u) => u.id == updated.id ? updated : u).toList();

      return updated;
    } catch (e) {
      _error = friendlyError(e);

      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Switch an account on or off.
  Future<bool> setActive(int id, bool active) async {
    return await updateUser(id: id, status: active) != null;
  }

  Future<bool> deleteUser(int id) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await UserService.deleteUser(id);
      _all = _all.where((UserModel u) => u.id != id).toList();

      return true;
    } catch (e) {
      _error = friendlyError(e);

      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
