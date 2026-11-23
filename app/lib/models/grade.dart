class Grade {
  final String id;
  final String subjectId;
  final String name;
  final double weight; // 0 a 100 %
  final double? score; // null = pendiente de presentar
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String syncStatus; // 'synced', 'pending_create', 'pending_update', 'pending_delete'

  Grade({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.weight,
    this.score,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = 'synced',
  });

  bool get isPending => score == null;

  Grade copyWith({
    String? id,
    String? subjectId,
    String? name,
    double? weight,
    double? score,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? syncStatus,
  }) {
    return Grade(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      name: name ?? this.name,
      weight: weight ?? this.weight,
      score: score ?? this.score,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  factory Grade.fromJson(Map<String, dynamic> json, {String syncStatus = 'synced'}) {
    return Grade(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      name: json['name'] as String,
      weight: (json['weight'] as num).toDouble(),
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'] as String) : null,
      syncStatus: syncStatus,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'subjectId': subjectId,
      'name': name,
      'weight': weight,
      'score': score,
    };
    if (includeId) {
      map['id'] = id;
    }
    return map;
  }

  factory Grade.fromDbMap(Map<String, dynamic> map) {
    return Grade(
      id: map['id'] as String,
      subjectId: map['subject_id'] as String,
      name: map['name'] as String,
      weight: (map['weight'] as num).toDouble(),
      score: map['score'] != null ? (map['score'] as num).toDouble() : null,
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
      'name': name,
      'weight': weight,
      'score': score,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }
}
