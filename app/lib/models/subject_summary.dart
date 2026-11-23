class SubjectSummary {
  final AbsenceSummary absences;
  final GradeSummary grades;

  SubjectSummary({
    required this.absences,
    required this.grades,
  });

  factory SubjectSummary.fromJson(Map<String, dynamic> json) {
    return SubjectSummary(
      absences: AbsenceSummary.fromJson(json['absences'] as Map<String, dynamic>? ?? {}),
      grades: GradeSummary.fromJson(json['grades'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class AbsenceSummary {
  final int count;
  final int justified;
  final int? max;
  final int? remaining;
  final bool atRisk;
  final bool exceeded;

  AbsenceSummary({
    required this.count,
    required this.justified,
    this.max,
    this.remaining,
    required this.atRisk,
    required this.exceeded,
  });

  factory AbsenceSummary.fromJson(Map<String, dynamic> json) {
    return AbsenceSummary(
      count: (json['count'] as num?)?.toInt() ?? 0,
      justified: (json['justified'] as num?)?.toInt() ?? 0,
      max: (json['max'] as num?)?.toInt(),
      remaining: (json['remaining'] as num?)?.toInt(),
      atRisk: json['atRisk'] as bool? ?? false,
      exceeded: json['exceeded'] as bool? ?? false,
    );
  }
}

class GradeSummary {
  final double gradeScale;
  final double passingGrade;
  final double gradedWeight;
  final double pendingWeight;
  final double totalWeight;
  final double accumulated;
  final double currentAverage;
  final double? neededOnPending;
  final String status; // 'possible', 'secured', 'impossible', 'approved', 'failed', 'no-data'

  GradeSummary({
    required this.gradeScale,
    required this.passingGrade,
    required this.gradedWeight,
    required this.pendingWeight,
    required this.totalWeight,
    required this.accumulated,
    required this.currentAverage,
    this.neededOnPending,
    required this.status,
  });

  factory GradeSummary.fromJson(Map<String, dynamic> json) {
    return GradeSummary(
      gradeScale: (json['gradeScale'] as num?)?.toDouble() ?? 10.0,
      passingGrade: (json['passingGrade'] as num?)?.toDouble() ?? 8.0,
      gradedWeight: (json['gradedWeight'] as num?)?.toDouble() ?? 0.0,
      pendingWeight: (json['pendingWeight'] as num?)?.toDouble() ?? 100.0,
      totalWeight: (json['totalWeight'] as num?)?.toDouble() ?? 100.0,
      accumulated: (json['accumulated'] as num?)?.toDouble() ?? 0.0,
      currentAverage: (json['currentAverage'] as num?)?.toDouble() ?? 0.0,
      neededOnPending: (json['neededOnPending'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'no-data',
    );
  }
}
