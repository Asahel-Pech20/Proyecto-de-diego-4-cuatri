import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { pool } from './db.js';

export async function migrate() {
  const sql = await readFile(new URL('./schema.sql', import.meta.url), 'utf8');
  await pool.query(sql);
}

// Permite: npm run db:migrate
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  migrate()
    .then(() => { console.log('Esquema aplicado.'); return pool.end(); })
    .catch((err) => { console.error(err); process.exit(1); });
}
