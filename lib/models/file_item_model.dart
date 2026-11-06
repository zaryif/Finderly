class FileItemModel {
  final String id;
  final String name;
  final String folderId;
  final String localPath;
  final String? cloudUrl;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;
  final bool isDownloaded;

  const FileItemModel({
    required this.id,
    required this.name,
    required this.folderId,
    required this.localPath,
    this.cloudUrl,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
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

  factory FileItemModel.fromMap(Map<String, dynamic> map) => FileItemModel(
        id: map['id'] as String,
        name: map['name'] as String,
        folderId: map['folderId'] as String,
        localPath: map['localPath'] as String,
        cloudUrl: map['cloudUrl'] as String?,
        mimeType: map['mimeType'] as String,
        sizeBytes: map['sizeBytes'] as int,
        createdAt: _parseDateTime(map['createdAt']),
        isDownloaded: (map['isDownloaded'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'folderId': folderId,
        'localPath': localPath,
        'cloudUrl': cloudUrl,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'isDownloaded': isDownloaded ? 1 : 0,
      };

  FileItemModel copyWith({
    String? id,
    String? name,
    String? folderId,
    String? localPath,
    String? cloudUrl,
    String? mimeType,
    int? sizeBytes,
    DateTime? createdAt,
    bool? isDownloaded,
  }) =>
      FileItemModel(
        id: id ?? this.id,
        name: name ?? this.name,
        folderId: folderId ?? this.folderId,
        localPath: localPath ?? this.localPath,
        cloudUrl: cloudUrl ?? this.cloudUrl,
        mimeType: mimeType ?? this.mimeType,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        createdAt: createdAt ?? this.createdAt,
        isDownloaded: isDownloaded ?? this.isDownloaded,
      );

  String get fileExtension {
    final dotIndex = name.lastIndexOf('.');
    return dotIndex == -1 ? '' : name.substring(dotIndex + 1).toLowerCase();
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
