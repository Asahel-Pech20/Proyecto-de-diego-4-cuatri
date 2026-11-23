// Crea (o reinicia) la cuenta de demo con datos realistas para la presentación.
// Uso: npm run seed:demo        (con la base levantada: docker compose up -d)
//
// Lo que deja listo, pensado para el guion de la demo:
// - 5 materias con su horario de lunes a viernes (para "¿qué clase sigue?").
// - Programación Móvil: límite de 5 faltas con 3 registradas → al marcar "Falta de hoy"
//   quedan 4 y salta el aviso "Te queda 1 falta".
// - Programación Móvil: Parcial 1 = 7 (30 %), Parcial 2 = 8 (30 %), Final pendiente (40 %)
//   → el simulador dice "Necesitas 8.75".
// - Tareas y un examen en los próximos días, con fechas calculadas desde hoy.
//
// Se puede correr las veces que haga falta (por ejemplo, para dejar la cuenta limpia
// después de un ensayo). Si la cuenta ya existe, conserva el MISMO usuario (la sesión del
// teléfono sigue sirviendo) y marca sus datos anteriores como borrados, así que el teléfono
// los quita solo con sincronizar. No toca ninguna otra cuenta.
import bcrypt from 'bcryptjs';
import { pool } from '../src/db.js';
import { migrate } from '../src/migrate.js';
import { deleteUserUploads } from '../src/routes/uploads.js';

const EMAIL = process.env.DEMO_EMAIL ?? 'demo@utm.test';
const PASSWORD = process.env.DEMO_PASSWORD ?? 'demo1234';
const NAME = process.env.DEMO_NAME ?? 'Estudiante Demo';

// Fechas en hora LOCAL de la computadora.
const pad = (n) => String(n).padStart(2, '0');
const localDate = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
// n días HÁBILES a partir de hoy (se salta sábado y domingo).
const daysFromToday = (n, h = 23, m = 59) => {
  const d = new Date();
  let left = n;
  while (left > 0) {
    d.setDate(d.getDate() + 1);
    if (d.getDay() !== 0 && d.getDay() !== 6) left -= 1;
  }
  d.setHours(h, m, 0, 0);
  return d;
};
// Fecha de una falta pasada que no caiga en sábado ni domingo.
const pastWeekday = (weeksAgo, dow) => {
  const d = new Date();
  d.setDate(d.getDate() - 7 * weeksAgo - ((d.getDay() + 7 - dow) % 7 || 7));
  return localDate(d);
};

const SUBJECTS = [
  { key: 'movil', name: 'Programación Móvil', color: '#7A1C2E', maxAbsences: 5 },
  { key: 'bd', name: 'Base de Datos', color: '#1F6FB2', maxAbsences: 6 },
  { key: 'ingles', name: 'Inglés IV', color: '#2E8B57', maxAbsences: 4 },
  { key: 'mate', name: 'Matemáticas para TI', color: '#C77700', maxAbsences: 5 },
  { key: 'redes', name: 'Redes de Computadoras', color: '#6B4FBB', maxAbsences: 5 },
];

// [materia, día (1 = lunes), inicio, fin, salón]
const SCHEDULE = [
  ['movil', 1, '07:00', '08:40', 'Lab C'], ['bd', 1, '08:40', '10:20', 'Lab B'], ['ingles', 1, '10:40', '12:20', 'Aula 12'],
  ['mate', 2, '07:00', '08:40', 'Aula 8'], ['redes', 2, '08:40', '10:20', 'Lab Redes'], ['movil', 2, '10:40', '12:20', 'Lab C'],
  ['bd', 3, '07:00', '08:40', 'Lab B'], ['ingles', 3, '08:40', '10:20', 'Aula 12'], ['redes', 3, '10:40', '12:20', 'Lab Redes'],
  ['movil', 4, '07:00', '08:40', 'Lab C'], ['mate', 4, '08:40', '10:20', 'Aula 8'], ['bd', 4, '10:40', '12:20', 'Lab B'],
  ['redes', 5, '07:00', '08:40', 'Lab Redes'], ['mate', 5, '08:40', '10:20', 'Aula 8'], ['ingles', 5, '10:40', '12:20', 'Aula 12'],
];

