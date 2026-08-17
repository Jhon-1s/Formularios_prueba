import React, { useState } from 'react';
import Login from './components/Login';
import RegistroEmpresa from './components/RegistroEmpresa';
import FormulariosList from './components/FormulariosList';
import FormBuilder from './components/FormBuilder';
import RespuestasList from './components/RespuestasList';
import './App.css';

function App() {
  const [token, setToken] = useState(() => localStorage.getItem('token'));
  const [vistaActiva, setVistaActiva] = useState('lista');

  const handleLogout = () => {
    localStorage.removeItem('token');
    setToken(null);
  };

  if (!token) {
    return (
      <div style={{ padding: '2rem', fontFamily: 'sans-serif' }}>
        <h1 style={{ textAlign: 'center' }}>Panel Administrador</h1>
        <Login onLoginSuccess={(newToken) => setToken(newToken)} />
      </div>
    );
  }

  return (
    <div style={{ padding: '2rem', fontFamily: 'sans-serif', maxWidth: '900px', margin: '0 auto' }}>
      <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
        <h1>Panel Administrador</h1>
        <button 
          onClick={handleLogout} 
          style={{ padding: '0.5rem 1rem', background: '#dc3545', color: '#fff', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
        >
          Cerrar Sesión
        </button>
      </header>

      <nav style={{ display: 'flex', gap: '10px', marginBottom: '2rem', borderBottom: '2px solid #eee', paddingBottom: '0.5rem', flexWrap: 'wrap' }}>
        <button
          onClick={() => setVistaActiva('lista')}
          style={{
            padding: '0.5rem 1rem',
            background: vistaActiva === 'lista' ? '#007bff' : '#e9ecef',
            color: vistaActiva === 'lista' ? '#fff' : '#333',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
            fontWeight: 'bold'
          }}
        >
          📋 Mis Formularios
        </button>
        <button
          onClick={() => setVistaActiva('crear')}
          style={{
            padding: '0.5rem 1rem',
            background: vistaActiva === 'crear' ? '#007bff' : '#e9ecef',
            color: vistaActiva === 'crear' ? '#fff' : '#333',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
            fontWeight: 'bold'
          }}
        >
          🛠️ Constructor (Form Builder)
        </button>
        <button
          onClick={() => setVistaActiva('respuestas')}
          style={{
            padding: '0.5rem 1rem',
            background: vistaActiva === 'respuestas' ? '#007bff' : '#e9ecef',
            color: vistaActiva === 'respuestas' ? '#fff' : '#333',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
            fontWeight: 'bold'
          }}
        >
          📊 Ver Respuestas
        </button>
        <button
          onClick={() => setVistaActiva('empresa')}
          style={{
            padding: '0.5rem 1rem',
            background: vistaActiva === 'empresa' ? '#007bff' : '#e9ecef',
            color: vistaActiva === 'empresa' ? '#fff' : '#333',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
            fontWeight: 'bold'
          }}
        >
          🏢 Registrar Empresa
        </button>
      </nav>

      <main>
        {vistaActiva === 'lista' && <FormulariosList />}
        {vistaActiva === 'crear' && <FormBuilder onGuardarExitoso={() => setVistaActiva('lista')} />}
        {vistaActiva === 'respuestas' && <RespuestasList />}
        {vistaActiva === 'empresa' && <RegistroEmpresa />}
      </main>
    </div>
  );
}

export default App;