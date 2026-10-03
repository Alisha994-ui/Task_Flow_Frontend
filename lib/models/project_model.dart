class ProjectModel {
  final int id;
  final String name;
  final String description;
  final DateTime? startDate;
  final DateTime? endDate;
  final String priority;
  final String status;
  final int progress;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? manager;
  final int? team;

  ProjectModel({
    required this.id,
    required this.name,
    required this.description,
    this.startDate,
    this.endDate,
    required this.priority,
    required this.status,
    required this.progress,
    required this.isArchived,
    this.createdAt,
    this.updatedAt,
    this.manager,
    this.team,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      priority: json['priority'] ?? 'MEDIUM',
      status: json['status'] ?? 'PLANNING',
      progress: json['progress'] ?? 0,
      isArchived: json['is_archived'] ?? false,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      manager: json['manager'],
      team: json['team'],
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}