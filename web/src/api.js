/**
 * Cliente central del API REST de MiSemestre UTM (Web)
 */

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:3000';

export function getToken() {
  return localStorage.getItem('token');
}

export function setToken(token) {
  if (token) {
    localStorage.setItem('token', token);
  } else {
    localStorage.removeItem('token');
  }
}

export function getCurrentUser() {
  const user = localStorage.getItem('user');
  if (!user) return null;
  try {
    return JSON.parse(user);
  } catch (_) {
    return null;
  }
}

export function setCurrentUser(user) {
  if (user) {
    localStorage.setItem('user', JSON.stringify(user));
  } else {
    localStorage.removeItem('user');
  }
}

export function clearSession() {
  localStorage.removeItem('token');
  localStorage.removeItem('user');
}

/**
 * Petición central para todas las llamadas a la API.
 */
export async function request(method, path, body = null, options = {}) {
  const url = `${API_BASE_URL}${path}`;
  const token = getToken();

  const headers = {
    ...options.headers,
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const isFormData = body instanceof FormData;
  if (!isFormData && body !== null && body !== undefined) {
    headers['Content-Type'] = 'application/json';
  }

  const fetchOptions = {
    method: method.toUpperCase(),
    headers,
    ...options,
  };

  if (body !== null && body !== undefined) {
    fetchOptions.body = isFormData ? body : JSON.stringify(body);
  }

  let res;
  try {
    res = await fetch(url, fetchOptions);
  } catch (err) {
    throw new Error('No se pudo conectar con el servidor. Revisa tu conexión a internet.');
  }

  // Manejo de sesión expirada
  if (res.status === 401) {
    clearSession();
    if (window.location.pathname !== '/login' && window.location.pathname !== '/register') {
      window.location.href = '/login';
    }
    const error = new Error('Sesión expirada o no autorizada. Por favor inicia sesión nuevamente.');
    error.status = 401;
    throw error;
  }

  // Respuesta sin contenido (ej. 204 No Content en DELETE)
  if (res.status === 204) {
    return null;
  }

  let data = null;
  const contentType = res.headers.get('content-type');
  if (contentType && contentType.includes('application/json')) {
    try {
      data = await res.json();
    } catch (_) {
      data = null;
    }
  } else {
    try {
      data = await res.text();
    } catch (_) {
      data = null;
    }
  }

  if (!res.ok) {
    const errorMsg =
      (data && typeof data === 'object' && data.error) ||
      (typeof data === 'string' && data) ||
      `Error en el servidor (${res.status})`;
    const error = new Error(errorMsg);
    error.status = res.status;
    error.data = data;
    throw error;
  }

  return data;
}

// ==========================================
// MÉTODOS DE AUTENTICACIÓN
// ==========================================

export async function login(email, password) {
  const data = await request('POST', '/api/auth/login', { email, password });
  setToken(data.token);
  setCurrentUser(data.user);
  return data;
}

export async function register(name, email, password) {
  const data = await request('POST', '/api/auth/register', { name, email, password });
  setToken(data.token);
  setCurrentUser(data.user);
  return data;
}

export async function getMe() {
  const user = await request('GET', '/api/me');
  setCurrentUser(user);
  return user;
}

export async function deleteAccount() {
  await request('DELETE', '/api/me');
  clearSession();
}

// ==========================================
// MÉTODOS DE MATERIAS (SUBJECTS)
// ==========================================

export async function getSubjects() {
  return await request('GET', '/api/subjects');
}

export async function getSubject(id) {
  return await request('GET', `/api/subjects/${id}`);
}

export async function createSubject(subjectData) {
  return await request('POST', '/api/subjects', subjectData);
}

export async function updateSubject(id, changes) {
  return await request('PATCH', `/api/subjects/${id}`, changes);
}

export async function deleteSubject(id) {
  return await request('DELETE', `/api/subjects/${id}`);
}

export async function getSubjectSummary(id) {
  return await request('GET', `/api/subjects/${id}/summary`);
}

// ==========================================
// MÉTODOS DE HORARIO (SCHEDULES)
// ==========================================

export async function getSchedules(subjectId = null) {
  const path = subjectId ? `/api/schedules?subjectId=${encodeURIComponent(subjectId)}` : '/api/schedules';
  return await request('GET', path);
}

export async function createSchedule(scheduleData) {
  return await request('POST', '/api/schedules', scheduleData);
}

export async function updateSchedule(id, changes) {
  return await request('PATCH', `/api/schedules/${id}`, changes);
}

export async function deleteSchedule(id) {
  return await request('DELETE', `/api/schedules/${id}`);
}

// ==========================================
// MÉTODOS DE TAREAS Y EXÁMENES (TASKS)
// ==========================================

export async function getTasks(subjectId = null) {
  const path = subjectId ? `/api/tasks?subjectId=${encodeURIComponent(subjectId)}` : '/api/tasks';
  return await request('GET', path);
}

export async function createTask(taskData) {
  return await request('POST', '/api/tasks', taskData);
}

export async function updateTask(id, changes) {
  return await request('PATCH', `/api/tasks/${id}`, changes);
}

export async function deleteTask(id) {
  return await request('DELETE', `/api/tasks/${id}`);
}

// ==========================================
// MÉTODOS DE FALTAS (ABSENCES)
// ==========================================

export async function getAbsences(subjectId = null) {
  const path = subjectId ? `/api/absences?subjectId=${encodeURIComponent(subjectId)}` : '/api/absences';
  return await request('GET', path);
}

export async function createAbsence(absenceData) {
  return await request('POST', '/api/absences', absenceData);
}

export async function updateAbsence(id, changes) {
  return await request('PATCH', `/api/absences/${id}`, changes);
}

export async function deleteAbsence(id) {
  return await request('DELETE', `/api/absences/${id}`);
}

// ==========================================
// MÉTODOS DE CALIFICACIONES (GRADES)
// ==========================================

export async function getGrades(subjectId = null) {
  const path = subjectId ? `/api/grades?subjectId=${encodeURIComponent(subjectId)}` : '/api/grades';
  return await request('GET', path);
}

export async function createGrade(gradeData) {
  return await request('POST', '/api/grades', gradeData);
}

export async function updateGrade(id, changes) {
  return await request('PATCH', `/api/grades/${id}`, changes);
}

export async function deleteGrade(id) {
  return await request('DELETE', `/api/grades/${id}`);
}

// ==========================================
// SUBIDA Y CARGA DE FOTOS
// ==========================================

/**
 * Sube una foto mediante POST /api/uploads con multipart/form-data ('photo').
 */
export async function uploadPhoto(file) {
  const formData = new FormData();
  formData.append('photo', file);
  return await request('POST', '/api/uploads', formData);
}

/**
 * Descarga una imagen privada desde la API usando el header Authorization
 * y devuelve un ObjectURL para su uso en un <img>.
 * IMPORTANTE: Recuerda invocar URL.revokeObjectURL(url) cuando se desmonte el componente.
 */
export async function fetchPhotoBlobUrl(photoPath) {
  if (!photoPath) return null;
  const token = getToken();
  const fullUrl = photoPath.startsWith('http') ? photoPath : `${API_BASE_URL}${photoPath}`;

  const res = await fetch(fullUrl, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });

  if (!res.ok) {
    throw new Error(`Error al cargar imagen (${res.status})`);
  }

  const blob = await res.blob();
  return URL.createObjectURL(blob);
}
