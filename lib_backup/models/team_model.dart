class TeamModel {
  final int id;
  final List<int> members;
  final String name;
  final String description;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? teamLead;

  TeamModel({
    required this.id,
    required this.members,
    required this.name,
    required this.description,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.teamLead,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    return TeamModel(
      id: json['id'] ?? 0,
      members: List<int>.from(
        json['members'] ?? [],
      ),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      isActive: json['is_active'] ?? false,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(
              json['created_at'].toString(),
            ),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(
              json['updated_at'].toString(),
            ),
      teamLead: json['team_lead'],
    );
  }
}