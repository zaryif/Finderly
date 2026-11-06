import 'package:finderly/theme/folder_colors.dart';

class FolderModel {
  final String id;
  final String name;
  final String? parentId;
  final FolderColor color;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDownloaded;

  const FolderModel({
    required this.id,
    required this.name,
    this.parentId,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    this.isDownloaded = false,
  });

  static DateTime _parseDateTime(dynamic val) {
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) {
      final parsed = DateTime.tryParse(val);
      if (parsed != null) return parsed;
      final asInt = int.tryParse(val);
      if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
    }
    return DateTime.now();
  }

  factory FolderModel.fromMap(Map<String, dynamic> map) => FolderModel(
        id: map['id'] as String,
        name: map['name'] as String,
        parentId: map['parentId'] as String?,
        color: FolderColor.fromName(map['color'] as String),
        createdAt: _parseDateTime(map['createdAt']),
        updatedAt: _parseDateTime(map['updatedAt']),
        isDownloaded: (map['isDownloaded'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'parentId': parentId,
        'color': color.name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'isDownloaded': isDownloaded ? 1 : 0,
      };

  FolderModel copyWith({
    String? id,
    String? name,
    String? parentId,
    FolderColor? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDownloaded,
  }) =>
      FolderModel(
        id: id ?? this.id,
        name: name ?? this.name,
        parentId: parentId ?? this.parentId,
        color: color ?? this.color,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDownloaded: isDownloaded ?? this.isDownloaded,
      );
}
