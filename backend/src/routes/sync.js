import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db.js';
import { rowToCamel } from '../util.js';

const TABLES = ['subjects', 'schedules', 'tasks', 'absences', 'grades'];

const r = Router();

/**
 * GET /api/sync?since=ISO
 * Devuelve todo lo que cambió desde `since` (incluye borrados con deletedAt).
 * Sin `since`: todo lo vigente. Guardar `serverTime` y mandarlo como `since` la próxima vez.
 */
r.get('/', async (req, res) => {
  const since = req.query.since
    ? z.string().datetime({ offset: true }).parse(req.query.since)
    : null;
  const { rows: [{ now }] } = await pool.query('SELECT now()');
  const out = { serverTime: now.toISOString() };
  await Promise.all(
    TABLES.map(async (t) => {
      const { rows } = since
        ? await pool.query(
            `SELECT * FROM ${t} WHERE user_id = $1 AND updated_at > $2 AND updated_at <= $3 ORDER BY updated_at`,
            [req.user.id, since, now],
          )
        : await pool.query(
            `SELECT * FROM ${t} WHERE user_id = $1 AND deleted_at IS NULL AND updated_at <= $2 ORDER BY updated_at`,
            [req.user.id, now],
          );
      out[t] = rows.map(rowToCamel);
    }),
  );
  res.json(out);
});

export default r;
