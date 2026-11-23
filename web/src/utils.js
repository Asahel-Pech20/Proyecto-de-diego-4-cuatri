/**
 * Utilidades de fecha, hora, conversiones y cálculo académico para MiSemestre UTM (Web)
 */

/**
 * Convierte el día de JavaScript (Date.getDay(): 0=Dom, 1=Lun, ..., 6=Sáb)
 * al día de la API (1=Lun, 2=Mar, ..., 6=Sáb, 7=Dom).
 */
export function jsDayToApiDay(jsDay) {
  return jsDay === 0 ? 7 : jsDay;
}

/**
 * Convierte el día de la API (1=Lun ... 7=Dom) al día de JavaScript (0=Dom, 1=Lun ... 6=Sáb).
 */
export function apiDayToJsDay(apiDay) {
  return apiDay === 7 ? 0 : apiDay;
}

/**
 * Devuelve el nombre del día en español según el día de la API (1=Lunes ... 7=Domingo).
 */
export function getDayName(apiDay, short = false) {
  const days = {
    1: short ? 'Lun' : 'Lunes',
    2: short ? 'Mar' : 'Martes',
    3: short ? 'Mié' : 'Miércoles',
    4: short ? 'Jue' : 'Jueves',
    5: short ? 'Vie' : 'Viernes',
    6: short ? 'Sáb' : 'Sábado',
    7: short ? 'Dom' : 'Domingo',
  };
  return days[apiDay] || '';
}

/**
 * Convierte el valor de <input type="datetime-local"> ("YYYY-MM-DDTHH:mm")
 * a formato ISO con zona horaria UTC (ej. "2026-11-20T14:30:00.000Z").
 */
export function datetimeLocalToIso(val) {
  if (!val) return null;
  const d = new Date(val);
  return isNaN(d.getTime()) ? null : d.toISOString();
}

/**
 * Convierte una fecha ISO (ej. "2026-11-20T20:30:00.000Z") a formato local
 * "YYYY-MM-DDTHH:mm" para usar como valor en <input type="datetime-local">.
 */
export function isoToDatetimeLocal(isoStr) {
  if (!isoStr) return '';
  const d = new Date(isoStr);
  if (isNaN(d.getTime())) return '';
  const pad = (n) => String(n).padStart(2, '0');
  const year = d.getFullYear();
  const month = pad(d.getMonth() + 1);
  const day = pad(d.getDate());
  const hours = pad(d.getHours());
  const minutes = pad(d.getMinutes());
  return `${year}-${month}-${day}T${hours}:${minutes}`;
}

/**
 * Convierte "HH:MM" a minutos transcurridos desde medianoche.
 */
export function timeToMinutes(timeStr) {
  if (!timeStr) return 0;
  const [h, m] = timeStr.split(':').map((x) => parseInt(x, 10));
  return (h || 0) * 60 + (m || 0);
}

/**
 * Formatea minutos a formato "HH:MM".
 */
