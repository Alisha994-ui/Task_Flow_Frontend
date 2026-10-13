import '../core/network/api_client.dart';

class ProjectMessageModel {
  final int id;
  final int project;
  final int? user;
  final String userName;
  final String userFullName;
  final String text;

  /// Empty when the message is text only.
  final String file;
  final DateTime? createdAt;

  ProjectMessageModel({
    required this.id,
    required this.project,
    this.user,
    required this.userName,
    required this.userFullName,
    required this.text,
    required this.file,
    this.createdAt,
  });

  factory ProjectMessageModel.fromJson(Map<String, dynamic> json) {
    return ProjectMessageModel(
      id: json['id'] ?? 0,
      project: json['project'] ?? 0,
      user: json['user'],
      userName: json['user_name'] ?? '',
      userFullName: json['user_full_name'] ?? json['user_name'] ?? '',
      text: json['text'] ?? '',
      file: json['file']?.toString() ?? '',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }

  bool get hasFile => file.isNotEmpty;

  String get url => ApiClient.absoluteUrl(file);

  String get fileName {
    final List<String> parts = file.split('?').first.split('/');

    if (parts.isEmpty) {
      return 'file';
    }

    final String last = Uri.decodeComponent(parts.last);

    return last.isEmpty ? 'file' : last;
  }

  bool get isImage {
    final String name = fileName.toLowerCase();

    return name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.gif') ||
        name.endsWith('.webp');
  }
}
