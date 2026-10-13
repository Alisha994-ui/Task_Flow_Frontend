class UserModel {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String? phone;
  final String? profileImage;
  final bool status;

  UserModel({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.phone,
    this.profileImage,
    required this.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      phone: json['phone'],
      profileImage: json['profile_image'],
      status: json['status'] ?? false,
    );
  }

  String get fullName {
    final name = '$firstName $lastName'.trim();

    if (name.isEmpty) {
      return username;
    }

    return name;
  }

  bool get isAdmin => role == 'ADMIN';

  bool get isProjectManager => role == 'PROJECT_MANAGER';

  bool get isTeamLead => role == 'TEAM_LEAD';

  bool get isEmployee => role == 'EMPLOYEE';

  bool get isViewer => role == 'VIEWER';
}