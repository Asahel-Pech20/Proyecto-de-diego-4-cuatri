import { Router } from 'express';
import { pool } from '../db.js';
import { HttpError, rowToCamel } from '../util.js';
import { deleteUserUploads } from './uploads.js';

const r = Router();

r.get('/', async (req, res) => {
  const { rows } = await pool.query('SELECT * FROM users WHERE id = $1', [req.user.id]);
  if (!rows.length) throw new HttpError(404, 'Usuario no encontrado');
  res.json(rowToCamel(rows[0]));
});

// Borra la cuenta y TODA su información (cascada en la base + fotos).
r.delete('/', async (req, res) => {
  await pool.query('DELETE FROM users WHERE id = $1', [req.user.id]);
  await deleteUserUploads(req.user.id);
  res.status(204).end();
});

export default r;
