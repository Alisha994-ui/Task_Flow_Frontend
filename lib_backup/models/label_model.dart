class LabelModel {
  final int id;
  final String name;

  LabelModel({required this.id, required this.name});

  factory LabelModel.fromJson(Map<String, dynamic> json) {
    return LabelModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}
