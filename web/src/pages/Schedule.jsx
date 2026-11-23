import React, { useState, useEffect } from 'react';
import { getSubjects, getSchedules, createSchedule, updateSchedule, deleteSchedule } from '../api';
import { Modal } from '../components/Modal';
import { getDayName, buildSchedulePayload } from '../utils';

const DAYS = [
  { id: 1, name: 'Lunes' },
  { id: 2, name: 'Martes' },
  { id: 3, name: 'Miércoles' },
  { id: 4, name: 'Jueves' },
  { id: 5, name: 'Viernes' },
  { id: 6, name: 'Sábado' },
];

export function Schedule() {
  const [subjects, setSubjects] = useState([]);
  const [schedules, setSchedules] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Modal de agregar/editar
  const [modalOpen, setModalOpen] = useState(false);
  const [editingSchedule, setEditingSchedule] = useState(null);
  const [formData, setFormData] = useState({
    subjectId: '',
    dayOfWeek: 1,
    startTime: '08:00',
    endTime: '10:00',
    room: '',
  });
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState('');

  const loadData = async () => {
    try {
      setLoading(true);
      setError('');
      const [subjectsData, schedulesData] = await Promise.all([
        getSubjects(),
        getSchedules(),
      ]);
      setSubjects(subjectsData || []);
      setSchedules(schedulesData || []);
    } catch (err) {
      setError(err.message || 'Error al cargar horario');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const subjectsMap = React.useMemo(() => {
    const map = {};
    for (const s of subjects) {
      map[s.id] = s;
    }
    return map;
  }, [subjects]);

  const openCreateModal = (day = 1) => {
    if (subjects.length === 0) {
      alert('Primero debes registrar al menos una materia para poder agregar clases al horario.');
      return;
    }
    setEditingSchedule(null);
    setFormData({
      subjectId: subjects[0]?.id || '',
      dayOfWeek: day,
      startTime: '08:00',
      endTime: '10:00',
      room: '',
    });
    setFormError('');
    setModalOpen(true);
  };

  const openEditModal = (schedule) => {
    setEditingSchedule(schedule);
    setFormData({
      subjectId: schedule.subjectId,
      dayOfWeek: schedule.dayOfWeek,
      startTime: schedule.startTime,
      endTime: schedule.endTime,
      room: schedule.room || schedule.classroom || '',
    });
    setFormError('');
    setModalOpen(true);
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setFormError('');

    if (!formData.subjectId) {
      setFormError('Selecciona una materia');
      return;
    }
    if (!formData.startTime || !formData.endTime) {
      setFormError('Indica la hora de inicio y fin');
      return;
    }
    if (formData.startTime >= formData.endTime) {
      setFormError('La hora de inicio debe ser anterior a la hora de fin');
      return;
    }

    try {
      setSubmitting(true);
      const payload = buildSchedulePayload(formData);

      if (editingSchedule) {
        const updated = await updateSchedule(editingSchedule.id, payload);
        setSchedules((prev) => prev.map((s) => (s.id === editingSchedule.id ? updated : s)));
      } else {
        const created = await createSchedule(payload);
        setSchedules((prev) => [...prev, created]);
      }
      setModalOpen(false);
    } catch (err) {
      setFormError(err.message || 'Error al guardar clase');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async () => {
    if (!editingSchedule) return;
    if (!window.confirm('¿Seguro que deseas eliminar esta clase del horario?')) return;

    try {
      setSubmitting(true);
      await deleteSchedule(editingSchedule.id);
      setSchedules((prev) => prev.filter((s) => s.id !== editingSchedule.id));
      setModalOpen(false);
    } catch (err) {
      setFormError(err.message || 'Error al eliminar clase');
    } finally {
      setSubmitting(false);
    }
  };

  // Agrupar clases por día y ordenar por startTime
  const schedulesByDay = DAYS.reduce((acc, day) => {
    acc[day.id] = schedules
      .filter((s) => s.dayOfWeek === day.id)
      .sort((a, b) => a.startTime.localeCompare(b.startTime));
    return acc;
  }, {});

  if (loading) {
    return (
      <div className="loading-container">
        <div className="spinner spinner-dark" />
        <p>Cargando horario semanal...</p>
      </div>
    );
  }

  return (
    <div>
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: '12px',
          marginBottom: '20px',
        }}
      >
        <div>
          <h1 style={{ fontSize: '24px' }}>Horario Semanal</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '14px' }}>
            Consulta y organiza tus clases de lunes a sábado
          </p>
        </div>
        <button className="btn btn-primary" onClick={() => openCreateModal(1)}>
          ➕ Agregar Clase
        </button>
      </div>

      {error && <div className="alert alert-danger">{error}</div>}

      {subjects.length === 0 ? (
        <div className="card" style={{ textAlign: 'center', padding: '40px 20px' }}>
          <div style={{ fontSize: '40px', marginBottom: '12px' }}>📚</div>
          <h3>Aún no has registrado materias</h3>
          <p style={{ color: 'var(--text-muted)', margin: '8px 0 20px' }}>
            Para armar tu horario, primero necesitas registrar tus asignaturas del semestre.
          </p>
          <a href="/materias" className="btn btn-primary">
            Ir a Materias
          </a>
        </div>
      ) : (
        <>
          {/* Vista Cuadrícula Semanal (Desktop y tablet) */}
          <div className="card" style={{ padding: '16px', overflowX: 'auto' }}>
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(6, minmax(140px, 1fr))',
                gap: '12px',
                minWidth: '780px',
              }}
            >
              {DAYS.map((day) => {
                const dayClasses = schedulesByDay[day.id] || [];
                return (
                  <div
                    key={day.id}
                    style={{
                      background: '#fcfcfd',
                      borderRadius: '8px',
                      border: '1px solid var(--border)',
                      display: 'flex',
                      flexDirection: 'column',
                    }}
                  >
                    <div
                      style={{
                        backgroundColor: '#f3f4f6',
                        padding: '10px 8px',
                        fontWeight: 700,
                        fontSize: '13px',
                        textAlign: 'center',
                        borderBottom: '1px solid var(--border)',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                      }}
                    >
                      <span>{day.name}</span>
                      <button
                        type="button"
                        onClick={() => openCreateModal(day.id)}
                        className="btn-outline"
                        style={{
                          fontSize: '14px',
                          border: 'none',
                          cursor: 'pointer',
                          background: 'none',
                          color: 'var(--primary)',
                          fontWeight: 'bold',
                        }}
                        title={`Agregar clase en ${day.name}`}
                      >
                        +
                      </button>
                    </div>

                    <div style={{ padding: '8px', flex: 1, minHeight: '200px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                      {dayClasses.length === 0 ? (
                        <div
                          style={{
                            textAlign: 'center',
                            color: 'var(--text-muted)',
                            fontSize: '12px',
                            margin: 'auto 0',
                            fontStyle: 'italic',
                          }}
                        >
                          Sin clases
                        </div>
                      ) : (
                        dayClasses.map((s) => {
                          const subj = subjectsMap[s.subjectId];
                          const bg = subj?.color || 'var(--primary)';
                          return (
                            <div
                              key={s.id}
                              onClick={() => openEditModal(s)}
                              style={{
                                backgroundColor: bg,
                                color: '#ffffff',
                                borderRadius: '6px',
                                padding: '8px 10px',
                                cursor: 'pointer',
                                boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
                                transition: 'transform 0.1s ease',
                              }}
                              onMouseEnter={(e) => (e.currentTarget.style.transform = 'scale(1.02)')}
                              onMouseLeave={(e) => (e.currentTarget.style.transform = 'scale(1)')}
                            >
                              <div style={{ fontWeight: 700, fontSize: '13px', wordBreak: 'break-word' }}>
                                {subj?.name || 'Materia'}
                              </div>
                              <div style={{ fontSize: '11px', opacity: 0.95, marginTop: '2px' }}>
                                🕒 {s.startTime} - {s.endTime}
                              </div>
                              {(s.room || s.classroom) && (
                                <div style={{ fontSize: '11px', opacity: 0.9, marginTop: '2px' }}>
                                  📍 {s.room || s.classroom}
                                </div>
                              )}
                            </div>
                          );
                        })
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </>
      )}

      {/* Modal Agregar / Editar Clase */}
      <Modal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        title={editingSchedule ? 'Editar Clase' : 'Agregar Clase al Horario'}
      >
        {formError && <div className="alert alert-danger">{formError}</div>}

        <form onSubmit={handleSave}>
          <div className="form-group">
            <label className="form-label" htmlFor="subjectId">
              Materia *
            </label>
            <select
              id="subjectId"
              className="form-select"
              value={formData.subjectId}
              onChange={(e) => setFormData({ ...formData, subjectId: e.target.value })}
              required
            >
              {subjects.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="dayOfWeek">
              Día de la semana *
            </label>
            <select
              id="dayOfWeek"
              className="form-select"
              value={formData.dayOfWeek}
              onChange={(e) => setFormData({ ...formData, dayOfWeek: Number(e.target.value) })}
              required
            >
              {DAYS.map((d) => (
                <option key={d.id} value={d.id}>
                  {d.name}
                </option>
              ))}
            </select>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label className="form-label" htmlFor="startTime">
                Hora de Inicio *
              </label>
              <input
                id="startTime"
                type="time"
                className="form-input"
                value={formData.startTime}
                onChange={(e) => setFormData({ ...formData, startTime: e.target.value })}
                required
              />
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="endTime">
                Hora de Fin *
              </label>
              <input
                id="endTime"
                type="time"
                className="form-input"
                value={formData.endTime}
                onChange={(e) => setFormData({ ...formData, endTime: e.target.value })}
                required
              />
            </div>
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="room">
              Salón o Aula (opcional)
            </label>
            <input
              id="room"
              type="text"
              className="form-input"
              placeholder="Ej. Lab C, Aula 105"
              value={formData.room}
              onChange={(e) => setFormData({ ...formData, room: e.target.value })}
            />
          </div>

          <div className="modal-actions" style={{ justifyContent: editingSchedule ? 'space-between' : 'flex-end' }}>
            {editingSchedule && (
              <button
                type="button"
                className="btn btn-danger"
                onClick={handleDelete}
                disabled={submitting}
              >
                Eliminar Clase
              </button>
            )}
            <div style={{ display: 'flex', gap: '8px' }}>
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => setModalOpen(false)}
                disabled={submitting}
              >
                Cancelar
              </button>
              <button type="submit" className="btn btn-primary" disabled={submitting}>
                {submitting ? 'Guardando...' : editingSchedule ? 'Actualizar' : 'Guardar'}
              </button>
            </div>
          </div>
        </form>
      </Modal>
    </div>
  );
}
