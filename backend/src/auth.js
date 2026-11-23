import jwt from 'jsonwebtoken';
import { HttpError } from './util.js';

const secret = () => {
  const s = process.env.JWT_SECRET;
  if (!s) throw new Error('Falta JWT_SECRET en .env');
  return s;
};

export function signToken(user) {
  return jwt.sign({ sub: user.id }, secret(), { expiresIn: '30d' });
}

/** Middleware: exige "Authorization: Bearer <token>" y deja req.user = { id }. */
export function requireAuth(req, _res, next) {
  const header = req.get('authorization') ?? '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) return next(new HttpError(401, 'No autenticado'));
  try {
    const payload = jwt.verify(token, secret());
    req.user = { id: payload.sub };
    next();
  } catch {
    next(new HttpError(401, 'Token inválido o expirado'));
  }
}
