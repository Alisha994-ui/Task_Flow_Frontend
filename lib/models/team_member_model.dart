class TeamMemberModel {
  final int id;
  final int team;
  final int user;
  final String userName;
  final DateTime? joinedAt;

  TeamMemberModel({
    required this.id,
    required this.team,
    required this.user,
    required this.userName,
    this.joinedAt,
  });

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    return TeamMemberModel(
      id: json['id'] ?? 0,
      team: json['team'] ?? 0,
      user: json['user'] ?? 0,
      userName: json['user_name'] ?? '',
      joinedAt: json['joined_at'] == null
          ? null
          : DateTime.tryParse(json['joined_at'].toString()),
    );
  }
}
