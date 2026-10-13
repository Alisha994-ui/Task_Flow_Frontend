class AssistantMessageModel {
  final int id;
  final String role;
  final String text;
  final DateTime? createdAt;

  AssistantMessageModel({
    required this.id,
    required this.role,
    required this.text,
    this.createdAt,
  });

  factory AssistantMessageModel.fromJson(Map<String, dynamic> json) {
    return AssistantMessageModel(
      id: json['id'] ?? 0,
      role: json['role'] ?? 'assistant',
      text: json['text'] ?? '',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }

  /// Local-only, for showing a question the instant it is sent rather
  /// than after the answer comes back.
  factory AssistantMessageModel.pending(String text) {
    return AssistantMessageModel(
      id: -1,
      role: 'user',
      text: text,
      createdAt: DateTime.now(),
    );
  }

  bool get isUser => role == 'user';
}
