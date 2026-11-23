import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { getSubjects, getSchedules, getTasks, updateTask } from '../api';
import {
  calculateCurrentAndNextClass,
  formatDisplayDateTime,
  formatDisplayDate,
  getDayName,
} from '../utils';

export function Home() {
  const { user } = useAuth();
  const [subjects, setSubjects] = useState([]);
  const [schedules, setSchedules] = useState([]);
  const [tasks, setTasks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [togglingTaskId, setTogglingTaskId] = useState(null);

  const loadData = async () => {
    try {
      setLoading(true);
      setError('');
      const [subjectsData, schedulesData, tasksData] = await Promise.all([
        getSubjects(),
        getSchedules(),
        getTasks(),
      ]);
      setSubjects(subjectsData || []);
      setSchedules(schedulesData || []);
      setTasks(tasksData || []);
    } catch (err) {
      setError(err.message || 'Error al cargar datos del tablero');
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

  const handleToggleTask = async (task) => {
    try {
      setTogglingTaskId(task.id);
      const updated = await updateTask(task.id, { done: !task.done });
      setTasks((prev) => prev.map((t) => (t.id === task.id ? updated : t)));
    } catch (err) {
      alert(`Error al actualizar tarea: ${err.message}`);
    } finally {
      setTogglingTaskId(null);
    }
  };

  if (loading) {
    return (
      <div className="loading-container">
        <div className="spinner spinner-dark" />
        <p>Cargando información académica...</p>
      </div>
    );
  }

  const now = new Date();
  const { currentClass, nextClass } = calculateCurrentAndNextClass(schedules, now);

  // Filtrar tareas por hoy, mañana y vencidas
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
  const tomorrowStart = new Date(todayStart.getTime() + 24 * 60 * 60 * 1000);
  const dayAfterTomorrowStart = new Date(todayStart.getTime() + 48 * 60 * 60 * 1000);

  const overdueTasks = tasks.filter((t) => {
    if (t.done || !t.dueAt) return false;
    return new Date(t.dueAt).getTime() < now.getTime();
  });

  const todayTasks = tasks.filter((t) => {
    if (!t.dueAt) return false;
    const due = new Date(t.dueAt).getTime();
    return due >= todayStart.getTime() && due < tomorrowStart.getTime();
  });

  const tomorrowTasks = tasks.filter((t) => {
    if (!t.dueAt) return false;
    const due = new Date(t.dueAt).getTime();
    return due >= tomorrowStart.getTime() && due < dayAfterTomorrowStart.getTime();
  });

  return (
    <div>
      {/* Encabezado */}
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: '12px',
          marginBottom: '24px',
        }}
      >
        <div>
          <h1 style={{ fontSize: '26px' }}>¡Hola, {user?.name || 'Estudiante'}!</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '14px' }}>
            {formatDisplayDate(now)} — Panel principal de tu semestre en la UTM
          </p>
        </div>
        <div style={{ display: 'flex', gap: '8px' }}>
          <Link to="/horario" className="btn btn-secondary btn-sm">
            📅 Ver Horario
          </Link>
          <Link to="/tareas" className="btn btn-primary btn-sm">
            ➕ Tareas y Exámenes
          </Link>
        </div>
      </div>

      {error && <div className="alert alert-danger">{error}</div>}

      {/* Tarjeta "¿Qué clase sigue?" */}
      <div
        className="card"
        style={{
          borderLeft: '5px solid var(--primary)',
          backgroundColor: '#ffffff',
          position: 'relative',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '12px' }}>
          <span style={{ fontSize: '22px' }}>⏰</span>
          <h2 style={{ fontSize: '18px' }}>Estado de tus clases</h2>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '16px' }}>
          {/* Clase en curso */}
          <div
            style={{
              padding: '14px',
              borderRadius: '8px',
              backgroundColor: currentClass ? '#f0fdf4' : '#f9fafb',
              border: `1px solid ${currentClass ? '#bbf7d0' : 'var(--border)'}`,
            }}
          >
            <div style={{ fontSize: '12px', fontWeight: 700, color: currentClass ? '#166534' : 'var(--text-muted)', marginBottom: '4px' }}>
              {currentClass ? '🟢 CLASE EN CURSO AHORA' : 'EN ESTE MOMENTO'}
            </div>
            {currentClass ? (
              <div>
                <div style={{ fontSize: '16px', fontWeight: 700, color: 'var(--text-main)' }}>
                  {subjectsMap[currentClass.subjectId]?.name || 'Materia'}
                </div>
                <div style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '2px' }}>
                  {currentClass.startTime} - {currentClass.endTime}
                  {currentClass.room && ` • Salón: ${currentClass.room}`}
                </div>
              </div>
            ) : (
              <p style={{ fontSize: '14px', color: 'var(--text-muted)' }}>No tienes clase en este instante.</p>
            )}
          </div>

          {/* Siguiente clase */}
          <div
            style={{
              padding: '14px',
              borderRadius: '8px',
              backgroundColor: nextClass ? '#eff6ff' : '#f9fafb',
              border: `1px solid ${nextClass ? '#bfdbfe' : 'var(--border)'}`,
            }}
          >
            <div style={{ fontSize: '12px', fontWeight: 700, color: nextClass ? '#1e40af' : 'var(--text-muted)', marginBottom: '4px' }}>
              🔜 PRÓXIMA CLASE
            </div>
            {nextClass ? (
              <div>
                <div style={{ fontSize: '16px', fontWeight: 700, color: 'var(--text-main)' }}>
                  {subjectsMap[nextClass.subjectId]?.name || 'Materia'}
                </div>
                <div style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '2px' }}>
                  {getDayName(nextClass.dayOfWeek)} • {nextClass.startTime} - {nextClass.endTime}
                  {nextClass.room && ` • Salón: ${nextClass.room}`}
                </div>
              </div>
            ) : (
              <p style={{ fontSize: '14px', color: 'var(--text-muted)' }}>No hay más clases programadas esta semana.</p>
            )}
          </div>
        </div>
      </div>

      {/* Alerta de tareas vencidas */}
      {overdueTasks.length > 0 && (
        <div className="card" style={{ borderLeft: '5px solid var(--danger)', backgroundColor: '#fff5f5' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px' }}>
            <span style={{ fontSize: '20px' }}>⚠️</span>
            <h3 style={{ fontSize: '16px', color: '#991b1b' }}>
              Tienes {overdueTasks.length} pendiente{overdueTasks.length > 1 ? 's' : ''} vencido{overdueTasks.length > 1 ? 's' : ''}
            </h3>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {overdueTasks.map((t) => {
              const subj = subjectsMap[t.subjectId];
              return (
                <div
                  key={t.id}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '8px 12px',
                    borderRadius: '6px',
                    backgroundColor: '#ffffff',
                    border: '1px solid #fecaca',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <input
                      type="checkbox"
                      checked={t.done}
                      disabled={togglingTaskId === t.id}
                      onChange={() => handleToggleTask(t)}
                      style={{ cursor: 'pointer', width: '16px', height: '16px' }}
                    />
                    <div>
                      <span style={{ fontWeight: 600, fontSize: '14px' }}>{t.title}</span>
                      <div style={{ fontSize: '12px', color: '#b91c1c' }}>
                        {subj?.name ? `${subj.name} • ` : ''}Venció el {formatDisplayDateTime(t.dueAt)}
                      </div>
                    </div>
                  </div>
                  <span className={t.kind === 'exam' ? 'badge badge-exam' : 'badge badge-task'}>
                    {t.kind === 'exam' ? 'Examen' : 'Tarea'}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Grid: Pendientes de hoy y mañana */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '20px' }}>
        {/* Hoy */}
        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '14px' }}>
            <h3 style={{ fontSize: '16px' }}>📌 Pendientes para Hoy</h3>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>{todayTasks.length} en total</span>
          </div>
          {todayTasks.length === 0 ? (
            <p style={{ color: 'var(--text-muted)', fontSize: '14px' }}>No tienes tareas ni exámenes programados para hoy.</p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              {todayTasks.map((t) => {
                const subj = subjectsMap[t.subjectId];
                return (
                  <div
                    key={t.id}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '10px',
                      borderRadius: '8px',
                      border: '1px solid var(--border)',
                      backgroundColor: t.done ? '#f9fafb' : '#ffffff',
                      opacity: t.done ? 0.7 : 1,
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                      <input
                        type="checkbox"
                        checked={t.done}
                        disabled={togglingTaskId === t.id}
                        onChange={() => handleToggleTask(t)}
                        style={{ cursor: 'pointer', width: '18px', height: '18px' }}
                      />
                      <div>
                        <span
                          style={{
                            fontWeight: 600,
                            fontSize: '14px',
                            textDecoration: t.done ? 'line-through' : 'none',
                          }}
                        >
                          {t.title}
                        </span>
                        <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                          {subj && (
                            <span
                              style={{
                                display: 'inline-block',
                                width: '8px',
                                height: '8px',
                                borderRadius: '50%',
                                backgroundColor: subj.color || 'var(--primary)',
                                marginRight: '5px',
                              }}
                            />
                          )}
                          {subj?.name || 'General'} • {formatDisplayDateTime(t.dueAt).split(',')[1] || ''}
                        </div>
                      </div>
                    </div>
                    <span className={t.kind === 'exam' ? 'badge badge-exam' : 'badge badge-task'}>
                      {t.kind === 'exam' ? 'Examen' : 'Tarea'}
                    </span>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Mañana */}
        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '14px' }}>
            <h3 style={{ fontSize: '16px' }}>🌅 Pendientes para Mañana</h3>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>{tomorrowTasks.length} en total</span>
          </div>
          {tomorrowTasks.length === 0 ? (
            <p style={{ color: 'var(--text-muted)', fontSize: '14px' }}>No tienes tareas ni exámenes programados para mañana.</p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              {tomorrowTasks.map((t) => {
                const subj = subjectsMap[t.subjectId];
                return (
                  <div
                    key={t.id}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '10px',
                      borderRadius: '8px',
                      border: '1px solid var(--border)',
                      backgroundColor: t.done ? '#f9fafb' : '#ffffff',
                      opacity: t.done ? 0.7 : 1,
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                      <input
                        type="checkbox"
                        checked={t.done}
                        disabled={togglingTaskId === t.id}
                        onChange={() => handleToggleTask(t)}
                        style={{ cursor: 'pointer', width: '18px', height: '18px' }}
                      />
                      <div>
                        <span
                          style={{
                            fontWeight: 600,
                            fontSize: '14px',
                            textDecoration: t.done ? 'line-through' : 'none',
                          }}
                        >
                          {t.title}
                        </span>
                        <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                          {subj && (
                            <span
                              style={{
                                display: 'inline-block',
                                width: '8px',
                                height: '8px',
                                borderRadius: '50%',
                                backgroundColor: subj.color || 'var(--primary)',
                                marginRight: '5px',
                              }}
                            />
                          )}
                          {subj?.name || 'General'} • {formatDisplayDateTime(t.dueAt).split(',')[1] || ''}
                        </div>
                      </div>
                    </div>
                    <span className={t.kind === 'exam' ? 'badge badge-exam' : 'badge badge-task'}>
                      {t.kind === 'exam' ? 'Examen' : 'Tarea'}
                    </span>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
