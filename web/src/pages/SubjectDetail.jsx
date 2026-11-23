import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import {
  getSubject,
  getSubjectSummary,
  getAbsences,
  createAbsence,
  updateAbsence,
  deleteAbsence,
  getGrades,
  createGrade,
  updateGrade,
  deleteGrade,
} from '../api';
import { Modal } from '../components/Modal';
import {
  calculateAcademicSummary,
  simulateProjectedGrade,
  formatDisplayDate,
  localDateString,
} from '../utils';

export function SubjectDetail() {
  const { id } = useParams();
  const [subject, setSubject] = useState(null);
  const [absences, setAbsences] = useState([]);
  const [grades, setGrades] = useState([]);
  const [apiSummary, setApiSummary] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Pestaña activa: 'absences' | 'grades' | 'simulator'
  const [activeTab, setActiveTab] = useState('absences');

  // Modales y formularios de FALTAS
  const [absenceModalOpen, setAbsenceModalOpen] = useState(false);
  const [absenceForm, setAbsenceForm] = useState({
    date: localDateString(),
    justified: false,
    note: '',
  });
  const [submittingAbsence, setSubmittingAbsence] = useState(false);

  // Modales y formularios de CALIFICACIONES
  const [gradeModalOpen, setGradeModalOpen] = useState(false);
  const [editingGrade, setEditingGrade] = useState(null);
  const [gradeForm, setGradeForm] = useState({
    name: '',
    weight: 20,
    score: '',
  });
  const [submittingGrade, setSubmittingGrade] = useState(false);
  const [gradeFormError, setGradeFormError] = useState('');

  // Estado del SIMULADOR "¿Y si saco...?"
  const [simulatedScore, setSimulatedScore] = useState(8.0);

  const loadData = async () => {
    try {
      setLoading(true);
      setError('');
      const [subjData, absencesData, gradesData] = await Promise.all([
        getSubject(id),
        getAbsences(id),
        getGrades(id),
      ]);
      setSubject(subjData);
      setAbsences(absencesData || []);
      setGrades(gradesData || []);

      // Intentar cargar resumen de la API (opcional)
      try {
        const sum = await getSubjectSummary(id);
        setApiSummary(sum);
      } catch (_) {
        // Se puede calcular localmente con utils
      }
    } catch (err) {
      setError(err.message || 'Error al cargar detalle de materia');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [id]);

  // ==========================================
  // MANEJADORES DE FALTAS
  // ==========================================
  const handleQuickAbsenceToday = async () => {
    const todayStr = localDateString();
    const alreadyExists = absences.some((a) => a.date === todayStr);
    if (alreadyExists) {
      alert(`Ya existe una falta registrada hoy (${formatDisplayDate(todayStr)}) para esta materia.`);
      return;
    }

    try {
      setSubmittingAbsence(true);
      const created = await createAbsence({
        subjectId: id,
        date: todayStr,
        justified: false,
        note: 'Falta registrada hoy',
      });
      setAbsences((prev) => [created, ...prev]);
    } catch (err) {
      alert(`Error al registrar falta: ${err.message}`);
    } finally {
      setSubmittingAbsence(false);
    }
  };

  const handleSaveAbsence = async (e) => {
    e.preventDefault();
    const alreadyExists = absences.some((a) => a.date === absenceForm.date);
    if (alreadyExists) {
      alert(`Ya existe una falta registrada el ${formatDisplayDate(absenceForm.date)} para esta materia.`);
      return;
    }

    try {
      setSubmittingAbsence(true);
      const payload = {
        subjectId: id,
        date: absenceForm.date,
        justified: absenceForm.justified,
        note: absenceForm.note.trim() || null,
      };
      const created = await createAbsence(payload);
      setAbsences((prev) => [created, ...prev]);
      setAbsenceModalOpen(false);
      setAbsenceForm({
        date: localDateString(),
        justified: false,
        note: '',
      });
    } catch (err) {
      alert(`Error al registrar falta: ${err.message}`);
    } finally {
      setSubmittingAbsence(false);
    }
  };

  const handleToggleJustified = async (absence) => {
    try {
      const updated = await updateAbsence(absence.id, {
        justified: !absence.justified,
      });
      setAbsences((prev) => prev.map((a) => (a.id === absence.id ? updated : a)));
    } catch (err) {
      alert(`Error al actualizar justificación: ${err.message}`);
    }
  };

  const handleDeleteAbsence = async (absenceId) => {
    if (!window.confirm('¿Seguro que deseas eliminar esta falta?')) return;
    try {
      await deleteAbsence(absenceId);
      setAbsences((prev) => prev.filter((a) => a.id !== absenceId));
    } catch (err) {
      alert(`Error al eliminar falta: ${err.message}`);
    }
  };

  // ==========================================
  // MANEJADORES DE CALIFICACIONES
  // ==========================================
  const openCreateGradeModal = () => {
    setEditingGrade(null);
    setGradeForm({
      name: '',
      weight: 20,
      score: '',
    });
    setGradeFormError('');
    setGradeModalOpen(true);
  };

  const openEditGradeModal = (g) => {
    setEditingGrade(g);
    setGradeForm({
      name: g.name,
      weight: g.weight,
      score: g.score !== null && g.score !== undefined ? String(g.score) : '',
    });
    setGradeFormError('');
    setGradeModalOpen(true);
  };

  const handleSaveGrade = async (e) => {
    e.preventDefault();
    setGradeFormError('');

    if (!gradeForm.name.trim()) {
      setGradeFormError('El nombre de la evaluación es obligatorio');
      return;
    }
    const weightNum = Number(gradeForm.weight);
    if (isNaN(weightNum) || weightNum <= 0) {
      setGradeFormError('El porcentaje debe ser mayor a 0');
      return;
    }

    const scoreNum = gradeForm.score.trim() === '' ? null : Number(gradeForm.score);
    if (scoreNum !== null && (isNaN(scoreNum) || scoreNum < 0 || (subject && scoreNum > subject.gradeScale))) {
      setGradeFormError(`La calificación debe estar entre 0 y ${subject?.gradeScale || 10}`);
      return;
    }

    try {
      setSubmittingGrade(true);
      if (editingGrade) {
        const changes = {
          name: gradeForm.name.trim(),
          weight: weightNum,
          score: scoreNum,
        };
        const updated = await updateGrade(editingGrade.id, changes);
        setGrades((prev) => prev.map((g) => (g.id === editingGrade.id ? updated : g)));
      } else {
        const payload = {
          subjectId: id,
          name: gradeForm.name.trim(),
          weight: weightNum,
          score: scoreNum,
        };
        const created = await createGrade(payload);
        setGrades((prev) => [...prev, created]);
      }
      setGradeModalOpen(false);
    } catch (err) {
      setGradeFormError(err.message || 'Error al guardar calificación');
    } finally {
      setSubmittingGrade(false);
    }
  };

  const handleDeleteGrade = async (gradeId) => {
    if (!window.confirm('¿Seguro que deseas eliminar esta evaluación?')) return;
    try {
      await deleteGrade(gradeId);
      setGrades((prev) => prev.filter((g) => g.id !== gradeId));
    } catch (err) {
      alert(`Error al eliminar evaluación: ${err.message}`);
    }
  };

  if (loading) {
    return (
      <div className="loading-container">
        <div className="spinner spinner-dark" />
        <p>Cargando detalles de la asignatura...</p>
      </div>
    );
  }

  if (!subject) {
    return (
      <div className="card" style={{ textAlign: 'center', padding: '40px' }}>
        <h3>Materia no encontrada</h3>
        <p style={{ margin: '12px 0' }}>La materia solicitada no existe o fue eliminada.</p>
        <Link to="/materias" className="btn btn-primary">
          Regresar a materias
        </Link>
      </div>
    );
  }

  // Cálculos de faltas
  const unjustifiedAbsences = absences.filter((a) => !a.justified);
  const totalUnjustified = unjustifiedAbsences.length;
  const maxAbs = subject.maxAbsences;
  const isAtRisk = maxAbs !== null && totalUnjustified >= maxAbs - 1 && totalUnjustified < maxAbs;
  const isExceeded = maxAbs !== null && totalUnjustified >= maxAbs;

  // Cálculos de calificaciones y simulador
  const summary = calculateAcademicSummary(grades, subject.passingGrade, subject.gradeScale);
  const projectedFinalGrade = simulateProjectedGrade(grades, Number(simulatedScore));

  return (
    <div>
      {/* Botón de regreso y encabezado */}
      <div style={{ marginBottom: '16px' }}>
        <Link to="/materias" style={{ fontSize: '13px', display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
          ← Volver a Mis Materias
        </Link>
      </div>

      <div
        className="card"
        style={{
          borderLeft: `6px solid ${subject.color || 'var(--primary)'}`,
          marginBottom: '20px',
        }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '12px' }}>
          <div>
            <h1 style={{ fontSize: '24px' }}>{subject.name}</h1>
            <p style={{ color: 'var(--text-muted)', fontSize: '14px', marginTop: '4px' }}>
              {subject.teacher ? `👨‍🏫 Profesor: ${subject.teacher}` : 'Docente no asignado'}
            </p>
          </div>
          <div style={{ display: 'flex', gap: '16px', fontSize: '13px' }}>
            <div>
              <span style={{ color: 'var(--text-muted)' }}>Mín. Aprobatoria:</span>
              <div style={{ fontWeight: 700 }}>
                {subject.passingGrade} / {subject.gradeScale}
              </div>
            </div>
            <div>
              <span style={{ color: 'var(--text-muted)' }}>Límite de Faltas:</span>
              <div style={{ fontWeight: 700 }}>
                {subject.maxAbsences ? `${subject.maxAbsences} permitidas` : 'Sin límite'}
              </div>
            </div>
          </div>
        </div>
      </div>

      {error && <div className="alert alert-danger">{error}</div>}

      {/* Selector de Pestañas */}
      <div
        style={{
          display: 'flex',
          gap: '8px',
          borderBottom: '2px solid var(--border)',
          marginBottom: '24px',
        }}
      >
        <button
          type="button"
          onClick={() => setActiveTab('absences')}
          style={{
            padding: '10px 18px',
            fontSize: '14px',
            fontWeight: 600,
            background: 'none',
            border: 'none',
            borderBottom: activeTab === 'absences' ? '3px solid var(--primary)' : '3px solid transparent',
            color: activeTab === 'absences' ? 'var(--primary)' : 'var(--text-muted)',
            cursor: 'pointer',
            marginBottom: '-2px',
          }}
        >
          🚫 Faltas ({absences.length})
        </button>
        <button
          type="button"
          onClick={() => setActiveTab('grades')}
          style={{
            padding: '10px 18px',
            fontSize: '14px',
            fontWeight: 600,
            background: 'none',
            border: 'none',
            borderBottom: activeTab === 'grades' ? '3px solid var(--primary)' : '3px solid transparent',
            color: activeTab === 'grades' ? 'var(--primary)' : 'var(--text-muted)',
            cursor: 'pointer',
            marginBottom: '-2px',
          }}
        >
          📝 Calificaciones ({grades.length})
        </button>
        <button
          type="button"
          onClick={() => setActiveTab('simulator')}
          style={{
            padding: '10px 18px',
            fontSize: '14px',
            fontWeight: 600,
            background: 'none',
            border: 'none',
            borderBottom: activeTab === 'simulator' ? '3px solid var(--primary)' : '3px solid transparent',
            color: activeTab === 'simulator' ? 'var(--primary)' : 'var(--text-muted)',
            cursor: 'pointer',
            marginBottom: '-2px',
          }}
        >
          🎯 Simulador "¿Y si saco...?"
        </button>
      </div>

      {/* ========================================================
          PESTAÑA 1: FALTAS
         ======================================================== */}
      {activeTab === 'absences' && (
        <div>
          {/* Banner de estado de faltas */}
          {maxAbs !== null && isExceeded && (
            <div className="alert alert-danger">
              ⚠️ <strong>Límite de faltas superado:</strong> Tienes {totalUnjustified} de {maxAbs} faltas permitidas. Estás en riesgo de perder derecho a examen ordinario.
            </div>
          )}
          {maxAbs !== null && isAtRisk && (
            <div className="alert alert-warning">
              ⚠️ <strong>Alerta de faltas:</strong> Tienes {totalUnjustified} de {maxAbs} faltas permitidas. Una falta más y perderás el derecho.
            </div>
          )}

          <div
            className="card"
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              flexWrap: 'wrap',
              gap: '16px',
            }}
          >
            <div>
              <div style={{ fontSize: '13px', color: 'var(--text-muted)' }}>Contador de Asistencia</div>
              <div style={{ fontSize: '20px', fontWeight: 700, marginTop: '2px' }}>
                {totalUnjustified}{' '}
                {maxAbs !== null ? (
                  <span style={{ fontSize: '15px', color: 'var(--text-muted)', fontWeight: 400 }}>
                    / {maxAbs} faltas no justificadas
                  </span>
                ) : (
                  <span style={{ fontSize: '15px', color: 'var(--text-muted)', fontWeight: 400 }}>
                    faltas registradas (sin límite)
                  </span>
                )}
              </div>
            </div>

            <div style={{ display: 'flex', gap: '8px' }}>
              <button
                type="button"
                className="btn btn-outline"
                onClick={handleQuickAbsenceToday}
                disabled={submittingAbsence}
                title="Registra una falta con fecha de hoy de inmediato"
              >
                ⚡ Falta Hoy
              </button>
              <button
                type="button"
                className="btn btn-primary"
                onClick={() => setAbsenceModalOpen(true)}
              >
                ➕ Falta con Fecha
              </button>
            </div>
          </div>

          {/* Lista de Faltas */}
          {absences.length === 0 ? (
            <div className="card" style={{ textAlign: 'center', padding: '32px' }}>
              <div style={{ fontSize: '32px', marginBottom: '8px' }}>🎉</div>
              <h4>¡Excelente asistencia!</h4>
              <p style={{ color: 'var(--text-muted)', fontSize: '13px', marginTop: '4px' }}>
                No tienes ninguna falta registrada en esta materia.
              </p>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              {absences.map((a) => (
                <div
                  key={a.id}
                  className="card"
                  style={{
                    margin: 0,
                    padding: '12px 16px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    gap: '12px',
                    backgroundColor: a.justified ? '#f0fdf4' : '#ffffff',
                    borderColor: a.justified ? '#bbf7d0' : 'var(--border)',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <span style={{ fontSize: '18px' }}>{a.justified ? '✅' : '❌'}</span>
                    <div>
                      <div style={{ fontWeight: 600, fontSize: '14px' }}>
                        {formatDisplayDate(a.date)}
                      </div>
                      {a.note && (
                        <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '2px' }}>
                          Nota: {a.note}
                        </div>
                      )}
                    </div>
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <label
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: '6px',
                        fontSize: '12px',
                        cursor: 'pointer',
                        color: a.justified ? '#166534' : 'var(--text-muted)',
                      }}
                    >
                      <input
                        type="checkbox"
                        checked={a.justified}
                        onChange={() => handleToggleJustified(a)}
                      />
                      <span>Justificada</span>
                    </label>

                    <button
                      type="button"
                      className="btn-outline"
                      style={{
                        background: 'none',
                        border: 'none',
                        color: 'var(--danger)',
                        cursor: 'pointer',
                        fontSize: '14px',
                        padding: '4px',
                      }}
                      onClick={() => handleDeleteAbsence(a.id)}
                      title="Eliminar registro de falta"
                    >
                      🗑️
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* ========================================================
          PESTAÑA 2: CALIFICACIONES
         ======================================================== */}
      {activeTab === 'grades' && (
        <div>
          {/* Advertencia si los pesos no suman 100% */}
          {!summary.isWeightsSum100 && (
            <div className="alert alert-warning">
              ⚠️ <strong>Atención:</strong> Las evaluaciones suman actualmente{' '}
              <strong>{summary.totalWeight}%</strong>. Para un cálculo exacto de tu calificación final, los porcentajes deben sumar exactamente <strong>100%</strong>.
            </div>
          )}

          <div
            className="card"
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              flexWrap: 'wrap',
              gap: '12px',
            }}
          >
            <div>
              <div style={{ fontSize: '13px', color: 'var(--text-muted)' }}>Criterio de Evaluación</div>
              <div style={{ fontSize: '18px', fontWeight: 700, marginTop: '2px' }}>
                Total ponderado: {summary.totalWeight}%{' '}
                <span style={{ fontSize: '13px', color: 'var(--text-muted)', fontWeight: 400 }}>
                  ({summary.evaluatedWeight}% ya evaluado, {summary.pendingWeight}% pendiente)
                </span>
              </div>
            </div>

            <button type="button" className="btn btn-primary" onClick={openCreateGradeModal}>
              ➕ Nueva Evaluación
            </button>
          </div>

          {grades.length === 0 ? (
            <div className="card" style={{ textAlign: 'center', padding: '32px' }}>
              <div style={{ fontSize: '32px', marginBottom: '8px' }}>📊</div>
              <h4>No hay evaluaciones registradas</h4>
              <p style={{ color: 'var(--text-muted)', fontSize: '13px', margin: '4px 0 16px' }}>
                Agrega los parciales, tareas, prácticas o examen ordinario para llevar el control de tus notas.
              </p>
              <button className="btn btn-primary btn-sm" onClick={openCreateGradeModal}>
                Registrar primer rubro
              </button>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
              {grades.map((g) => (
                <div
                  key={g.id}
                  className="card"
                  style={{
                    margin: 0,
                    padding: '12px 16px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    gap: '12px',
                  }}
                >
                  <div>
                    <div style={{ fontWeight: 600, fontSize: '15px' }}>{g.name}</div>
                    <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '2px' }}>
                      Ponderación: <strong>{g.weight}%</strong> de la calificación final
                    </div>
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                    <div style={{ textAlign: 'right' }}>
                      <div style={{ fontSize: '11px', color: 'var(--text-muted)' }}>Calificación</div>
                      <div
                        style={{
                          fontSize: '16px',
                          fontWeight: 700,
                          color:
                            g.score !== null && g.score !== undefined
                              ? g.score >= subject.passingGrade
                                ? 'var(--success)'
                                : 'var(--danger)'
                              : 'var(--text-muted)',
                        }}
                      >
                        {g.score !== null && g.score !== undefined ? `${g.score} / ${subject.gradeScale}` : 'Pendiente'}
                      </div>
                    </div>

                    <div style={{ display: 'flex', gap: '4px' }}>
                      <button
                        type="button"
                        className="btn btn-secondary btn-sm"
                        onClick={() => openEditGradeModal(g)}
                        title="Editar evaluación"
                      >
                        ✏️
                      </button>
                      <button
                        type="button"
                        className="btn btn-outline btn-sm"
                        style={{ color: 'var(--danger)', borderColor: 'var(--danger)' }}
                        onClick={() => handleDeleteGrade(g.id)}
                        title="Eliminar evaluación"
                      >
                        🗑️
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* ========================================================
          PESTAÑA 3: SIMULADOR "¿Y SI SACO...?"
         ======================================================== */}
      {activeTab === 'simulator' && (
        <div>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))',
              gap: '16px',
              marginBottom: '20px',
            }}
          >
            {/* Promedio actual */}
            <div className="card" style={{ margin: 0, padding: '16px' }}>
              <div style={{ fontSize: '12px', fontWeight: 600, color: 'var(--text-muted)' }}>
                PROMEDIO ACUMULADO
              </div>
              <div style={{ fontSize: '26px', fontWeight: 800, color: 'var(--primary)', marginTop: '4px' }}>
                {summary.currentAverage !== null && summary.currentAverage !== undefined ? Number(summary.currentAverage).toFixed(2) : 'N/A'}
              </div>
              <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>
                Basado en el {summary.evaluatedWeight ?? summary.gradedWeight ?? 0}% evaluado
              </div>
            </div>

            {/* Puntos acumulados */}
            <div className="card" style={{ margin: 0, padding: '16px' }}>
              <div style={{ fontSize: '12px', fontWeight: 600, color: 'var(--text-muted)' }}>
                PUNTOS OBTENIDOS
              </div>
              <div style={{ fontSize: '26px', fontWeight: 800, color: 'var(--text-main)', marginTop: '4px' }}>
                {Number(summary.currentWeightedScore ?? summary.accumulated ?? 0).toFixed(2)} pts
              </div>
              <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>
                De {subject.gradeScale} puntos posibles
              </div>
            </div>

            {/* Necesario para pasar */}
            <div
              className="card"
              style={{
                margin: 0,
                padding: '16px',
                backgroundColor: summary.isImpossible ? '#fee2e2' : summary.isAlreadyPassed ? '#d1fae5' : '#eff6ff',
                borderColor: summary.isImpossible ? '#fca5a5' : summary.isAlreadyPassed ? '#6ee7b7' : '#bfdbfe',
              }}
            >
              <div style={{ fontSize: '12px', fontWeight: 700, color: summary.isImpossible ? '#991b1b' : summary.isAlreadyPassed ? '#065f46' : '#1e40af' }}>
                PARA APROBAR ({subject.passingGrade})
              </div>
              <div style={{ fontSize: '24px', fontWeight: 800, marginTop: '4px' }}>
                {summary.isAlreadyPassed
                  ? '¡Ya aprobaste!'
                  : summary.isImpossible
                  ? 'Inalcanzable'
                  : summary.neededScore !== null && summary.neededScore !== undefined
                  ? `${Number(summary.neededScore).toFixed(2)} promedio`
                  : 'Sin pendientes'}
              </div>
              <div style={{ fontSize: '12px', marginTop: '4px', opacity: 0.85 }}>
                {summary.isAlreadyPassed
                  ? 'Incluso con 0 en lo restante'
                  : summary.isImpossible
                  ? `Faltan puntos sobre escala de ${subject.gradeScale}`
                  : `Necesitas en el ${summary.pendingWeight ?? 0}% pendiente`}
              </div>
            </div>
          </div>

          {/* Sección Interactiva: ¿Y si saco...? */}
          <div className="card" style={{ padding: '24px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '16px' }}>
              <span style={{ fontSize: '24px' }}>🔮</span>
              <div>
                <h3 style={{ fontSize: '18px' }}>Simulador de Nota Final: ¿Y si saco...?</h3>
                <p style={{ color: 'var(--text-muted)', fontSize: '13px' }}>
                  Ajusta la calificación supuesta para el {summary.pendingWeight}% pendiente y observa tu calificación final estimada.
                </p>
              </div>
            </div>

            {summary.pendingWeight === 0 ? (
              <div className="alert alert-info">
                Todas tus evaluaciones registradas ya cuentan con calificación. Si agregas más evaluaciones pendientes, podrás simularlas aquí.
              </div>
            ) : (
              <div>
                <div style={{ marginBottom: '20px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                    <label className="form-label" style={{ margin: 0 }}>
                      Calificación supuesta en rubros pendientes:
                    </label>
                    <span style={{ fontSize: '20px', fontWeight: 800, color: 'var(--primary)' }}>
                      {Number(simulatedScore).toFixed(1)} / {subject.gradeScale}
                    </span>
                  </div>

                  <input
                    type="range"
                    min="0"
                    max={subject.gradeScale}
                    step="0.1"
                    value={simulatedScore}
                    onChange={(e) => setSimulatedScore(e.target.value)}
                    style={{ width: '100%', cursor: 'pointer', accentColor: 'var(--primary)' }}
                  />
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '11px', color: 'var(--text-muted)' }}>
                    <span>0 (Mínima)</span>
                    <span>{subject.passingGrade} (Aprobatoria)</span>
                    <span>{subject.gradeScale} (Máxima)</span>
                  </div>
                </div>

                <div
                  style={{
                    padding: '20px',
                    borderRadius: '8px',
                    backgroundColor: projectedFinalGrade >= subject.passingGrade ? '#f0fdf4' : '#fef2f2',
                    border: `1px solid ${projectedFinalGrade >= subject.passingGrade ? '#bbf7d0' : '#fecaca'}`,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    flexWrap: 'wrap',
                    gap: '16px',
                  }}
                >
                  <div>
                    <div style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-muted)' }}>
                      CALIFICACIÓN FINAL ESTIMADA:
                    </div>
                    <div
                      style={{
                        fontSize: '32px',
                        fontWeight: 900,
                        color: (projectedFinalGrade ?? 0) >= subject.passingGrade ? '#15803d' : '#b91c1c',
                      }}
                    >
                      {Number(projectedFinalGrade ?? 0).toFixed(2)}{' '}
                      <span style={{ fontSize: '16px', fontWeight: 500 }}>
                        {(projectedFinalGrade ?? 0) >= subject.passingGrade ? '— ¡Aprobado! 🎉' : '— No aprobado ⚠️'}
                      </span>
                    </div>
                  </div>

                  <div style={{ fontSize: '13px', color: 'var(--text-muted)', maxWidth: '300px' }}>
                    Si obtienes un <strong>{Number(simulatedScore).toFixed(1)}</strong> en las evaluaciones pendientes, tu promedio final ponderado del semestre será de <strong>{Number(projectedFinalGrade ?? 0).toFixed(2)}</strong>.
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ========================================================
          MODALES
         ======================================================== */}
      {/* Modal Registrar Falta */}
      <Modal
        isOpen={absenceModalOpen}
        onClose={() => setAbsenceModalOpen(false)}
        title="Registrar Falta en Asignatura"
      >
        <form onSubmit={handleSaveAbsence}>
          <div className="form-group">
            <label className="form-label" htmlFor="absenceDate">
              Fecha de la falta *
            </label>
            <input
              id="absenceDate"
              type="date"
              className="form-input"
              value={absenceForm.date}
              onChange={(e) => setAbsenceForm({ ...absenceForm, date: e.target.value })}
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="absenceNote">
              Nota o motivo (opcional)
            </label>
            <input
              id="absenceNote"
              type="text"
              className="form-input"
              placeholder="Ej. Cita médica, transporte demorado..."
              value={absenceForm.note}
              onChange={(e) => setAbsenceForm({ ...absenceForm, note: e.target.value })}
            />
          </div>

          <div className="form-group">
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', fontSize: '14px' }}>
              <input
                type="checkbox"
                checked={absenceForm.justified}
                onChange={(e) => setAbsenceForm({ ...absenceForm, justified: e.target.checked })}
              />
              <span>Falta Justificada (con comprobante escolar)</span>
            </label>
          </div>

          <div className="modal-actions">
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => setAbsenceModalOpen(false)}
              disabled={submittingAbsence}
            >
              Cancelar
            </button>
            <button type="submit" className="btn btn-primary" disabled={submittingAbsence}>
              {submittingAbsence ? 'Guardando...' : 'Registrar Falta'}
            </button>
          </div>
        </form>
      </Modal>

      {/* Modal Crear / Editar Calificación */}
      <Modal
        isOpen={gradeModalOpen}
        onClose={() => setGradeModalOpen(false)}
        title={editingGrade ? 'Editar Evaluación' : 'Nueva Evaluación'}
      >
        {gradeFormError && <div className="alert alert-danger">{gradeFormError}</div>}

        <form onSubmit={handleSaveGrade}>
          <div className="form-group">
            <label className="form-label" htmlFor="gradeName">
              Nombre de la Evaluación *
            </label>
            <input
              id="gradeName"
              type="text"
              className="form-input"
              placeholder="Ej. Primer Parcial, Proyecto, Examen Final"
              value={gradeForm.name}
              onChange={(e) => setGradeForm({ ...gradeForm, name: e.target.value })}
              required
            />
          </div>

          <div className="form-row">
            <div className="form-group">
              <label className="form-label" htmlFor="gradeWeight">
                Porcentaje / Ponderación (%) *
              </label>
              <input
                id="gradeWeight"
                type="number"
                min="1"
                max="100"
                step="1"
                className="form-input"
                placeholder="Ej. 30"
                value={gradeForm.weight}
                onChange={(e) => setGradeForm({ ...gradeForm, weight: e.target.value })}
                required
              />
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="gradeScore">
                Calificación obtenida (opcional)
              </label>
              <input
                id="gradeScore"
                type="number"
                min="0"
                max={subject.gradeScale}
                step="0.01"
                className="form-input"
                placeholder={`0 a ${subject.gradeScale} (vacío si está pendiente)`}
                value={gradeForm.score}
                onChange={(e) => setGradeForm({ ...gradeForm, score: e.target.value })}
              />
            </div>
          </div>

          <div className="modal-actions">
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => setGradeModalOpen(false)}
              disabled={submittingGrade}
            >
              Cancelar
            </button>
            <button type="submit" className="btn btn-primary" disabled={submittingGrade}>
              {submittingGrade ? 'Guardando...' : editingGrade ? 'Actualizar' : 'Guardar Evaluación'}
            </button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
