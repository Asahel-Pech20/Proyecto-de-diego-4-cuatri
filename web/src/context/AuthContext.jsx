import React, { createContext, useContext, useState, useEffect } from 'react';
import {
  getToken,
  setToken,
  getCurrentUser,
  setCurrentUser,
  clearSession,
  login as apiLogin,
  register as apiRegister,
  getMe as apiGetMe,
  deleteAccount as apiDeleteAccount,
} from '../api';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(getCurrentUser());
  const [token, setTokenState] = useState(getToken());
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function initAuth() {
      const savedToken = getToken();
      if (savedToken) {
        try {
          const profile = await apiGetMe();
          setUser(profile);
        } catch (err) {
          if (err?.status === 401) {
            clearSession();
            setUser(null);
            setTokenState(null);
          } else {
            console.warn('No se pudo refrescar el perfil del usuario:', err);
            const cachedUser = getCurrentUser();
            if (cachedUser) {
              setUser(cachedUser);
            }
          }
        }
      } else {
        setUser(null);
        setTokenState(null);
      }
      setLoading(false);
    }
    initAuth();
  }, []);

  const login = async (email, password) => {
    const data = await apiLogin(email, password);
    setTokenState(data.token);
    setUser(data.user);
    return data;
  };

  const register = async (name, email, password) => {
    const data = await apiRegister(name, email, password);
    setTokenState(data.token);
    setUser(data.user);
    return data;
  };

  const logout = () => {
    clearSession();
    setTokenState(null);
    setUser(null);
  };

  const deleteAccount = async () => {
    await apiDeleteAccount();
    clearSession();
    setTokenState(null);
    setUser(null);
  };

  const value = {
    user,
    token,
    isAuthenticated: Boolean(token),
    loading,
    login,
    register,
    logout,
    deleteAccount,
    setUser,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth debe ser usado dentro de un AuthProvider');
  }
  return context;
}
