import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { ZodError } from 'zod';
import multer from 'multer';
import { requireAuth } from './auth.js';
import { HttpError } from './util.js';
import authRoutes from './routes/auth.js';
import meRoutes from './routes/me.js';
import subjectRoutes from './routes/subjects.js';
import syncRoutes from './routes/sync.js';
import uploadRoutes from './routes/uploads.js';
import { resourceRouter } from './routes/resource.js';
import { scheduleSchema, taskSchema, absenceSchema, gradeSchema } from './schemas.js';

export function createApp() {
  const app = express();
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  const origins = process.env.CORS_ORIGIN?.split(',').map((s) => s.trim()).filter(Boolean);
  app.use(cors(origins?.length ? { origin: origins } : undefined));
  app.use(express.json({ limit: '1mb' }));

  app.get('/api/health', (_req, res) => res.json({ ok: true }));
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
