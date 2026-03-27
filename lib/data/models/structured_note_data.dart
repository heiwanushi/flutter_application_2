class StructuredNoteData {
  final String title;
  final String content;
  final List<String> tags;
  final int? colorIndex;
  final DateTime? eventAt;
  final int? reminderMinutes;

  StructuredNoteData({
    required this.title,
    required this.content,
    required this.tags,
    this.colorIndex,
    this.eventAt,
    this.reminderMinutes,
  });

  factory StructuredNoteData.fromJson(Map<String, dynamic> json) {
    return StructuredNoteData(
      title: json['title'] as String? ?? 'Новая заметка',
      content: json['content'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      colorIndex: json['colorIndex'] as int?,
      eventAt: json['eventAt'] != null ? DateTime.tryParse(json['eventAt'] as String) : null,
      reminderMinutes: json['reminderMinutes'] as int?,
    );
  }
}
