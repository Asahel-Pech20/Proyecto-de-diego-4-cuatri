import React, { useState } from 'react';
import { NavLink, Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export function Navbar() {
  const { user, logout } = useAuth();
  const [menuOpen, setMenuOpen] = useState(false);
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const closeMenu = () => setMenuOpen(false);

  return (
    <nav className="navbar">
      <Link to="/" className="nav-brand" onClick={closeMenu}>
        <span style={{ fontSize: '20px' }}>🎓</span>
        <span>MiSemestre UTM</span>
      </Link>

      <button
        type="button"
        className="nav-mobile-toggle"
        onClick={() => setMenuOpen(!menuOpen)}
        aria-label="Toggle navigation menu"
      >
        ☰
      </button>

      <div className={`nav-links ${menuOpen ? 'open' : ''}`}>
        <NavLink
          to="/"
          end
          className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}
          onClick={closeMenu}
        >
          Inicio
        </NavLink>
        <NavLink
          to="/horario"
          className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}
          onClick={closeMenu}
        >
          Horario
        </NavLink>
        <NavLink
          to="/tareas"
          className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}
          onClick={closeMenu}
        >
          Tareas
        </NavLink>
        <NavLink
          to="/materias"
          className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}
          onClick={closeMenu}
        >
          Materias
        </NavLink>
        <NavLink
          to="/cuenta"
          className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}
          onClick={closeMenu}
        >
          Mi Cuenta
        </NavLink>
        <button
          onClick={() => {
            closeMenu();
            handleLogout();
          }}
          className="btn btn-outline btn-sm"
          style={{ borderColor: 'rgba(255,255,255,0.6)', color: '#ffffff' }}
        >
          Salir
        </button>
      </div>
    </nav>
  );
}
