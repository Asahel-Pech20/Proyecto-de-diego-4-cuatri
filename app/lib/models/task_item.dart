import 'dart:convert';

class TaskItem {
  final String id;
  final String subjectId;
  final String kind; // "task" | "exam"
  final String title;
  final String? description;
  final DateTime dueAt;
  final bool done;
  final String? photoUrl;
  final String? localPhotoPath;
  final List<int> reminders; // En minutos antes de dueAt (ej. [1440, 120])
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String syncStatus; // 'synced', 'pending_create', 'pending_update', 'pending_delete'

  TaskItem({
    required this.id,
    required this.subjectId,
    this.kind = 'task',
    required this.title,
    this.description,
    required this.dueAt,
    this.done = false,
    this.photoUrl,
    this.localPhotoPath,
    this.reminders = const [1440, 120],
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = 'synced',
  });

  bool get isExam => kind == 'exam';

  TaskItem copyWith({
    String? id,
    String? subjectId,
    String? kind,
    String? title,
    String? description,
    DateTime? dueAt,
    bool? done,
    String? photoUrl,
    String? localPhotoPath,
    bool clearLocalPhotoPath = false,
    List<int>? reminders,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? syncStatus,
  }) {
    return TaskItem(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      description: description ?? this.description,
      dueAt: dueAt ?? this.dueAt,
      done: done ?? this.done,
      photoUrl: photoUrl ?? this.photoUrl,
      localPhotoPath: clearLocalPhotoPath ? null : (localPhotoPath ?? this.localPhotoPath),
      reminders: reminders ?? this.reminders,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  factory TaskItem.fromJson(Map<String, dynamic> json, {String syncStatus = 'synced', String? localPhotoPath}) {
    List<int> parseReminders(dynamic val) {
      if (val is List) {
        return val.map((e) => (e as num).toInt()).toList();
      }
      return [1440, 120];
    }

    return TaskItem(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      kind: (json['kind'] as String?) ?? 'task',
      title: json['title'] as String,
      description: json['description'] as String?,
      dueAt: DateTime.parse(json['dueAt'] as String),
      done: json['done'] as bool? ?? false,
      photoUrl: json['photoUrl'] as String?,
      localPhotoPath: localPhotoPath,
      reminders: parseReminders(json['reminders']),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'] as String) : null,
      syncStatus: syncStatus,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'subjectId': subjectId,
      'kind': kind,
      'title': title,
      'description': description,
      'dueAt': dueAt.toUtc().toIso8601String(),
      'done': done,
      'photoUrl': photoUrl,
      'reminders': reminders,
    };
    if (includeId) {
      map['id'] = id;
    }
    return map;
  }

  factory TaskItem.fromDbMap(Map<String, dynamic> map) {
    List<int> parseReminders(dynamic val) {
      if (val == null) return [1440, 120];
      try {
        final decoded = jsonDecode(val.toString());
        if (decoded is List) {
          return decoded.map((e) => (e as num).toInt()).toList();
        }
      } catch (_) {}
      return [1440, 120];
    }

    return TaskItem(
      id: map['id'] as String,
      subjectId: map['subject_id'] as String,
      kind: (map['kind'] as String?) ?? 'task',
      title: map['title'] as String,
      description: map['description'] as String?,
      dueAt: DateTime.parse(map['due_at'] as String),
      done: (map['done'] as int?) == 1,
      photoUrl: map['photo_url'] as String?,
      localPhotoPath: map['local_photo_path'] as String?,
      reminders: parseReminders(map['reminders']),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'] as String) : null,
      deletedAt: map['deleted_at'] != null ? DateTime.tryParse(map['deleted_at'] as String) : null,
      syncStatus: (map['sync_status'] as String?) ?? 'synced',
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'subject_id': subjectId,
      'kind': kind,
      'title': title,
      'description': description,
      'due_at': dueAt.toUtc().toIso8601String(),
      'done': done ? 1 : 0,
      'photo_url': photoUrl,
      'local_photo_path': localPhotoPath,
      'reminders': jsonEncode(reminders),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }
}
