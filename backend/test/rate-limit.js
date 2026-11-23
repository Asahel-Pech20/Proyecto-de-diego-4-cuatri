// Prueba del límite de intentos de login. Levanta su PROPIA instancia de la API en un puerto
// aleatorio con un límite bajo, así no bloquea la API real (puerto 3000) ni la demo.
// Necesita la base de datos levantada (docker compose up -d).
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';
import { pool } from '../src/db.js';

const server = createApp({ loginMax: 3 }).listen(0);
await new Promise((ok) => server.once('listening', ok));
const base = `http://127.0.0.1:${server.address().port}`;

const login = (password) => fetch(`${base}/api/auth/login`, {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ email: 'nadie@utm.test', password }),
});

try {
  for (let i = 1; i <= 3; i++) {
    const r = await login('mala-clave');
    assert.equal(r.status, 401, `intento ${i} debe ser 401`);
  }
  const blocked = await login('mala-clave');
  assert.equal(blocked.status, 429);
  const body = await blocked.json();
  assert.match(body.error, /Demasiados intentos/);
  assert.ok(blocked.headers.get('ratelimit'), 'manda el header RateLimit');
  console.log('✓ login bloqueado (429) después de 3 intentos fallidos');
} finally {
  server.close();
  await pool.end();
}
