class SubtaskModel {
  final int id;
  final int task;
  final String title;
  final bool isDone;
  final DateTime? createdAt;

  SubtaskModel({
    required this.id,
    required this.task,
    required this.title,
    required this.isDone,
    this.createdAt,
  });

  factory SubtaskModel.fromJson(Map<String, dynamic> json) {
    return SubtaskModel(
      id: json['id'] ?? 0,
      task: json['task'] ?? 0,
      title: json['title'] ?? '',
      isDone: json['is_done'] ?? false,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}