export function minutesToTime(mins) {
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

/**
 * Formatea una fecha ISO en hora local amigable en español.
 */
export function formatDisplayDateTime(isoStr) {
  if (!isoStr) return '';
  const d = new Date(isoStr);
  if (isNaN(d.getTime())) return '';
  return d.toLocaleString('es-MX', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
}

/**
 * Convierte un objeto Date o fecha a string local en formato "YYYY-MM-DD".
 * Usa la hora local del dispositivo (getFullYear, getMonth, getDate),
 * evitando el desfase de zona horaria que causa toISOString() al atardecer/noche.
 * @param {Date|string|number} [date=new Date()]
 * @returns {string} Fecha en formato "YYYY-MM-DD"
 */
export function localDateString(date = new Date()) {
  const d = date instanceof Date ? date : new Date(date);
  if (isNaN(d.getTime())) return '';
  const pad = (n) => String(n).padStart(2, '0');
  const year = d.getFullYear();
  const month = pad(d.getMonth() + 1);
  const day = pad(d.getDate());
  return `${year}-${month}-${day}`;
}

/**
 * Formatea una fecha ("YYYY-MM-DD", ISO o instancia de Date) a "DD/MM/YYYY".
 * Soporta tanto strings como instancias Date de JavaScript.
 * @param {string|Date} dateVal
 * @returns {string} Fecha formateada "DD/MM/YYYY"
 */
export function formatDisplayDate(dateVal) {
  if (!dateVal) return '';
  if (dateVal instanceof Date) {
    if (isNaN(dateVal.getTime())) return '';
    const pad = (n) => String(n).padStart(2, '0');
    return `${pad(dateVal.getDate())}/${pad(dateVal.getMonth() + 1)}/${dateVal.getFullYear()}`;
  }
  const str = String(dateVal);
  const dateOnly = str.split('T')[0];
  const parts = dateOnly.split('-');
  if (parts.length === 3) {
    return `${parts[2]}/${parts[1]}/${parts[0]}`;
  }
  return str;
}

/**
 * Calcula la clase actual y la siguiente según el horario y un instante dado.
 * @param {Array} schedules - Lista de horarios de materias
 * @param {Date} [now] - Fecha y hora de referencia (por defecto Date actual)
 * @returns {{ currentClass: Object|null, nextClass: Object|null }}
 */
export function calculateCurrentAndNextClass(schedules, now = new Date()) {
  if (!schedules || schedules.length === 0) {
    return { currentClass: null, nextClass: null };
  }

  const currentApiDay = jsDayToApiDay(now.getDay());
  const currentMinutes = now.getHours() * 60 + now.getMinutes();

  // Filtrar clases de hoy ordenadas por hora de inicio
  const todayClasses = schedules
    .filter((s) => s.dayOfWeek === currentApiDay)
    .sort((a, b) => timeToMinutes(a.startTime) - timeToMinutes(b.startTime));

  let currentClass = null;
  let nextClass = null;

  for (const s of todayClasses) {
    const start = timeToMinutes(s.startTime);
    const end = timeToMinutes(s.endTime);

    if (start <= currentMinutes && currentMinutes < end) {
      currentClass = s;
    } else if (start > currentMinutes && !nextClass) {
      nextClass = s;
    }
  }

  // Si hoy no hay más clases, buscar la primera clase de los días siguientes (lunes a sábado, rotativo)
  if (!nextClass) {
    for (let offset = 1; offset <= 6; offset++) {
      const nextDay = ((currentApiDay - 1 + offset) % 7) + 1;
      const nextDayClasses = schedules
        .filter((s) => s.dayOfWeek === nextDay)
        .sort((a, b) => timeToMinutes(a.startTime) - timeToMinutes(b.startTime));

      if (nextDayClasses.length > 0) {
        nextClass = nextDayClasses[0];
        break;
      }
    }
  }

  return { currentClass, nextClass };
}

/**
 * Calcula el resumen de calificaciones con las fórmulas de docs/api.md.
 */
export function calculateAcademicSummary(grades, passingGrade = 8.0, gradeScale = 10.0) {
  if (!grades || grades.length === 0) {
    return {
      status: 'no-data',
      accumulated: 0,
      currentAverage: 0,
      gradedWeight: 0,
      pendingWeight: 0,
      totalWeight: 0,
      neededOnPending: null,
      currentWeightedScore: 0,
      evaluatedWeight: 0,
      neededScore: null,
      isWeightsSum100: false,
      isImpossible: false,
      isAlreadyPassed: false,
    };
  }

  let accumulated = 0;
  let gradedWeight = 0;
  let pendingWeight = 0;

  for (const g of grades) {
    const weight = Number(g.weight) || 0;
    const score = g.score !== null && g.score !== undefined && g.score !== '' ? Number(g.score) : null;

    if (score !== null) {
      gradedWeight += weight;
      accumulated += (score * weight) / 100;
    } else {
      pendingWeight += weight;
    }
  }

  const totalWeight = gradedWeight + pendingWeight;
  const currentAverage = gradedWeight > 0 ? (accumulated * 100) / gradedWeight : 0;

  let neededOnPending = null;
  let status = 'no-data';

  if (totalWeight === 0) {
    status = 'no-data';
  } else if (pendingWeight <= 0) {
    status = accumulated >= passingGrade ? 'approved' : 'failed';
  } else {
    neededOnPending = ((passingGrade - accumulated) * 100) / pendingWeight;
    if (neededOnPending <= 0) {
      status = 'secured';
    } else if (neededOnPending > gradeScale) {
      status = 'impossible';
    } else {
      status = 'possible';
    }
  }

  const roundAcc = Math.round(accumulated * 100) / 100;
  const roundAvg = Math.round(currentAverage * 100) / 100;
  const roundGraded = Math.round(gradedWeight * 100) / 100;
  const roundPending = Math.round(pendingWeight * 100) / 100;
  const roundTotal = Math.round(totalWeight * 100) / 100;
  const roundNeeded = neededOnPending !== null ? Math.round(neededOnPending * 100) / 100 : null;

  return {
    status,
    accumulated: roundAcc,
    currentAverage: roundAvg,
    gradedWeight: roundGraded,
    pendingWeight: roundPending,
    totalWeight: roundTotal,
    neededOnPending: roundNeeded,
    // Aliases y helpers booleanos
    currentWeightedScore: roundAcc,
    evaluatedWeight: roundGraded,
    neededScore: roundNeeded,
    isWeightsSum100: roundTotal === 100,
    isImpossible: status === 'impossible',
    isAlreadyPassed: status === 'secured' || status === 'approved',
  };
}

/**
 * Simula la calificación proyectada si se obtiene una puntuación dada en las evaluaciones pendientes.
 */
export function simulateProjectedGrade(grades, simulatedPendingScore) {
  const summary = calculateAcademicSummary(grades);
  const score = Number(simulatedPendingScore) || 0;
  const projected = summary.accumulated + (score * summary.pendingWeight) / 100;
  return Math.round(projected * 100) / 100;
}

/**
 * Normaliza y construye el payload de una tarea/examen según docs/api.md.
 * Garantiza que lleve `kind` ("task" | "exam") y NUNCA `isExam`.
 * @param {Object} formData
 * @returns {Object} Payload listo para la API
 */
export function buildTaskPayload(formData) {
  const kind = formData.kind === 'exam' || formData.isExam === true ? 'exam' : 'task';
  const isoDueAt = formData.dueAt ? datetimeLocalToIso(formData.dueAt) : null;
  return {
    subjectId: formData.subjectId,
    title: formData.title?.trim() || '',
    description: formData.description?.trim() || null,
    kind,
    dueAt: isoDueAt,
    photoUrl: formData.photoUrl || null,
    reminders: Array.isArray(formData.reminders) ? formData.reminders : [],
  };
}

/**
 * Normaliza y construye el payload de una clase del horario según docs/api.md.
 * Garantiza que use `room` (Salón) y no `classroom`.
 * @param {Object} formData
 * @returns {Object} Payload listo para la API
 */
export function buildSchedulePayload(formData) {
  const roomVal = (formData.room || formData.classroom)?.trim() || null;
  return {
    subjectId: formData.subjectId,
    dayOfWeek: Number(formData.dayOfWeek),
    startTime: formData.startTime,
    endTime: formData.endTime,
    room: roomVal,
  };
}
