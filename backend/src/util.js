export class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const toCamelKey = (k) => k.replace(/_([a-z])/g, (_, c) => c.toUpperCase());
export const toSnakeKey = (k) => k.replace(/[A-Z]/g, (c) => `_${c.toLowerCase()}`);

/** Convierte una fila de Postgres a JSON camelCase y quita user_id. */
export function rowToCamel(row) {
  const out = {};
  for (const [k, v] of Object.entries(row)) {
    if (k === 'user_id' || k === 'password_hash') continue;
    out[toCamelKey(k)] = v;
  }
  return out;
}
