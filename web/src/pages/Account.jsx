import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Modal } from '../components/Modal';

export function Account() {
  const { user, logout, deleteAccount } = useAuth();
  const navigate = useNavigate();

  const [deleteModalOpen, setDeleteModalOpen] = useState(false);
  const [confirmationText, setConfirmationText] = useState('');
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState('');

  const CONFIRM_KEYWORD = 'BORRAR MI CUENTA';

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const handleDeleteAccount = async () => {
    if (confirmationText.trim() !== CONFIRM_KEYWORD) {
      setError(`Debes escribir exactamente "${CONFIRM_KEYWORD}" para confirmar.`);
      return;
    }

    try {
      setDeleting(true);
      setError('');
      await deleteAccount();
      navigate('/login');
    } catch (err) {
      setError(err.message || 'Error al eliminar la cuenta');
      setDeleting(false);
    }
  };

  return (
    <div style={{ maxWidth: '640px', margin: '0 auto' }}>
      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '24px' }}>Mi Cuenta de Estudiante</h1>
        <p style={{ color: 'var(--text-muted)', fontSize: '14px' }}>
          Información del perfil y configuración de seguridad
        </p>
      </div>

      {/* Tarjeta de Información del Usuario */}
      <div className="card">
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px', marginBottom: '20px' }}>
          <div
            style={{
              width: '64px',
              height: '64px',
              borderRadius: '50%',
              backgroundColor: 'var(--primary)',
              color: '#ffffff',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '28px',
              fontWeight: 700,
            }}
          >
            {user?.name ? user.name[0].toUpperCase() : 'U'}
          </div>
          <div>
            <h2 style={{ fontSize: '18px' }}>{user?.name || 'Estudiante'}</h2>
            <div style={{ color: 'var(--text-muted)', fontSize: '14px' }}>{user?.email || ''}</div>
          </div>
        </div>

        <div
          style={{
            borderTop: '1px solid var(--border)',
            paddingTop: '16px',
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gap: '12px',
            fontSize: '13px',
          }}
        >
          <div>
            <span style={{ color: 'var(--text-muted)' }}>Identificador de usuario:</span>
            <div style={{ fontFamily: 'monospace', fontSize: '11px', marginTop: '2px', wordBreak: 'break-all' }}>
              {user?.id || '—'}
            </div>
          </div>
          <div>
            <span style={{ color: 'var(--text-muted)' }}>Servidor conectado:</span>
            <div style={{ fontWeight: 600, marginTop: '2px' }}>
              {import.meta.env.VITE_API_URL || 'http://localhost:3000'}
            </div>
          </div>
        </div>

        <div style={{ marginTop: '24px', display: 'flex', justifyContent: 'flex-end' }}>
          <button type="button" className="btn btn-secondary" onClick={handleLogout}>
            Cerrar Sesión
          </button>
        </div>
      </div>

      {/* Zona de Peligro: Borrar Cuenta */}
      <div className="card" style={{ borderLeft: '5px solid var(--danger)', marginTop: '32px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '10px' }}>
          <span style={{ fontSize: '20px' }}>⚠️</span>
          <h3 style={{ fontSize: '16px', color: '#991b1b' }}>Zona de Peligro</h3>
        </div>
        <p style={{ fontSize: '14px', color: 'var(--text-main)', marginBottom: '16px' }}>
          Eliminar tu cuenta borrará de forma irreversible y permanente todos tus datos en el servidor, incluyendo todas tus materias, clases del horario, tareas, exámenes, fotos, asistencias y calificaciones.
        </p>

        <button
          type="button"
          className="btn btn-danger"
          onClick={() => {
            setConfirmationText('');
            setError('');
            setDeleteModalOpen(true);
          }}
        >
          Borrar definitivamente mi cuenta
        </button>
      </div>

      {/* Modal Confirmación de Borrado */}
      <Modal
        isOpen={deleteModalOpen}
        onClose={() => setDeleteModalOpen(false)}
        title="⚠️ Confirmar eliminación definitiva"
      >
        {error && <div className="alert alert-danger">{error}</div>}

        <div style={{ fontSize: '14px', color: 'var(--text-main)' }}>
          <p style={{ marginBottom: '12px' }}>
            Esta acción es <strong>completamente destructiva e irreversible</strong>. No podrás recuperar tu horario ni tus notas.
          </p>
          <p style={{ marginBottom: '16px' }}>
            Para confirmar, escribe exactamente <strong>{CONFIRM_KEYWORD}</strong> en el siguiente campo:
          </p>

          <div className="form-group">
            <input
              type="text"
              className="form-input"
              placeholder={CONFIRM_KEYWORD}
              value={confirmationText}
              onChange={(e) => setConfirmationText(e.target.value)}
              style={{ fontWeight: 600, letterSpacing: '0.5px' }}
            />
          </div>
        </div>

        <div className="modal-actions">
          <button
            type="button"
            className="btn btn-secondary"
            onClick={() => setDeleteModalOpen(false)}
            disabled={deleting}
          >
            Cancelar
          </button>
          <button
            type="button"
            className="btn btn-danger"
            onClick={handleDeleteAccount}
            disabled={confirmationText.trim() !== CONFIRM_KEYWORD || deleting}
          >
            {deleting ? 'Borrando cuenta...' : 'Confirmar y borrar mi cuenta'}
          </button>
        </div>
      </Modal>
    </div>
  );
}
