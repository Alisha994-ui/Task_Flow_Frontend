import '../core/network/api_client.dart';

class AttachmentModel {
  final int id;
  final int task;
  final int? uploadedBy;
  final String uploadedByName;

  /// Whatever the serializer returned - may be a full URL or a path.
  final String file;
  final DateTime? createdAt;

  AttachmentModel({
    required this.id,
    required this.task,
    this.uploadedBy,
    required this.uploadedByName,
    required this.file,
    this.createdAt,
  });

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: json['id'] ?? 0,
      task: json['task'] ?? 0,
      uploadedBy: json['uploaded_by'],
      uploadedByName: json['uploaded_by_name'] ?? '',
      file: json['file']?.toString() ?? '',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }

  /// Openable link, with the server prefix added when Django sent a path.
  String get url => ApiClient.absoluteUrl(file);

  /// `task_attachments/spec_v2.pdf` -> `spec_v2.pdf`
  String get fileName {
    final String clean = file.split('?').first;
    final List<String> parts = clean.split('/');

    if (parts.isEmpty) {
      return 'file';
    }

    final String last = Uri.decodeComponent(parts.last);

    return last.isEmpty ? 'file' : last;
  }

  /// `pdf`, `png`, `docx` ...
  String get extension {
    final String name = fileName;
    final int dot = name.lastIndexOf('.');

    if (dot == -1 || dot == name.length - 1) {
      return '';
    }

    return name.substring(dot + 1).toLowerCase();
  }

  bool get isImage =>
      <String>['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'].contains(extension);
}
