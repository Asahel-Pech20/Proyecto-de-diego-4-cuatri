class Absence {
  final String id;
  final String subjectId;
  final String date; // "YYYY-MM-DD"
  final bool justified;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String syncStatus; // 'synced', 'pending_create', 'pending_update', 'pending_delete'

  Absence({
    required this.id,
    required this.subjectId,
    required this.date,
    this.justified = false,
    this.note,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = 'synced',
  });

  Absence copyWith({
    String? id,
    String? subjectId,
    String? date,
    bool? justified,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? syncStatus,
  }) {
    return Absence(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      date: date ?? this.date,
      justified: justified ?? this.justified,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  factory Absence.fromJson(Map<String, dynamic> json, {String syncStatus = 'synced'}) {
    return Absence(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      date: json['date'] as String,
      justified: json['justified'] as bool? ?? false,
      note: json['note'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'] as String) : null,
      syncStatus: syncStatus,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'subjectId': subjectId,
      'date': date,
      'justified': justified,
      'note': note,
    };
    if (includeId) {
      map['id'] = id;
    }
    return map;
  }

  factory Absence.fromDbMap(Map<String, dynamic> map) {
    return Absence(
      id: map['id'] as String,
      subjectId: map['subject_id'] as String,
      date: map['date'] as String,
      justified: (map['justified'] as int?) == 1,
      note: map['note'] as String?,
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
      'date': date,
      'justified': justified ? 1 : 0,
      'note': note,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }
}
