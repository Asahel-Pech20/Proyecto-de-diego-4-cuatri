import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { ZodError } from 'zod';
import multer from 'multer';
import { rateLimit } from 'express-rate-limit';
import { requireAuth } from './auth.js';
import { HttpError } from './util.js';
import authRoutes from './routes/auth.js';
import meRoutes from './routes/me.js';
import subjectRoutes from './routes/subjects.js';
import syncRoutes from './routes/sync.js';
import uploadRoutes from './routes/uploads.js';
import { resourceRouter } from './routes/resource.js';
import { scheduleSchema, taskSchema, absenceSchema, gradeSchema } from './schemas.js';

/**
 * Límites de intentos en /api/auth (por IP):
 * - login: 10 intentos FALLIDOS cada 15 min (los correctos no cuentan).
 * - registro: 30 cuentas por hora.
 * Configurables con AUTH_LOGIN_MAX / AUTH_REGISTER_MAX o con `opts` (pruebas).
 */
function authLimiters(opts) {
  const loginMax = opts.loginMax ?? Number(process.env.AUTH_LOGIN_MAX ?? 10);
  const registerMax = opts.registerMax ?? Number(process.env.AUTH_REGISTER_MAX ?? 30);
  const common = { standardHeaders: 'draft-8', legacyHeaders: false };
  return {
    login: rateLimit({
      ...common,
      windowMs: 15 * 60 * 1000,
      limit: loginMax,
      skipSuccessfulRequests: true,
      handler: (_req, res) => res.status(429).json({
        error: 'Demasiados intentos fallidos. Espera 15 minutos e inténtalo de nuevo.',
      }),
    }),
    register: rateLimit({
      ...common,
      windowMs: 60 * 60 * 1000,
      limit: registerMax,
      handler: (_req, res) => res.status(429).json({
        error: 'Demasiados registros desde esta red. Inténtalo más tarde.',
      }),
    }),
  };
}

export function createApp(opts = {}) {
  const app = express();
  const limiters = authLimiters(opts);
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  const origins = process.env.CORS_ORIGIN?.split(',').map((s) => s.trim()).filter(Boolean);
  app.use(cors(origins?.length ? { origin: origins } : undefined));
  app.use(express.json({ limit: '1mb' }));

  app.get('/api/health', (_req, res) => res.json({ ok: true }));
  app.use('/api/auth/login', limiters.login);
  app.use('/api/auth/register', limiters.register);
  app.use('/api/auth', authRoutes);

  app.use('/api', requireAuth);
  app.use('/api/me', meRoutes);
  app.use('/api/subjects', subjectRoutes);
  app.use('/api/schedules', resourceRouter({ table: 'schedules', schema: scheduleSchema }));
  app.use('/api/tasks', resourceRouter({ table: 'tasks', schema: taskSchema }));
  app.use('/api/absences', resourceRouter({ table: 'absences', schema: absenceSchema }));
  app.use('/api/grades', resourceRouter({ table: 'grades', schema: gradeSchema }));
  app.use('/api/sync', syncRoutes);
  app.use('/api/uploads', uploadRoutes);

  app.use((_req, _res, next) => next(new HttpError(404, 'Ruta no encontrada')));

  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    if (err instanceof ZodError) {
      return res.status(400).json({ error: 'Datos inválidos', details: err.flatten() });
    }
    if (err instanceof HttpError) return res.status(err.status).json({ error: err.message });
    if (err instanceof multer.MulterError) return res.status(400).json({ error: err.message });
    if (err.type === 'entity.parse.failed') return res.status(400).json({ error: 'JSON inválido' });
    if (err.code === '23505') return res.status(409).json({ error: 'Ya existe un registro con ese id' });
    if (err.code === '22P02' || err.code === '22007' || err.code === '22008') {
      return res.status(400).json({ error: 'Valor con formato inválido' });
    }
    console.error(err);
    res.status(500).json({ error: 'Error interno del servidor' });
  });

  return app;
}
