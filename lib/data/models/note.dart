class Note {
  /// Считается синхронизированной, если isNoteSynced == true
  final bool isNoteSynced;
  bool get isSynced => isNoteSynced;
  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final List<String> imagePaths;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final int? colorIndex;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    this.imagePaths = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.colorIndex,
    this.isNoteSynced = false,
  });

  Note copyWith({
    String? title,
    String? content,
    List<String>? tags,
    List<String>? imagePaths,
    DateTime? updatedAt,
    bool? isPinned,
    int? colorIndex,
    bool? isNoteSynced,
    bool clearColor = false,
  }) =>
      Note(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        tags: tags ?? this.tags,
        imagePaths: imagePaths ?? this.imagePaths,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isPinned: isPinned ?? this.isPinned,
        colorIndex: clearColor ? null : (colorIndex ?? this.colorIndex),
        isNoteSynced: isNoteSynced ?? this.isNoteSynced,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'tags': tags,
        'imagePaths': imagePaths,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isPinned': isPinned,
        'colorIndex': colorIndex,
        'isNoteSynced': isNoteSynced,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        content: json['content'] as String,
        tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        imagePaths: (json['imagePaths'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        isPinned: json['isPinned'] as bool? ?? false,
        colorIndex: json['colorIndex'] as int?,
        isNoteSynced: (json['isNoteSynced'] is bool)
            ? json['isNoteSynced'] as bool
            : false,
      );
}
