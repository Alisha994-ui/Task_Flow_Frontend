import '../core/network/api_client.dart';
import '../core/network/api_parsing.dart';
import '../models/user_model.dart';

class UserService {
  static const int _maxPages = 10;

  static Future<List<UserModel>> getUsers() async {
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

    for (int page = 1; page <= _maxPages; page++) {
      final dynamic response = await ApiClient.get(
        '/users/${buildQuery(<String, dynamic>{if (page > 1) 'page': page})}',
      );

      rows.addAll(extractResults(response));

      if (nextPageUrl(response) == null) {
        break;
      }
    }

    return rows.map(UserModel.fromJson).toList();
  }

  static Future<UserModel> getUser(int id) async {
    final response = await ApiClient.get('/users/$id/');

    return UserModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// `password` is write-only on the serializer and is hashed there.
  static Future<UserModel> createUser({
    required String username,
    required String email,
    required String password,
    String firstName = '',
    String lastName = '',
    String? phone,
    required String role,
    bool status = true,
  }) async {
    final response = await ApiClient.post(
      '/users/',
      body: <String, dynamic>{
        'username': username,
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'role': role,
        'status': status,
      },
    );

    return UserModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Partial update. Leave [password] null to keep the current one -
  /// the serializer only re-hashes when the field is present.
  static Future<UserModel> updateUser({
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
    final Map<String, dynamic> body = <String, dynamic>{};

    if (username != null) body['username'] = username;
    if (email != null) body['email'] = email;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;
    if (phone != null) body['phone'] = phone;
    if (role != null) body['role'] = role;
    if (status != null) body['status'] = status;

    final response = await ApiClient.patch('/users/$id/', body: body);

    return UserModel.fromJson(Map<String, dynamic>.from(response));
  }

  /// Switches the account off without deleting it - safer than destroy,
  /// because a deleted user takes their tasks and comments with them.
  static Future<UserModel> setActive({
    required int id,
    required bool active,
  }) async {
    return updateUser(id: id, status: active);
  }

  static Future<void> deleteUser(int id) async {
    await ApiClient.delete('/users/$id/');
  }
}
