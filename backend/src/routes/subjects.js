import { z } from 'zod';
import { pool } from '../db.js';
import { subjectSchema } from '../schemas.js';
import { HttpError } from '../util.js';
import { resourceRouter } from './resource.js';

const round2 = (n) => (n === null ? null : Math.round(n * 100) / 100);

/** Faltas y simulador de calificación de una materia. */
export function summarize(subject, absences, grades) {
  const counted = absences.filter((a) => !a.justified).length;
  const max = subject.max_absences;
  const remaining = max === null ? null : max - counted;

  const scale = subject.grade_scale;
  const passing = subject.passing_grade;
  const graded = grades.filter((g) => g.score !== null);
  const pending = grades.filter((g) => g.score === null);
  const gradedWeight = graded.reduce((s, g) => s + g.weight, 0);
  const pendingWeight = pending.reduce((s, g) => s + g.weight, 0);
  // Puntos ya ganados sobre la escala final (ej. 6.4 de 10 si ya se evaluó todo eso).
  const accumulated = graded.reduce((s, g) => s + (g.score * g.weight) / 100, 0);
  const currentAverage = gradedWeight ? (accumulated * 100) / gradedWeight : null;

  let neededOnPending = null;
  let status;
  if (pendingWeight === 0) {
    status = gradedWeight === 0 ? 'no-data' : accumulated >= passing ? 'approved' : 'failed';
  } else {
    neededOnPending = ((passing - accumulated) * 100) / pendingWeight;
    status = neededOnPending <= 0 ? 'secured' : neededOnPending > scale ? 'impossible' : 'possible';
    neededOnPending = Math.max(0, neededOnPending);
  }

  return {
    absences: {
      count: counted,
      justified: absences.length - counted,
      max,
      remaining,
      atRisk: max !== null && remaining <= Math.max(1, Math.floor(max * 0.2)),
      exceeded: max !== null && remaining < 0,
    },
    grades: {
      gradeScale: scale,
      passingGrade: passing,
      gradedWeight: round2(gradedWeight),
      pendingWeight: round2(pendingWeight),
      totalWeight: round2(gradedWeight + pendingWeight),
      accumulated: round2(accumulated),
      currentAverage: round2(currentAverage),
      neededOnPending: round2(neededOnPending),
      status,
    },
  };
}

export default resourceRouter({
  table: 'subjects',
  schema: subjectSchema,
  hasSubject: false,
  cascade: ['schedules', 'tasks', 'absences', 'grades'],
  extend(r) {
    r.get('/:id/summary', async (req, res) => {
      const id = z.string().uuid().parse(req.params.id);
      const { rows } = await pool.query(
        'SELECT * FROM subjects WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL',
        [id, req.user.id],
      );
      if (!rows.length) throw new HttpError(404, 'Materia no encontrada');
      const [abs, grades] = await Promise.all([
        pool.query('SELECT justified FROM absences WHERE subject_id = $1 AND deleted_at IS NULL', [id]),
        pool.query('SELECT weight, score FROM grades WHERE subject_id = $1 AND deleted_at IS NULL', [id]),
      ]);
      res.json(summarize(rows[0], abs.rows, grades.rows));
    });
  },
});
