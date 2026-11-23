// Prueba de humo: recorre el flujo principal contra la API corriendo.
// Uso: npm run dev (en otra terminal) y luego npm test
import assert from 'node:assert/strict';

const BASE = process.env.API_URL ?? `http://localhost:${process.env.PORT ?? 3000}`;
let token;

async function call(method, path, body, { raw } = {}) {
  const headers = token ? { authorization: `Bearer ${token}` } : {};
  let payload;
  if (raw) payload = raw;
  else if (body !== undefined) {
    headers['content-type'] = 'application/json';
    payload = JSON.stringify(body);
  }
  const res = await fetch(BASE + path, { method, headers, body: payload });
  const text = await res.text();
  const data = text && res.headers.get('content-type')?.includes('json') ? JSON.parse(text) : text;
  return { status: res.status, data };
}

const step = (msg) => console.log(`✓ ${msg}`);

const email = `prueba-${Date.now()}@utm.test`;
let r = await call('POST', '/api/auth/register', { name: 'Prueba', email, password: 'secreto123' });
assert.equal(r.status, 201, JSON.stringify(r.data));
token = r.data.token;
step('registro');

r = await call('POST', '/api/auth/login', { email, password: 'mala-clave' });
assert.equal(r.status, 401);
r = await call('POST', '/api/auth/login', { email, password: 'secreto123' });
assert.equal(r.status, 200);
step('login');

const syncStart = (await call('GET', '/api/sync')).data.serverTime;

r = await call('POST', '/api/subjects', { name: 'Programación móvil', maxAbsences: 5, color: '#3366ff' });
assert.equal(r.status, 201, JSON.stringify(r.data));
const subject = r.data;
assert.equal(subject.passingGrade, 8);
step('materia creada');

r = await call('POST', '/api/schedules', { subjectId: subject.id, dayOfWeek: 1, startTime: '07:00', endTime: '08:40', room: 'L3' });
assert.equal(r.status, 201, JSON.stringify(r.data));
assert.equal(r.data.startTime, '07:00');
step('horario');

const clientId = crypto.randomUUID();
r = await call('POST', '/api/tasks', {
  id: clientId, subjectId: subject.id, title: 'Práctica 1', dueAt: new Date(Date.now() + 86400000).toISOString(),
});
assert.equal(r.status, 201, JSON.stringify(r.data));
assert.equal(r.data.id, clientId);
assert.deepEqual(r.data.reminders, [1440, 120]);
r = await call('PATCH', `/api/tasks/${clientId}`, { done: true });
assert.equal(r.data.done, true);
step('tarea con id del cliente + marcar hecha');

const form = new FormData();
form.append('photo', new Blob([Buffer.from('89504e470d0a1a0a', 'hex')], { type: 'image/png' }), 'p.png');
r = await call('POST', '/api/uploads', undefined, { raw: form });
assert.equal(r.status, 201, JSON.stringify(r.data));
r = await call('GET', r.data.url);
assert.equal(r.status, 200);
step('subir y leer foto');

for (const date of ['2026-09-01', '2026-09-03', '2026-09-08', '2026-09-10']) {
  await call('POST', '/api/absences', { subjectId: subject.id, date });
}
await call('POST', '/api/grades', { subjectId: subject.id, name: 'Parcial 1', weight: 30, score: 7 });
await call('POST', '/api/grades', { subjectId: subject.id, name: 'Parcial 2', weight: 30, score: 8 });
await call('POST', '/api/grades', { subjectId: subject.id, name: 'Final', weight: 40 });
r = await call('GET', `/api/subjects/${subject.id}/summary`);
assert.equal(r.status, 200);
assert.equal(r.data.absences.count, 4);
assert.equal(r.data.absences.atRisk, true);
assert.equal(r.data.grades.accumulated, 4.5);
assert.equal(r.data.grades.neededOnPending, 8.75);
assert.equal(r.data.grades.status, 'possible');
step('faltas y simulador (necesita 8.75 en el final)');

r = await call('POST', '/api/tasks', { subjectId: subject.id, title: '' , dueAt: 'mañana' });
assert.equal(r.status, 400);
step('validación');

r = await call('DELETE', `/api/subjects/${subject.id}`);
assert.equal(r.status, 204);
r = await call('GET', '/api/tasks');
assert.equal(r.data.length, 0);
r = await call('GET', `/api/sync?since=${encodeURIComponent(syncStart)}`);
assert.ok(r.data.tasks.every((t) => t.deletedAt), 'sync devuelve borrados');
step('borrado en cascada + sync');

const otherToken = token;
r = await call('POST', '/api/auth/register', { name: 'Otro', email: `otro-${Date.now()}@utm.test`, password: 'secreto123' });
token = r.data.token;
r = await call('GET', `/api/tasks/${clientId}`);
assert.equal(r.status, 404);
step('aislamiento entre usuarios');
await call('DELETE', '/api/me');

token = otherToken;
r = await call('DELETE', '/api/me');
assert.equal(r.status, 204);
r = await call('GET', '/api/me');
assert.equal(r.status, 404);
step('borrar cuenta');

console.log('\nTodo bien.');
