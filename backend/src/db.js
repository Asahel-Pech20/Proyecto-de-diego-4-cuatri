import pg from 'pg';

// DATE -> 'YYYY-MM-DD' (sin convertir a Date con zona horaria)
pg.types.setTypeParser(1082, (v) => v);
// NUMERIC -> número
pg.types.setTypeParser(1700, (v) => (v === null ? null : Number(v)));
// TIME -> 'HH:MM'
pg.types.setTypeParser(1083, (v) => v.slice(0, 5));

export const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
});
