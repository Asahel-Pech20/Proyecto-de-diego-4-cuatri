import { Router } from 'express';
import { z } from 'zod';
import { pool } from '../db.js';
import { HttpError, rowToCamel, toSnakeKey } from '../util.js';

const sinceSchema = z.string().datetime({ offset: true });

async function assertOwnSubject(userId, subjectId) {
  const { rowCount } = await pool.query(
    'SELECT 1 FROM subjects WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL',
    [subjectId, userId],
  );
  if (!rowCount) throw new HttpError(404, 'Materia no encontrada');
}

/**
 * CRUD genérico para una tabla del usuario.
 * - table: nombre de la tabla
 * - schema: zod schema del body (campos camelCase)
 * - hasSubject: la tabla tiene subject_id (se valida que la materia sea del usuario)
 * - cascade: tablas hijas que se borran (lógicamente) junto con el registro
 */
export function resourceRouter({ table, schema, hasSubject = true, cascade = [], extend }) {
  const r = Router();
  const partial = schema.omit({ id: true }).partial();

  // Listar. ?subjectId= filtra por materia. ?since= devuelve también los borrados.
  r.get('/', async (req, res) => {
    const params = [req.user.id];
    let sql = `SELECT * FROM ${table} WHERE user_id = $1`;
    if (req.query.since) {
      params.push(sinceSchema.parse(req.query.since));
      sql += ` AND updated_at > $${params.length}`;
    } else {
      sql += ' AND deleted_at IS NULL';
    }
    if (hasSubject && req.query.subjectId) {
      params.push(z.string().uuid().parse(req.query.subjectId));
      sql += ` AND subject_id = $${params.length}`;
    }
    sql += ' ORDER BY created_at';
    const { rows } = await pool.query(sql, params);
    res.json(rows.map(rowToCamel));
  });

  r.get('/:id', async (req, res) => {
    const { rows } = await pool.query(
      `SELECT * FROM ${table} WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
      [z.string().uuid().parse(req.params.id), req.user.id],
    );
    if (!rows.length) throw new HttpError(404, 'No encontrado');
    res.json(rowToCamel(rows[0]));
  });

  r.post('/', async (req, res) => {
    const data = schema.parse(req.body);
    if (hasSubject) await assertOwnSubject(req.user.id, data.subjectId);
    const entries = Object.entries(data).filter(([, v]) => v !== undefined);
    const cols = ['user_id', ...entries.map(([k]) => toSnakeKey(k))];
    const vals = [req.user.id, ...entries.map(([, v]) => v)];
    const ph = vals.map((_, i) => `$${i + 1}`);
    const { rows } = await pool.query(
      `INSERT INTO ${table} (${cols.join(', ')}) VALUES (${ph.join(', ')}) RETURNING *`,
      vals,
    );
    res.status(201).json(rowToCamel(rows[0]));
  });

  r.patch('/:id', async (req, res) => {
    const id = z.string().uuid().parse(req.params.id);
    const data = partial.parse(req.body);
    if (hasSubject && data.subjectId) await assertOwnSubject(req.user.id, data.subjectId);
    const entries = Object.entries(data).filter(([, v]) => v !== undefined);
    const sets = entries.map(([k], i) => `${toSnakeKey(k)} = $${i + 3}`);
    sets.push('updated_at = now()');
    const { rows } = await pool.query(
      `UPDATE ${table} SET ${sets.join(', ')}
       WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL RETURNING *`,
      [id, req.user.id, ...entries.map(([, v]) => v)],
    );
    if (!rows.length) throw new HttpError(404, 'No encontrado');
    res.json(rowToCamel(rows[0]));
  });

  r.delete('/:id', async (req, res) => {
    const id = z.string().uuid().parse(req.params.id);
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const { rowCount } = await client.query(
        `UPDATE ${table} SET deleted_at = now(), updated_at = now()
         WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
        [id, req.user.id],
      );
      if (!rowCount) throw new HttpError(404, 'No encontrado');
      for (const child of cascade) {
        await client.query(
          `UPDATE ${child} SET deleted_at = now(), updated_at = now()
           WHERE subject_id = $1 AND user_id = $2 AND deleted_at IS NULL`,
          [id, req.user.id],
        );
      }
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
    res.status(204).end();
  });

  extend?.(r);
  return r;
}
