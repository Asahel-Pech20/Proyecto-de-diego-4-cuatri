import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import {
  getSubjects,
  createSubject,
  updateSubject,
  deleteSubject,
} from '../api';
import { Modal } from '../components/Modal';

const PRESET_COLORS = [
  '#7a1c2e', // UTM Wine
  '#1e40af', // Blue
  '#059669', // Emerald
  '#d97706', // Amber
  '#7c3aed', // Purple
  '#0891b2', // Cyan
  '#db2777', // Pink
  '#4b5563', // Slate
];

export function Subjects() {
  const [subjects, setSubjects] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Modal crear/editar
  const [modalOpen, setModalOpen] = useState(false);
  const [editingSubject, setEditingSubject] = useState(null);
  const [formData, setFormData] = useState({
    name: '',
    teacher: '',
    color: '#7a1c2e',
    maxAbsences: '',
    passingGrade: 6.0,
    gradeScale: 10.0,
  });
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState('');

  // Modal advertencia de eliminación
  const [deleteModalOpen, setDeleteModalOpen] = useState(false);
  const [subjectToDelete, setSubjectToDelete] = useState(null);

  const loadData = async () => {
    try {
      setLoading(true);
      setError('');
      const data = await getSubjects();
      setSubjects(data || []);
    } catch (err) {
      setError(err.message || 'Error al cargar materias');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const openCreateModal = () => {
    setEditingSubject(null);
    setFormData({
      name: '',
      teacher: '',
      color: PRESET_COLORS[subjects.length % PRESET_COLORS.length],
      maxAbsences: '',
      passingGrade: 6.0,
      gradeScale: 10.0,
    });
    setFormError('');
    setModalOpen(true);
  };

  const openEditModal = (s) => {
    setEditingSubject(s);
    setFormData({
      name: s.name,
      teacher: s.teacher || '',
      color: s.color || '#7a1c2e',
      maxAbsences: s.maxAbsences !== null && s.maxAbsences !== undefined ? String(s.maxAbsences) : '',
      passingGrade: s.passingGrade ?? 6.0,
      gradeScale: s.gradeScale ?? 10.0,
    });
    setFormError('');
    setModalOpen(true);
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setFormError('');

    if (!formData.name.trim()) {
      setFormError('El nombre de la materia es obligatorio');
      return;
    }

    const maxAbsencesVal = formData.maxAbsences.trim() === '' ? null : Number(formData.maxAbsences);
    const teacherVal = formData.teacher.trim() === '' ? null : formData.teacher.trim();
    const colorVal = formData.color.trim() === '' ? null : formData.color.trim();

    try {
      setSubmitting(true);
      if (editingSubject) {
        const changes = {
          name: formData.name.trim(),
          teacher: teacherVal,
          color: colorVal,
          maxAbsences: maxAbsencesVal,
          passingGrade: Number(formData.passingGrade),
          gradeScale: Number(formData.gradeScale),
        };
        const updated = await updateSubject(editingSubject.id, changes);
        setSubjects((prev) => prev.map((s) => (s.id === editingSubject.id ? updated : s)));
      } else {
        const payload = {
          name: formData.name.trim(),
          teacher: teacherVal,
          color: colorVal,
          maxAbsences: maxAbsencesVal,
          passingGrade: Number(formData.passingGrade),
          gradeScale: Number(formData.gradeScale),
        };
        const created = await createSubject(payload);
        setSubjects((prev) => [...prev, created]);
      }
      setModalOpen(false);
    } catch (err) {
      setFormError(err.message || 'Error al guardar materia');
    } finally {
      setSubmitting(false);
    }
  };

  const confirmDelete = (s) => {
    setSubjectToDelete(s);
    setDeleteModalOpen(true);
  };

  const handleDelete = async () => {
    if (!subjectToDelete) return;
    try {
      setSubmitting(true);
      await deleteSubject(subjectToDelete.id);
      setSubjects((prev) => prev.filter((s) => s.id !== subjectToDelete.id));
      setDeleteModalOpen(false);
      setSubjectToDelete(null);
    } catch (err) {
      alert(`Error al eliminar materia: ${err.message}`);
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <div className="loading-container">
        <div className="spinner spinner-dark" />
        <p>Cargando lista de materias...</p>
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
          <h1 style={{ fontSize: '24px' }}>Mis Materias</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '14px' }}>
            Gestiona tus asignaturas, profesores, faltas y calificaciones del semestre
          </p>
        </div>
        <button className="btn btn-primary" onClick={openCreateModal}>
          ➕ Nueva Materia
        </button>
      </div>

      {error && <div className="alert alert-danger">{error}</div>}

      {subjects.length === 0 ? (
        <div className="card" style={{ textAlign: 'center', padding: '40px 20px' }}>
          <div style={{ fontSize: '40px', marginBottom: '12px' }}>📚</div>
          <h3>Aún no tienes materias registradas</h3>
          <p style={{ color: 'var(--text-muted)', margin: '8px 0 20px' }}>
            Registra tus asignaturas para poder agregar clases a tu horario, tareas, controlar tus faltas y simular calificaciones.
          </p>
          <button className="btn btn-primary" onClick={openCreateModal}>
            Registrar mi primera materia
          </button>
        </div>
      ) : (
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))',
            gap: '20px',
          }}
        >
          {subjects.map((s) => {
            const cardColor = s.color || 'var(--primary)';
            return (
              <div
                key={s.id}
                className="card"
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  justifyContent: 'space-between',
                  borderTop: `6px solid ${cardColor}`,
                  margin: 0,
                  transition: 'transform 0.15s ease, box-shadow 0.15s ease',
                }}
              >
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '8px' }}>
                    <h3 style={{ fontSize: '18px', color: 'var(--text-main)', wordBreak: 'break-word' }}>
                      {s.name}
                    </h3>
                  </div>

                  {s.teacher ? (
                    <div style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
                      👨‍🏫 Prof. {s.teacher}
                    </div>
                  ) : (
                    <div style={{ fontSize: '13px', color: '#9ca3af', fontStyle: 'italic', marginTop: '4px' }}>
                      Docente no asignado
                    </div>
                  )}

                  <div
                    style={{
                      display: 'grid',
                      gridTemplateColumns: '1fr 1fr',
                      gap: '8px',
                      marginTop: '16px',
                      padding: '10px',
                      backgroundColor: '#f9fafb',
                      borderRadius: '8px',
                      fontSize: '12px',
                    }}
                  >
                    <div>
                      <span style={{ color: 'var(--text-muted)' }}>Mín. Aprobatoria:</span>
                      <div style={{ fontWeight: 700, fontSize: '14px' }}>
                        {s.passingGrade} / {s.gradeScale}
                      </div>
                    </div>
                    <div>
                      <span style={{ color: 'var(--text-muted)' }}>Límite de Faltas:</span>
                      <div style={{ fontWeight: 700, fontSize: '14px' }}>
                        {s.maxAbsences !== null && s.maxAbsences !== undefined ? `${s.maxAbsences} faltas` : 'Sin límite'}
                      </div>
                    </div>
                  </div>
                </div>

                <div
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    marginTop: '20px',
                    paddingTop: '14px',
                    borderTop: '1px solid var(--border)',
                  }}
                >
                  <Link to={`/materias/${s.id}`} className="btn btn-primary btn-sm">
                    📊 Faltas y Notas
                  </Link>

                  <div style={{ display: 'flex', gap: '6px' }}>
                    <button
                      type="button"
                      className="btn btn-secondary btn-sm"
                      onClick={() => openEditModal(s)}
                      title="Editar materia"
                    >
                      ✏️
                    </button>
                    <button
                      type="button"
                      className="btn btn-outline btn-sm"
                      style={{ color: 'var(--danger)', borderColor: 'var(--danger)' }}
                      onClick={() => confirmDelete(s)}
                      title="Eliminar materia"
                    >
                      🗑️
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Modal Crear / Editar Materia */}
      <Modal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        title={editingSubject ? 'Editar Materia' : 'Nueva Materia'}
      >
        {formError && <div className="alert alert-danger">{formError}</div>}

        <form onSubmit={handleSave}>
          <div className="form-group">
            <label className="form-label" htmlFor="subjectName">
              Nombre de la Materia *
            </label>
            <input
              id="subjectName"
              type="text"
              className="form-input"
              placeholder="Ej. Redes de Computadoras"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="subjectTeacher">
              Profesor / Docente (opcional)
            </label>
            <input
              id="subjectTeacher"
              type="text"
              className="form-input"
              placeholder="Ej. Dr. Mario Santos"
              value={formData.teacher}
              onChange={(e) => setFormData({ ...formData, teacher: e.target.value })}
            />
          </div>

          <div className="form-group">
            <label className="form-label">Color distintivo</label>
            <div style={{ display: 'flex', gap: '8px', alignItems: 'center', flexWrap: 'wrap' }}>
              {PRESET_COLORS.map((c) => (
                <button
                  key={c}
                  type="button"
                  onClick={() => setFormData({ ...formData, color: c })}
                  style={{
                    width: '30px',
                    height: '30px',
                    borderRadius: '50%',
                    backgroundColor: c,
                    border: formData.color === c ? '3px solid #111827' : '1px solid rgba(0,0,0,0.1)',
                    cursor: 'pointer',
                    outline: 'none',
                  }}
                  title={c}
                />
              ))}
              <input
                type="color"
                value={formData.color}
                onChange={(e) => setFormData({ ...formData, color: e.target.value })}
                style={{ width: '36px', height: '32px', cursor: 'pointer', border: 'none', background: 'none' }}
                title="Color personalizado"
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label className="form-label" htmlFor="maxAbsences">
                Límite de Faltas (opcional)
              </label>
              <input
                id="maxAbsences"
                type="number"
                min="1"
                className="form-input"
                placeholder="Ej. 6"
                value={formData.maxAbsences}
                onChange={(e) => setFormData({ ...formData, maxAbsences: e.target.value })}
              />
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="passingGrade">
                Calificación Mínima Aprobatoria *
              </label>
              <input
                id="passingGrade"
                type="number"
                step="0.1"
                min="0"
                max="100"
                className="form-input"
                value={formData.passingGrade}
                onChange={(e) => setFormData({ ...formData, passingGrade: e.target.value })}
                required
              />
            </div>
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="gradeScale">
              Escala de Calificación Máxima *
            </label>
            <input
              id="gradeScale"
              type="number"
              step="0.1"
              min="1"
              max="100"
              className="form-input"
              value={formData.gradeScale}
              onChange={(e) => setFormData({ ...formData, gradeScale: e.target.value })}
              required
            />
          </div>

          <div className="modal-actions">
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => setModalOpen(false)}
              disabled={submitting}
            >
              Cancelar
            </button>
            <button type="submit" className="btn btn-primary" disabled={submitting}>
              {submitting ? 'Guardando...' : editingSubject ? 'Actualizar' : 'Crear Materia'}
            </button>
          </div>
        </form>
      </Modal>

      {/* Modal Advertencia de Eliminación en Cascada */}
      <Modal
        isOpen={deleteModalOpen}
        onClose={() => setDeleteModalOpen(false)}
        title="⚠️ Confirmar eliminación de materia"
      >
        <div style={{ color: 'var(--text-main)', fontSize: '14px' }}>
          <p style={{ marginBottom: '12px' }}>
            ¿Estás seguro de que deseas eliminar la materia{' '}
            <strong>"{subjectToDelete?.name}"</strong>?
          </p>
          <div className="alert alert-danger" style={{ fontSize: '13px' }}>
            <strong>¡Atención!</strong> Esta acción eliminará permanentemente:
            <ul style={{ paddingLeft: '20px', marginTop: '6px' }}>
              <li>Todas las clases de su horario semanal</li>
              <li>Todas sus tareas y exámenes asociados</li>
              <li>El registro de faltas</li>
              <li>Todas sus calificaciones y evaluaciones</li>
            </ul>
          </div>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
            Esta acción no se puede deshacer en el servidor.
          </p>
        </div>

        <div className="modal-actions">
          <button
            type="button"
            className="btn btn-secondary"
            onClick={() => setDeleteModalOpen(false)}
            disabled={submitting}
          >
            Cancelar
          </button>
          <button
            type="button"
            className="btn btn-danger"
            onClick={handleDelete}
            disabled={submitting}
          >
            {submitting ? 'Eliminando...' : 'Sí, eliminar materia y datos'}
          </button>
        </div>
      </Modal>
    </div>
  );
}
