-- MiSemestre UTM: esquema de base de datos (idempotente).
-- Todas las tablas de datos llevan user_id para que cada consulta filtre por dueño,
-- y deleted_at (borrado lógico) para que la sincronización sin conexión vea los borrados.

CREATE TABLE IF NOT EXISTS users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL,
  email         text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS subjects (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name          text NOT NULL,
  teacher       text,
  color         text,
  max_absences  integer,
  passing_grade numeric(6,2) NOT NULL DEFAULT 8,
  grade_scale   numeric(6,2) NOT NULL DEFAULT 10,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  deleted_at    timestamptz
);

CREATE TABLE IF NOT EXISTS schedules (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id  uuid NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  day_of_week smallint NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
  start_time  time NOT NULL,
  end_time    time NOT NULL,
  room        text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);

CREATE TABLE IF NOT EXISTS tasks (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id  uuid NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  kind        text NOT NULL DEFAULT 'task' CHECK (kind IN ('task', 'exam')),
  title       text NOT NULL,
  description text,
  due_at      timestamptz NOT NULL,
  done        boolean NOT NULL DEFAULT false,
  photo_url   text,
  reminders   integer[] NOT NULL DEFAULT '{1440,120}',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);

CREATE TABLE IF NOT EXISTS absences (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id  uuid NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  date        date NOT NULL,
  justified   boolean NOT NULL DEFAULT false,
  note        text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);

CREATE TABLE IF NOT EXISTS grades (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id  uuid NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  name        text NOT NULL,
  weight      numeric(6,2) NOT NULL CHECK (weight >= 0 AND weight <= 100),
  score       numeric(6,2),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);

CREATE INDEX IF NOT EXISTS subjects_user_updated  ON subjects  (user_id, updated_at);
CREATE INDEX IF NOT EXISTS schedules_user_updated ON schedules (user_id, updated_at);
CREATE INDEX IF NOT EXISTS tasks_user_updated     ON tasks     (user_id, updated_at);
CREATE INDEX IF NOT EXISTS tasks_user_due         ON tasks     (user_id, due_at);
CREATE INDEX IF NOT EXISTS absences_user_updated  ON absences  (user_id, updated_at);
CREATE INDEX IF NOT EXISTS grades_user_updated    ON grades    (user_id, updated_at);