const TASKS = [
  { s: 'bd', kind: 'task', title: 'Diagrama entidad-relación del proyecto', due: daysFromToday(1, 23, 59), reminders: [1440, 120] },
  { s: 'movil', kind: 'exam', title: 'Examen final: Flutter y consumo de API', due: daysFromToday(3, 10, 40), reminders: [2880, 1440] },
  { s: 'ingles', kind: 'task', title: 'Essay: my future job (250 words)', due: daysFromToday(2, 22, 0), reminders: [1440] },
  { s: 'redes', kind: 'task', title: 'Práctica de subneteo en Packet Tracer', due: daysFromToday(5, 23, 59), reminders: [1440, 120] },
  { s: 'mate', kind: 'exam', title: 'Segundo parcial: matrices', due: daysFromToday(6, 8, 40), reminders: [1440, 120] },
];

// Programación Móvil: 3 faltas de 5, en lunes, martes y jueves de semanas pasadas (días con clase).
const ABSENCES = [
  { s: 'movil', date: pastWeekday(1, 4) },
  { s: 'movil', date: pastWeekday(2, 2) },
  { s: 'movil', date: pastWeekday(3, 1) },
  { s: 'ingles', date: pastWeekday(1, 3), justified: true, note: 'Cita médica' },
];

const GRADES = [
  { s: 'movil', name: 'Parcial 1', weight: 30, score: 7 },
  { s: 'movil', name: 'Parcial 2', weight: 30, score: 8 },
  { s: 'movil', name: 'Proyecto final', weight: 40, score: null },
  { s: 'bd', name: 'Parcial 1', weight: 35, score: 9 },
  { s: 'bd', name: 'Parcial 2', weight: 35, score: null },
  { s: 'bd', name: 'Proyecto', weight: 30, score: null },
];

async function main() {
  await migrate();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const hash = await bcrypt.hash(PASSWORD, 10);
    // Crea el usuario o, si ya existe, conserva su id y actualiza nombre y contraseña.
    const { rows: [user] } = await client.query(
      `INSERT INTO users (name, email, password_hash) VALUES ($1, $2, $3)
       ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name, password_hash = EXCLUDED.password_hash
       RETURNING id`,
      [NAME, EMAIL, hash],
    );
    // Borrado lógico de los datos anteriores: el sync del teléfono recibe deletedAt y los quita.
    for (const table of ['grades', 'absences', 'tasks', 'schedules', 'subjects']) {
      await client.query(
        `UPDATE ${table} SET deleted_at = now(), updated_at = now() WHERE user_id = $1 AND deleted_at IS NULL`,
        [user.id],
      );
    }

    const ids = {};
    for (const s of SUBJECTS) {
      const { rows: [r] } = await client.query(
        'INSERT INTO subjects (user_id, name, color, max_absences) VALUES ($1, $2, $3, $4) RETURNING id',
        [user.id, s.name, s.color, s.maxAbsences],
      );
      ids[s.key] = r.id;
    }
    for (const [s, day, start, end, room] of SCHEDULE) {
      await client.query(
        'INSERT INTO schedules (user_id, subject_id, day_of_week, start_time, end_time, room) VALUES ($1, $2, $3, $4, $5, $6)',
        [user.id, ids[s], day, start, end, room],
      );
    }
    for (const t of TASKS) {
      await client.query(
        'INSERT INTO tasks (user_id, subject_id, kind, title, due_at, reminders) VALUES ($1, $2, $3, $4, $5, $6)',
        [user.id, ids[t.s], t.kind, t.title, t.due, t.reminders],
      );
    }
    for (const a of ABSENCES) {
      await client.query(
        'INSERT INTO absences (user_id, subject_id, date, justified, note) VALUES ($1, $2, $3, $4, $5)',
        [user.id, ids[a.s], a.date, a.justified ?? false, a.note ?? null],
      );
    }
    for (const g of GRADES) {
      await client.query(
        'INSERT INTO grades (user_id, subject_id, name, weight, score) VALUES ($1, $2, $3, $4, $5)',
        [user.id, ids[g.s], g.name, g.weight, g.score],
      );
    }
    await client.query('COMMIT');
    // Las fotos de las tareas anteriores ya no se usan.
    await deleteUserUploads(user.id);

    console.log(`Cuenta de demo lista: ${EMAIL}`);
    console.log(`  ${SUBJECTS.length} materias, ${SCHEDULE.length} clases, ${TASKS.length} tareas/exámenes, ${ABSENCES.length} faltas, ${GRADES.length} calificaciones`);
    console.log('  Programación Móvil: 3 de 5 faltas; simulador → necesita 8.75 en el proyecto final.');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((err) => { console.error(err); process.exit(1); });
