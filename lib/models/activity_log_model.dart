class ActivityLogModel {
  final int id;
  final int task;
  final int? user;
  final String userName;
  final String action;
  final String description;
  final DateTime? createdAt;

  ActivityLogModel({
    required this.id,
    required this.task,
    this.user,
    required this.userName,
    required this.action,
    required this.description,
    this.createdAt,
  });

  factory ActivityLogModel.fromJson(Map<String, dynamic> json) {
    return ActivityLogModel(
      id: json['id'] ?? 0,
      task: json['task'] ?? 0,
      user: json['user'],
      userName: json['user_name'] ?? '',
      action: json['action'] ?? '',
      description: json['description'] ?? '',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}
