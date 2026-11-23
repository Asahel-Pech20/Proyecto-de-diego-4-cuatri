import React from 'react';

export class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('ErrorBoundary capturó un error:', error, errorInfo);
  }

  handleReset = () => {
    this.setState({ hasError: false, error: null });
    window.location.reload();
  };

  handleGoHome = () => {
    this.setState({ hasError: false, error: null });
    window.location.href = '/';
  };

  render() {
    if (this.state.hasError) {
      return (
        <div style={{ padding: '32px 16px', maxWidth: '600px', margin: '40px auto' }}>
          <div
            className="card"
            style={{
              borderLeft: '5px solid var(--danger)',
              boxShadow: 'var(--shadow-md)',
              padding: '24px',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '12px' }}>
              <span style={{ fontSize: '28px' }}>⚠️</span>
              <h2 style={{ fontSize: '20px', color: '#991b1b' }}>Algo salió mal en esta página</h2>
            </div>
            <p style={{ color: 'var(--text-muted)', fontSize: '14px', marginBottom: '16px' }}>
              Se produjo un error inesperado al renderizar la vista. No te preocupes, tus datos están a salvo.
            </p>
            {this.state.error?.message && (
              <div
                style={{
                  backgroundColor: '#fee2e2',
                  color: '#991b1b',
                  padding: '10px 12px',
                  borderRadius: '6px',
                  fontSize: '12px',
                  fontFamily: 'monospace',
                  marginBottom: '20px',
                  wordBreak: 'break-all',
                }}
              >
                {this.state.error.message}
              </div>
            )}
            <div style={{ display: 'flex', gap: '10px' }}>
              <button type="button" className="btn btn-primary btn-sm" onClick={this.handleReset}>
                🔄 Recargar página
              </button>
              <button type="button" className="btn btn-secondary btn-sm" onClick={this.handleGoHome}>
                🏠 Ir al Inicio
              </button>
            </div>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
