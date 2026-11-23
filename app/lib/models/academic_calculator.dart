import 'absence.dart';
import 'grade.dart';
import 'subject_summary.dart';

class AcademicCalculator {
  /// Calcula el resumen de asistencias de forma local según docs/api.md:
  /// - Las faltas justificadas no cuentan para el límite.
  /// - atRisk: quedan 1 o menos faltas (o <= 20% del límite).
  /// - exceeded: las faltas injustificadas superan el límite permitido.
  static AbsenceSummary calculateAbsences({
    required List<Absence> absences,
    int? maxAbsences,
  }) {
    final count = absences.length;
    final justified = absences.where((a) => a.justified).length;
    final unjustified = count - justified;

    if (maxAbsences == null) {
      return AbsenceSummary(
        count: count,
        justified: justified,
        max: null,
        remaining: null,
        atRisk: false,
        exceeded: false,
      );
    }

    final remaining = maxAbsences - unjustified;
    final exceeded = remaining < 0;

    // En riesgo si no ha excedido pero queda 1 o menos faltas, o <= 20% del límite
    final bool atRisk = !exceeded &&
        (remaining <= 1 || (maxAbsences > 0 && (remaining / maxAbsences) <= 0.20));

    return AbsenceSummary(
      count: count,
      justified: justified,
      max: maxAbsences,
      remaining: remaining,
      atRisk: atRisk,
      exceeded: exceeded,
    );
  }

  /// Calcula las calificaciones y el simulador de forma local según docs/api.md:
  /// accumulated = Σ(score * weight / 100)
  /// neededOnPending = (passingGrade - accumulated) * 100 / pendingWeight
  /// status: possible | secured (needed <= 0) | impossible (needed > gradeScale) | approved | failed | no-data
  static GradeSummary calculateGrades({
    required List<Grade> grades,
    required double passingGrade,
    required double gradeScale,
  }) {
    if (grades.isEmpty) {
      return GradeSummary(
        gradeScale: gradeScale,
        passingGrade: passingGrade,
        gradedWeight: 0,
        pendingWeight: 0,
        totalWeight: 0,
        accumulated: 0,
        currentAverage: 0,
        neededOnPending: null,
        status: 'no-data',
      );
    }

    double gradedWeight = 0;
    double pendingWeight = 0;
    double accumulated = 0;

    for (final g in grades) {
      if (g.score != null) {
        gradedWeight += g.weight;
        accumulated += (g.score! * g.weight / 100.0);
      } else {
        pendingWeight += g.weight;
      }
    }

    // Redondear a 4 decimales para evitar problemas de precisión en punto flotante
    accumulated = (accumulated * 10000).round() / 10000;
    final totalWeight = gradedWeight + pendingWeight;

    final currentAverage = gradedWeight > 0
        ? ((accumulated * 100.0 / gradedWeight) * 100).round() / 100.0
        : 0.0;

    double? neededOnPending;
    String status;

    if (pendingWeight <= 0) {
      // Ya no hay evaluaciones pendientes
      neededOnPending = null;
      status = accumulated >= passingGrade ? 'approved' : 'failed';
    } else {
      neededOnPending = ((passingGrade - accumulated) * 100.0 / pendingWeight);
      neededOnPending = (neededOnPending * 10000).round() / 10000;

      if (neededOnPending <= 0) {
        status = 'secured'; // Ya aprobó aunque saque 0 en lo pendiente
      } else if (neededOnPending > gradeScale) {
        status = 'impossible'; // Necesitaría más que la calificación máxima
      } else {
        status = 'possible'; // Puede aprobar sacando neededOnPending
      }
    }

    return GradeSummary(
      gradeScale: gradeScale,
      passingGrade: passingGrade,
      gradedWeight: gradedWeight,
      pendingWeight: pendingWeight,
      totalWeight: totalWeight,
      accumulated: accumulated,
      currentAverage: currentAverage,
      neededOnPending: neededOnPending,
      status: status,
    );
  }

  /// Calcula la calificación final proyectada si en lo pendiente saca [simulatedPendingScore]
  static double simulateProjectedGrade({
    required List<Grade> grades,
    required double simulatedPendingScore,
    required double gradeScale,
  }) {
    double accumulated = 0;
    double pendingWeight = 0;

    for (final g in grades) {
      if (g.score != null) {
        accumulated += (g.score! * g.weight / 100.0);
      } else {
        pendingWeight += g.weight;
      }
    }

    final projected = accumulated + (simulatedPendingScore * pendingWeight / 100.0);
    return (projected * 100).round() / 100.0;
  }
}
