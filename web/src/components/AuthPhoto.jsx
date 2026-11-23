import React, { useState, useEffect } from 'react';
import { fetchPhotoBlobUrl } from '../api';

export function AuthPhoto({ photoPath, alt = 'Foto', className = '', style = {}, onClick }) {
  const [blobUrl, setBlobUrl] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  useEffect(() => {
    let active = true;
    let createdUrl = null;

    if (!photoPath) {
      setBlobUrl(null);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(false);

    fetchPhotoBlobUrl(photoPath)
      .then((url) => {
        if (active) {
          createdUrl = url;
          setBlobUrl(url);
          setLoading(false);
        } else {
          URL.revokeObjectURL(url);
        }
      })
      .catch((err) => {
        console.error('Error al cargar foto autenticada:', err);
        if (active) {
          setError(true);
          setLoading(false);
        }
      });

    return () => {
      active = false;
      if (createdUrl) {
        URL.revokeObjectURL(createdUrl);
      }
    };
  }, [photoPath]);

  if (loading) {
    return (
      <div
        className={className}
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: '#f3f4f6',
          borderRadius: '8px',
          padding: '8px',
          minWidth: '60px',
          minHeight: '60px',
          ...style,
        }}
      >
        <span className="spinner spinner-dark" style={{ width: '16px', height: '16px' }} />
      </div>
    );
  }

  if (error || !blobUrl) {
    return (
      <div
        className={className}
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: '#fee2e2',
          color: '#991b1b',
          fontSize: '11px',
          borderRadius: '8px',
          padding: '6px',
          ...style,
        }}
      >
        ⚠️ Foto no disp.
      </div>
    );
  }

  return (
    <img
      src={blobUrl}
      alt={alt}
      className={className}
      style={{
        objectFit: 'cover',
        borderRadius: '8px',
        cursor: onClick ? 'pointer' : 'default',
        ...style,
      }}
      onClick={onClick}
    />
  );
}
