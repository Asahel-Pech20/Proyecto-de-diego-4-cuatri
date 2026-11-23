import { describe, it, expect } from 'vitest';
import {
  jsDayToApiDay,
  apiDayToJsDay,
  getDayName,
  datetimeLocalToIso,
  isoToDatetimeLocal,
  localDateString,
  formatDisplayDate,
  calculateCurrentAndNextClass,
  calculateAcademicSummary,
  simulateProjectedGrade,
  buildTaskPayload,
  buildSchedulePayload,
} from './utils.js';

describe('Pruebas requeridas con Vitest para MiSemestre UTM (Web)', () => {
  // 1. Conversión de dayOfWeek
  describe('1. Conversión de dayOfWeek (JS 0=Dom ... 6=Sáb vs API 1=Lun ... 7=Dom)', () => {
    it('convierte correctamente días de JS a API', () => {
      expect(jsDayToApiDay(1)).toBe(1); // Lunes
      expect(jsDayToApiDay(2)).toBe(2); // Martes
      expect(jsDayToApiDay(5)).toBe(5); // Viernes
      expect(jsDayToApiDay(6)).toBe(6); // Sábado
      expect(jsDayToApiDay(0)).toBe(7); // Domingo en JS es 0 -> en API es 7
    });

    it('convierte correctamente días de API a JS', () => {
      expect(apiDayToJsDay(1)).toBe(1); // Lunes
      expect(apiDayToJsDay(6)).toBe(6); // Sábado
      expect(apiDayToJsDay(7)).toBe(0); // Domingo en API es 7 -> en JS es 0
    });

    it('devuelve el nombre de día correcto', () => {
      expect(getDayName(1)).toBe('Lunes');
      expect(getDayName(1, true)).toBe('Lun');
      expect(getDayName(6)).toBe('Sábado');
      expect(getDayName(7)).toBe('Domingo');
    });
  });

  // 2. Conversión de datetime-local a ISO y de vuelta
  describe('2. Conversión de datetime-local a ISO y de vuelta', () => {
    it('convierte formato input datetime-local a ISO string válido', () => {
      const inputVal = '2026-11-20T14:30';
      const iso = datetimeLocalToIso(inputVal);
      expect(iso).not.toBeNull();
      expect(new Date(iso).getTime()).not.toBeNaN();

      // Debe preservar el año, mes, día, hora y minutos en hora local
      const parsed = new Date(iso);
      expect(parsed.getFullYear()).toBe(2026);
      expect(parsed.getMonth()).toBe(10); // Noviembre es 10 (base 0)
      expect(parsed.getDate()).toBe(20);
      expect(parsed.getHours()).toBe(14);
      expect(parsed.getMinutes()).toBe(30);
    });

    it('convierte formato ISO a string para input datetime-local y mantiene consistencia de ida y vuelta', () => {
      const originalInput = '2026-11-20T14:30';
      const iso = datetimeLocalToIso(originalInput);
      const roundTrip = isoToDatetimeLocal(iso);
      expect(roundTrip).toBe(originalInput);
    });

    it('maneja valores vacíos o nulos sin lanzar errores', () => {
      expect(datetimeLocalToIso(null)).toBeNull();
      expect(datetimeLocalToIso('')).toBeNull();
      expect(isoToDatetimeLocal(null)).toBe('');
      expect(isoToDatetimeLocal('')).toBe('');
    });

    it('localDateString devuelve YYYY-MM-DD en hora local incluso en horas nocturnas (evita UTC bug)', () => {
      // 19 de noviembre de 2026 a las 23:45 (noche en México)
      const nightDate = new Date(2026, 10, 19, 23, 45, 0);
      const str = localDateString(nightDate);
      expect(str).toBe('2026-11-19'); // Debe seguir siendo 19, NO 20
    });

    it('formatDisplayDate formatea correctamente tanto strings como objetos Date', () => {
      expect(formatDisplayDate('2026-11-19')).toBe('19/11/2026');
      expect(formatDisplayDate('2026-11-19T23:30:00.000Z')).toBe('19/11/2026');

      const dateObj = new Date(2026, 10, 19);
      expect(formatDisplayDate(dateObj)).toBe('19/11/2026');
      expect(formatDisplayDate(null)).toBe('');
    });
  });

  // 3. Cálculo de "clase actual / siguiente"
  describe('3. Cálculo de clase actual y siguiente a partir del horario y una hora dada', () => {
    const schedules = [
      { id: '1', subjectId: 's1', dayOfWeek: 1, startTime: '08:00', endTime: '10:00' }, // Lunes 8-10
      { id: '2', subjectId: 's2', dayOfWeek: 1, startTime: '10:00', endTime: '12:00' }, // Lunes 10-12
      { id: '3', subjectId: 's3', dayOfWeek: 2, startTime: '08:00', endTime: '10:00' }, // Martes 8-10
    ];

    it('identifica la clase en curso cuando la hora actual cae en su rango', () => {
      // Lunes a las 09:15
      // 2026-11-16 fue Lunes
      const monday915 = new Date(2026, 10, 16, 9, 15);
      const res = calculateCurrentAndNextClass(schedules, monday915);
      expect(res.currentClass).not.toBeNull();
      expect(res.currentClass.id).toBe('1');
      expect(res.nextClass).not.toBeNull();
      expect(res.nextClass.id).toBe('2');
    });

    it('identifica la siguiente clase del mismo día si no hay clase en curso', () => {
      // Lunes a las 07:30
      const monday730 = new Date(2026, 10, 16, 7, 30);
      const res = calculateCurrentAndNextClass(schedules, monday730);
      expect(res.currentClass).toBeNull();
      expect(res.nextClass).not.toBeNull();
      expect(res.nextClass.id).toBe('1');
    });

    it('busca la primera clase del día siguiente si las de hoy ya concluyeron', () => {
      // Lunes a las 14:00 (ya terminaron las clases del lunes)
      const monday1400 = new Date(2026, 10, 16, 14, 0);
      const res = calculateCurrentAndNextClass(schedules, monday1400);
      expect(res.currentClass).toBeNull();
      expect(res.nextClass).not.toBeNull();
      expect(res.nextClass.id).toBe('3'); // Martes 8-10
    });
  });

  // 4. Simulador "¿Y si saco...?" y caso específico requerido
  describe('4. Simulador académico y cálculo "¿Y si saco...?"', () => {
    // Caso requerido: Parcial 1 = 7 (30%), Parcial 2 = 8 (30%), Final pendiente (40%), aprobatoria 8
    const grades = [
      { id: '1', name: 'Parcial 1', weight: 30, score: 7 },
      { id: '2', name: 'Parcial 2', weight: 30, score: 8 },
      { id: '3', name: 'Final', weight: 40, score: null },
    ];

    it('calcula acumulado 4.5, necesita 8.75 y estado possible', () => {
      const summary = calculateAcademicSummary(grades, 8.0, 10.0);
      expect(summary.accumulated).toBe(4.5);
      expect(summary.gradedWeight).toBe(60);
      expect(summary.pendingWeight).toBe(40);
      expect(summary.neededOnPending).toBe(8.75);
      expect(summary.status).toBe('possible');
    });

    it('si en la simulación "¿Y si saco...?" se obtiene 8 en el final, la calificación queda en 7.7', () => {
      const projected = simulateProjectedGrade(grades, 8.0);
      expect(projected).toBe(7.7);
    });

    it('si en la simulación se obtiene 8.75 en el final, alcanza exactamente la aprobatoria 8.0', () => {
      const projected = simulateProjectedGrade(grades, 8.75);
      expect(projected).toBe(8.0);
    });

    it('cubre estados secured, impossible, approved y failed', () => {
      // Secured: necesita <= 0
      const securedGrades = [
        { id: '1', weight: 80, score: 10 },
        { id: '2', weight: 20, score: null },
      ];
      expect(calculateAcademicSummary(securedGrades, 8.0).status).toBe('secured');

      // Impossible: necesita > 10
      const impossibleGrades = [
        { id: '1', weight: 70, score: 5 }, // 3.5
        { id: '2', weight: 30, score: null }, // necesita (8 - 3.5)*100/30 = 450/30 = 15 > 10
      ];
      expect(calculateAcademicSummary(impossibleGrades, 8.0).status).toBe('impossible');

      // Approved (sin pendientes y >= 8)
      const approvedGrades = [
        { id: '1', weight: 50, score: 8 },
        { id: '2', weight: 50, score: 9 },
      ];
      expect(calculateAcademicSummary(approvedGrades, 8.0).status).toBe('approved');

      // Failed (sin pendientes y < 8)
      const failedGrades = [
        { id: '1', weight: 50, score: 6 },
        { id: '2', weight: 50, score: 7 },
      ];
      expect(calculateAcademicSummary(failedGrades, 8.0).status).toBe('failed');
    });
  });

  // 5. Verificación de payloads conformes con docs/api.md (kind y room)
  describe('5. Conformidad estricta de payloads con docs/api.md', () => {
    it('el payload de crear/editar examen incluye "kind: exam" y NUNCA "isExam"', () => {
      const formData = {
        subjectId: 'sub-123',
        title: 'Examen Ordinario',
        description: 'Capítulos 1 al 5',
        kind: 'exam',
        dueAt: '2026-11-25T10:00',
        photoUrl: null,
        reminders: [1440, 120],
      };

      const payload = buildTaskPayload(formData);

      expect(payload).toHaveProperty('kind');
      expect(payload.kind).toBe('exam');
      expect(payload).not.toHaveProperty('isExam');
      expect(payload.title).toBe('Examen Ordinario');
      expect(payload.subjectId).toBe('sub-123');
    });

    it('el payload de crear tarea incluye "kind: task" y NUNCA "isExam"', () => {
      const formData = {
        subjectId: 'sub-456',
        title: 'Práctica 4',
        kind: 'task',
        dueAt: '2026-11-22T23:59',
      };

      const payload = buildTaskPayload(formData);

      expect(payload).toHaveProperty('kind');
      expect(payload.kind).toBe('task');
      expect(payload).not.toHaveProperty('isExam');
    });

    it('el payload de horario incluye "room" y NUNCA "classroom"', () => {
      const formData = {
        subjectId: 'sub-123',
        dayOfWeek: 1,
        startTime: '08:00',
        endTime: '10:00',
        room: 'Lab Redes 2',
      };

      const payload = buildSchedulePayload(formData);

      expect(payload).toHaveProperty('room');
      expect(payload.room).toBe('Lab Redes 2');
      expect(payload).not.toHaveProperty('classroom');
    });
  });
});
