class ProjectMemberModel {
  final int id;
  final int project;
  final int user;
  final String userName;
  final DateTime? joinedAt;

  ProjectMemberModel({
    required this.id,
    required this.project,
    required this.user,
    required this.userName,
    this.joinedAt,
  });

  factory ProjectMemberModel.fromJson(Map<String, dynamic> json) {
    return ProjectMemberModel(
      id: json['id'] ?? 0,
      project: json['project'] ?? 0,
      user: json['user'] ?? 0,
      userName: json['user_name'] ?? '',
      joinedAt: json['joined_at'] == null
          ? null
          : DateTime.tryParse(json['joined_at'].toString()),
    );
  }
}