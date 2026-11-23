import { z } from 'zod';

const id = z.string().uuid();
const optText = (max) => z.string().trim().max(max).nullable().optional();
const hhmm = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Formato HH:MM');

export const registerSchema = z.object({
  name: z.string().trim().min(1).max(100),
  email: z.string().trim().toLowerCase().email().max(200),
  password: z.string().min(8).max(200),
});

export const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(1),
});

export const subjectSchema = z.object({
  id: id.optional(),
  name: z.string().trim().min(1).max(100),
  teacher: optText(100),
  color: z.string().regex(/^#[0-9a-fA-F]{6}$/, 'Color #RRGGBB').nullable().optional(),
  maxAbsences: z.number().int().min(0).nullable().optional(),
  passingGrade: z.number().min(0).max(100).optional(),
  gradeScale: z.number().positive().max(100).optional(),
});

export const scheduleSchema = z.object({
  id: id.optional(),
  subjectId: id,
  dayOfWeek: z.number().int().min(1).max(7),
  startTime: hhmm,
  endTime: hhmm,
  room: optText(50),
});

export const taskSchema = z.object({
  id: id.optional(),
  subjectId: id,
  kind: z.enum(['task', 'exam']).optional(),
  title: z.string().trim().min(1).max(200),
  description: optText(2000),
  dueAt: z.string().datetime({ offset: true }),
  done: z.boolean().optional(),
  photoUrl: z.string().max(500).nullable().optional(),
  reminders: z.array(z.number().int().min(0).max(60 * 24 * 30)).max(10).optional(),
});

export const absenceSchema = z.object({
  id: id.optional(),
  subjectId: id,
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Formato YYYY-MM-DD'),
  justified: z.boolean().optional(),
  note: optText(500),
});

export const gradeSchema = z.object({
  id: id.optional(),
  subjectId: id,
  name: z.string().trim().min(1).max(100),
  weight: z.number().min(0).max(100),
  score: z.number().min(0).max(100).nullable().optional(),
});
