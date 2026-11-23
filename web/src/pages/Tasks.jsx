import React, { useState, useEffect } from 'react';
import {
  getSubjects,
  getTasks,
  createTask,
  updateTask,
  deleteTask,
  uploadPhoto,
} from '../api';
import { Modal } from '../components/Modal';
import { AuthPhoto } from '../components/AuthPhoto';
import {
  datetimeLocalToIso,
  isoToDatetimeLocal,
  formatDisplayDateTime,
  buildTaskPayload,
} from '../utils';

const REMINDER_OPTIONS = [
  { label: '10 min antes', value: 10 },
  { label: '30 min antes', value: 30 },
  { label: '1 hora antes', value: 60 },
  { label: '2 horas antes', value: 120 },
  { label: '1 día antes', value: 1440 },
];

export function Tasks() {
  const [subjects, setSubjects] = useState([]);
  const [tasks, setTasks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Filtros
  const [filterType, setFilterType] = useState('all'); // all, tasks, exams
  const [filterStatus, setFilterStatus] = useState('all'); // all, pending, completed
  const [filterSubject, setFilterSubject] = useState('all');

  // Modal de tarea (crear/editar)
  const [modalOpen, setModalOpen] = useState(false);
  const [editingTask, setEditingTask] = useState(null);
  const [formData, setFormData] = useState({
    subjectId: '',
    title: '',
    description: '',
    kind: 'task',
    dueAt: '', // datetime-local format
    photoUrl: null,
    reminders: [],
  });
  const [selectedFile, setSelectedFile] = useState(null);
  const [uploadingPhoto, setUploadingPhoto] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState('');

  // Modal para vista previa de imagen grande
  const [previewPhotoUrl, setPreviewPhotoUrl] = useState(null);

  const loadData = async () => {
    try {
      setLoading(true);
      setError('');
      const [subjectsData, tasksData] = await Promise.all([
        getSubjects(),
        getTasks(),
      ]);
      setSubjects(subjectsData || []);
      setTasks(tasksData || []);
    } catch (err) {
      setError(err.message || 'Error al cargar tareas');
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

  const openCreateModal = () => {
    if (subjects.length === 0) {
      alert('Primero debes registrar al menos una materia para asignar tareas.');
      return;
    }
    // Hora por defecto: mañana a las 12:00
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(12, 0, 0, 0);

    setEditingTask(null);
    setSelectedFile(null);
    setFormData({
      subjectId: subjects[0]?.id || '',
      title: '',
      description: '',
      kind: 'task',
      dueAt: isoToDatetimeLocal(tomorrow.toISOString()),
      photoUrl: null,
      reminders: [30],
    });
    setFormError('');
    setModalOpen(true);
  };

  const openEditModal = (task) => {
    setEditingTask(task);
    setSelectedFile(null);
    setFormData({
      subjectId: task.subjectId,
      title: task.title,
      description: task.description || '',
      kind: task.kind || (task.isExam ? 'exam' : 'task'),
      dueAt: isoToDatetimeLocal(task.dueAt),
      photoUrl: task.photoUrl || null,
      reminders: Array.isArray(task.reminders) ? [...task.reminders] : [],
    });
    setFormError('');
    setModalOpen(true);
  };

  const handleToggleDone = async (task) => {
    try {
      const updated = await updateTask(task.id, { done: !task.done });
      setTasks((prev) => prev.map((t) => (t.id === task.id ? updated : t)));
    } catch (err) {
      alert(`Error al actualizar estado: ${err.message}`);
    }
  };

  const handleFileChange = (e) => {
    if (e.target.files && e.target.files[0]) {
      setSelectedFile(e.target.files[0]);
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setFormError('');

    if (!formData.title.trim()) {
      setFormError('El título es obligatorio');
      return;
    }
    if (!formData.subjectId) {
      setFormError('Selecciona una materia');
      return;
    }
    if (!formData.dueAt) {
      setFormError('Indica la fecha y hora de entrega');
      return;
    }

    try {
      setSubmitting(true);

      let finalPhotoUrl = formData.photoUrl;

      // Si seleccionó un archivo nuevo, subirlo primero
      if (selectedFile) {
        setUploadingPhoto(true);
        const uploadRes = await uploadPhoto(selectedFile);
        finalPhotoUrl = uploadRes.url;
        setUploadingPhoto(false);
      }

      const taskPayload = buildTaskPayload({
        ...formData,
        photoUrl: finalPhotoUrl || null,
      });

      if (editingTask) {
        const updated = await updateTask(editingTask.id, taskPayload);
        setTasks((prev) => prev.map((t) => (t.id === editingTask.id ? updated : t)));
      } else {
        const created = await createTask(taskPayload);
        setTasks((prev) => [created, ...prev]);
      }
      setModalOpen(false);
    } catch (err) {
      setFormError(err.message || 'Error al guardar tarea');
    } finally {
      setSubmitting(false);
      setUploadingPhoto(false);
    }
  };

  const handleDelete = async () => {
    if (!editingTask) return;
    if (!window.confirm(`¿Seguro que deseas eliminar "${editingTask.title}"?`)) return;

    try {
      setSubmitting(true);
      await deleteTask(editingTask.id);
      setTasks((prev) => prev.filter((t) => t.id !== editingTask.id));
      setModalOpen(false);
    } catch (err) {
      setFormError(err.message || 'Error al eliminar');
    } finally {
      setSubmitting(false);
    }
  };

  const toggleReminder = (val) => {
    const exists = formData.reminders.includes(val);
    const updated = exists
      ? formData.reminders.filter((r) => r !== val)
      : [...formData.reminders, val].sort((a, b) => a - b);
    setFormData({ ...formData, reminders: updated });
  };

  // Filtrado de la lista
  const nowTime = new Date().getTime();
  const isTaskExam = (t) => t.kind === 'exam' || t.isExam;
  const filteredTasks = tasks.filter((t) => {
    if (filterType === 'tasks' && isTaskExam(t)) return false;
    if (filterType === 'exams' && !isTaskExam(t)) return false;

    if (filterStatus === 'pending' && t.done) return false;
    if (filterStatus === 'completed' && !t.done) return false;

    if (filterSubject !== 'all' && t.subjectId !== filterSubject) return false;

    return true;
  });

  if (loading) {
    return (
      <div className="loading-container">
        <div className="spinner spinner-dark" />
        <p>Cargando tareas y exámenes...</p>
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
          <h1 style={{ fontSize: '24px' }}>Tareas y Exámenes</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '14px' }}>
            Gestiona tus entregas, exámenes y evidencias fotográficas
          </p>
        </div>
        <button className="btn btn-primary" onClick={openCreateModal}>
          ➕ Nueva Tarea o Examen
        </button>
      </div>

      {error && <div className="alert alert-danger">{error}</div>}

      {/* Barra de Filtros */}
      <div
        className="card"
        style={{
          padding: '12px 16px',
          marginBottom: '20px',
          display: 'flex',
          gap: '16px',
          flexWrap: 'wrap',
          alignItems: 'center',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ fontSize: '13px', fontWeight: 600 }}>Tipo:</span>
          <select
            className="form-select"
            style={{ width: 'auto', padding: '6px 10px', fontSize: '13px' }}
            value={filterType}
            onChange={(e) => setFilterType(e.target.value)}
          >
            <option value="all">Todos</option>
            <option value="tasks">Solo Tareas</option>
            <option value="exams">Solo Exámenes</option>
          </select>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ fontSize: '13px', fontWeight: 600 }}>Estado:</span>
          <select
            className="form-select"
            style={{ width: 'auto', padding: '6px 10px', fontSize: '13px' }}
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
          >
            <option value="all">Todas</option>
            <option value="pending">Pendientes</option>
            <option value="completed">Completadas</option>
          </select>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ fontSize: '13px', fontWeight: 600 }}>Materia:</span>
          <select
            className="form-select"
            style={{ width: 'auto', padding: '6px 10px', fontSize: '13px' }}
            value={filterSubject}
            onChange={(e) => setFilterSubject(e.target.value)}
          >
            <option value="all">Todas las materias</option>
            {subjects.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </select>
        </div>

        <div style={{ marginLeft: 'auto', fontSize: '13px', color: 'var(--text-muted)' }}>
          Mostrando {filteredTasks.length} de {tasks.length}
        </div>
      </div>

      {/* Lista de Tareas */}
      {filteredTasks.length === 0 ? (
        <div className="card" style={{ textAlign: 'center', padding: '40px 20px' }}>
          <div style={{ fontSize: '40px', marginBottom: '12px' }}>📋</div>
          <h3>No se encontraron tareas o exámenes</h3>
          <p style={{ color: 'var(--text-muted)', margin: '8px 0 16px' }}>
            No hay pendientes que coincidan con los filtros seleccionados.
          </p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          {filteredTasks.map((t) => {
            const subj = subjectsMap[t.subjectId];
            const isOverdue = !t.done && t.dueAt && new Date(t.dueAt).getTime() < nowTime;

            return (
              <div
                key={t.id}
                className="card"
                style={{
                  margin: 0,
                  padding: '16px',
                  display: 'flex',
                  alignItems: 'flex-start',
                  justifyContent: 'space-between',
                  gap: '16px',
                  borderLeft: `5px solid ${isOverdue ? 'var(--danger)' : subj?.color || 'var(--primary)'}`,
                  opacity: t.done ? 0.75 : 1,
                  backgroundColor: t.done ? '#fafafa' : '#ffffff',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'flex-start', gap: '14px', flex: 1 }}>
                  <input
                    type="checkbox"
                    checked={t.done}
                    onChange={() => handleToggleDone(t)}
                    style={{ width: '20px', height: '20px', marginTop: '3px', cursor: 'pointer' }}
                    title={t.done ? 'Marcar como pendiente' : 'Marcar como completada'}
                  />
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                      <span
                        style={{
                          fontWeight: 700,
                          fontSize: '16px',
                          textDecoration: t.done ? 'line-through' : 'none',
                          color: 'var(--text-main)',
                        }}
                      >
                        {t.title}
                      </span>
                      <span className={t.kind === 'exam' || t.isExam ? 'badge badge-exam' : 'badge badge-task'}>
                        {t.kind === 'exam' || t.isExam ? 'Examen' : 'Tarea'}
                      </span>
                      {isOverdue && (
                        <span className="badge" style={{ backgroundColor: '#fee2e2', color: '#991b1b' }}>
                          ⚠️ Vencida
                        </span>
                      )}
                    </div>

                    {t.description && (
                      <p
                        style={{
                          fontSize: '13px',
                          color: 'var(--text-muted)',
                          margin: '4px 0 8px',
                          whiteSpace: 'pre-wrap',
                        }}
                      >
                        {t.description}
                      </p>
                    )}

                    <div
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: '12px',
                        fontSize: '12px',
                        color: 'var(--text-muted)',
                        flexWrap: 'wrap',
                        marginTop: '6px',
                      }}
                    >
                      {subj && (
                        <span style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
                          <span
                            style={{
                              width: '9px',
                              height: '9px',
                              borderRadius: '50%',
                              backgroundColor: subj.color || 'var(--primary)',
                            }}
                          />
                          <strong style={{ color: 'var(--text-main)' }}>{subj.name}</strong>
                        </span>
                      )}
                      <span>📅 Entrega: {formatDisplayDateTime(t.dueAt)}</span>
                      {Array.isArray(t.reminders) && t.reminders.length > 0 && (
                        <span>🔔 {t.reminders.length} recordatorio(s)</span>
                      )}
                    </div>
                  </div>
                </div>

                {/* Foto y botón editar */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  {t.photoUrl && (
                    <div
                      title="Ver foto de la tarea"
                      onClick={() => setPreviewPhotoUrl(t.photoUrl)}
                      style={{ cursor: 'pointer' }}
                    >
                      <AuthPhoto
                        photoPath={t.photoUrl}
                        alt="Foto tarea"
                        style={{ width: '48px', height: '48px', borderRadius: '6px', border: '1px solid var(--border)' }}
                      />
                    </div>
                  )}
                  <button
                    className="btn btn-secondary btn-sm"
                    onClick={() => openEditModal(t)}
                  >
                    ✏️ Editar
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Modal Crear / Editar Tarea */}
      <Modal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        title={editingTask ? 'Editar Tarea / Examen' : 'Nueva Tarea o Examen'}
      >
        {formError && <div className="alert alert-danger">{formError}</div>}

        <form onSubmit={handleSave}>
          <div className="form-group">
            <label className="form-label" htmlFor="taskSubjectId">
              Materia *
            </label>
            <select
              id="taskSubjectId"
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
            <label className="form-label" htmlFor="taskTitle">
              Título *
            </label>
            <input
              id="taskTitle"
              type="text"
              className="form-input"
              placeholder="Ej. Tarea 3: Álgebra Lineal"
              value={formData.title}
              onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="taskDescription">
              Descripción o notas (opcional)
            </label>
            <textarea
              id="taskDescription"
              className="form-textarea"
              rows={3}
              placeholder="Detalles sobre los ejercicios, páginas del libro o instrucciones..."
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
            />
          </div>

          <div className="form-row">
            <div className="form-group">
              <label className="form-label" htmlFor="taskKind">
                Tipo *
              </label>
              <select
                id="taskKind"
                className="form-select"
                value={formData.kind}
                onChange={(e) => setFormData({ ...formData, kind: e.target.value })}
              >
                <option value="task">📝 Tarea</option>
                <option value="exam">🎯 Examen</option>
              </select>
            </div>

            <div className="form-group">
              <label className="form-label" htmlFor="taskDueAt">
                Fecha y Hora de Entrega *
              </label>
              <input
                id="taskDueAt"
                type="datetime-local"
                className="form-input"
                value={formData.dueAt}
                onChange={(e) => setFormData({ ...formData, dueAt: e.target.value })}
                required
              />
            </div>
          </div>

          {/* Subida y gestión de foto */}
          <div className="form-group">
            <label className="form-label">Foto adjunta (pizarrón, temario, hoja)</label>
            {formData.photoUrl && !selectedFile && (
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '8px' }}>
                <AuthPhoto
                  photoPath={formData.photoUrl}
                  style={{ width: '60px', height: '60px', borderRadius: '6px' }}
                />
                <button
                  type="button"
                  className="btn btn-outline btn-sm"
                  style={{ color: 'var(--danger)', borderColor: 'var(--danger)' }}
                  onClick={() => setFormData({ ...formData, photoUrl: null })}
                >
                  Quitar foto actual
                </button>
              </div>
            )}
            <input
              type="file"
              accept="image/jpeg,image/png,image/webp,image/heic"
              className="form-input"
              onChange={handleFileChange}
            />
            {selectedFile && (
              <div style={{ fontSize: '12px', color: 'var(--success)', marginTop: '4px' }}>
                Archivo listo para subir: {selectedFile.name} ({(selectedFile.size / 1024).toFixed(1)} KB)
              </div>
            )}
          </div>

          {/* Recordatorios */}
          <div className="form-group">
            <label className="form-label">Recordatorios previos</label>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
              {REMINDER_OPTIONS.map((opt) => {
                const checked = formData.reminders.includes(opt.value);
                return (
                  <button
                    key={opt.value}
                    type="button"
                    onClick={() => toggleReminder(opt.value)}
                    className={checked ? 'btn btn-primary btn-sm' : 'btn btn-secondary btn-sm'}
                    style={{ fontSize: '12px' }}
                  >
                    {checked ? '✓ ' : '+ '} {opt.label}
                  </button>
                );
              })}
            </div>
          </div>

          <div className="modal-actions" style={{ justifyContent: editingTask ? 'space-between' : 'flex-end' }}>
            {editingTask && (
              <button
                type="button"
                className="btn btn-danger"
                onClick={handleDelete}
                disabled={submitting}
              >
                Eliminar
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
                {submitting
                  ? uploadingPhoto
                    ? 'Subiendo foto...'
                    : 'Guardando...'
                  : editingTask
                  ? 'Actualizar'
                  : 'Crear'}
              </button>
            </div>
          </div>
        </form>
      </Modal>

      {/* Modal Visor de Imagen Grande */}
      <Modal
        isOpen={Boolean(previewPhotoUrl)}
        onClose={() => setPreviewPhotoUrl(null)}
        title="Vista previa de foto adjunta"
      >
        <div style={{ textAlign: 'center' }}>
          {previewPhotoUrl && (
            <AuthPhoto
              photoPath={previewPhotoUrl}
              alt="Foto completa"
              style={{ maxWidth: '100%', maxHeight: '70vh', borderRadius: '8px' }}
            />
          )}
          <div style={{ marginTop: '16px' }}>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={() => setPreviewPhotoUrl(null)}
            >
              Cerrar visor
            </button>
          </div>
        </div>
      </Modal>
    </div>
  );
}
