import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { pool } from '../db.js';
import { signToken } from '../auth.js';
import { registerSchema, loginSchema } from '../schemas.js';
import { HttpError, rowToCamel } from '../util.js';

const r = Router();

r.post('/register', async (req, res) => {
  const { name, email, password } = registerSchema.parse(req.body);
  const hash = await bcrypt.hash(password, 10);
  const { rows } = await pool.query(
    'INSERT INTO users (name, email, password_hash) VALUES ($1, $2, $3) RETURNING *',
    [name, email, hash],
  ).catch((err) => {
    if (err.code === '23505') throw new HttpError(409, 'Ese correo ya está registrado');
    throw err;
  });
  const user = rows[0];
  res.status(201).json({ token: signToken(user), user: rowToCamel(user) });
});

r.post('/login', async (req, res) => {
  const { email, password } = loginSchema.parse(req.body);
  const { rows } = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
  const user = rows[0];
  if (!user || !(await bcrypt.compare(password, user.password_hash))) {
    throw new HttpError(401, 'Correo o contraseña incorrectos');
  }
  res.json({ token: signToken(user), user: rowToCamel(user) });
});

export default r;
