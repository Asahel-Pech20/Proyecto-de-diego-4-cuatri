import { Router } from 'express';
import multer from 'multer';
import { randomUUID } from 'node:crypto';
import { mkdirSync, existsSync } from 'node:fs';
import { readdir, unlink } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { HttpError } from '../util.js';

export const UPLOAD_DIR = fileURLToPath(new URL('../../uploads/', import.meta.url));
mkdirSync(UPLOAD_DIR, { recursive: true });

const EXT = { 'image/jpeg': '.jpg', 'image/png': '.png', 'image/webp': '.webp', 'image/heic': '.heic' };

const upload = multer({
  storage: multer.diskStorage({
    destination: UPLOAD_DIR,
    // El nombre empieza con el id del usuario: así se comprueba quién es el dueño.
    filename: (req, file, cb) => cb(null, `${req.user.id}-${randomUUID()}${EXT[file.mimetype]}`),
  }),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) =>
    EXT[file.mimetype] ? cb(null, true) : cb(new HttpError(400, 'Solo imágenes JPG, PNG, WEBP o HEIC')),
});

const r = Router();

// multipart/form-data con el campo "photo"
r.post('/', upload.single('photo'), (req, res) => {
  if (!req.file) throw new HttpError(400, 'Falta el archivo "photo"');
  res.status(201).json({ url: `/api/uploads/${req.file.filename}` });
});

r.get('/:file', (req, res) => {
  const file = req.params.file;
  if (file !== path.basename(file) || !file.startsWith(`${req.user.id}-`)) {
    throw new HttpError(404, 'No encontrado');
  }
  const full = path.join(UPLOAD_DIR, file);
  if (!existsSync(full)) throw new HttpError(404, 'No encontrado');
  res.sendFile(full);
});

export async function deleteUserUploads(userId) {
  const files = await readdir(UPLOAD_DIR);
  await Promise.all(
    files.filter((f) => f.startsWith(`${userId}-`)).map((f) => unlink(path.join(UPLOAD_DIR, f))),
  );
}

export default r;
