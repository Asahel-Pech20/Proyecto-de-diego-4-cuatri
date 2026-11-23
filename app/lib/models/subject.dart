class Subject {
  final String id;
  final String name;
  final String? teacher;
  final String? color;
  final int? maxAbsences;
  final double passingGrade;
  final double gradeScale;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String syncStatus; // 'synced', 'pending_create', 'pending_update', 'pending_delete'

  Subject({
    required this.id,
    required this.name,
    this.teacher,
    this.color,
    this.maxAbsences,
    this.passingGrade = 8.0,
    this.gradeScale = 10.0,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = 'synced',
  });

  Subject copyWith({
    String? id,
    String? name,
    String? teacher,
    String? color,
    int? maxAbsences,
    double? passingGrade,
    double? gradeScale,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? syncStatus,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      color: color ?? this.color,
      maxAbsences: maxAbsences ?? this.maxAbsences,
      passingGrade: passingGrade ?? this.passingGrade,
      gradeScale: gradeScale ?? this.gradeScale,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  factory Subject.fromJson(Map<String, dynamic> json, {String syncStatus = 'synced'}) {
    return Subject(
      id: json['id'] as String,
      name: json['name'] as String,
      teacher: json['teacher'] as String?,
      color: json['color'] as String?,
      maxAbsences: json['maxAbsences'] != null ? (json['maxAbsences'] as num).toInt() : null,
      passingGrade: json['passingGrade'] != null ? (json['passingGrade'] as num).toDouble() : 8.0,
      gradeScale: json['gradeScale'] != null ? (json['gradeScale'] as num).toDouble() : 10.0,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'] as String) : null,
      syncStatus: syncStatus,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'name': name,
      'teacher': teacher,
      'color': color,
      'maxAbsences': maxAbsences,
      'passingGrade': passingGrade,
      'gradeScale': gradeScale,
    };
    if (includeId) {
      map['id'] = id;
    }
    return map;
  }

  factory Subject.fromDbMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'] as String,
      name: map['name'] as String,
      teacher: map['teacher'] as String?,
      color: map['color'] as String?,
      maxAbsences: map['max_absences'] != null ? (map['max_absences'] as num).toInt() : null,
      passingGrade: map['passing_grade'] != null ? (map['passing_grade'] as num).toDouble() : 8.0,
      gradeScale: map['grade_scale'] != null ? (map['grade_scale'] as num).toDouble() : 10.0,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'] as String) : null,
      deletedAt: map['deleted_at'] != null ? DateTime.tryParse(map['deleted_at'] as String) : null,
      syncStatus: (map['sync_status'] as String?) ?? 'synced',
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'name': name,
      'teacher': teacher,
      'color': color,
      'max_absences': maxAbsences,
      'passing_grade': passingGrade,
      'grade_scale': gradeScale,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }
}
