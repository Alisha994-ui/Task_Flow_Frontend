class CommentModel {
  final int id;
  final int task;
  final int? user;
  final String userName;
  final String text;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CommentModel({
    required this.id,
    required this.task,
    this.user,
    required this.userName,
    required this.text,
    this.createdAt,
    this.updatedAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] ?? 0,
      task: json['task'] ?? 0,
      user: json['user'],
      userName: json['user_name'] ?? '',
      text: json['text'] ?? '',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'].toString()),
    );
  }
}
