import React, { useState, useEffect } from 'react';
import { db } from '../db/db';
import { sincronizarDatos } from '../utils/sync';

const EstadoSincronizacion = () => {
  const [online, setOnline] = useState(navigator.onLine);
  const [pendientes, setPendientes] = useState(0);

  const actualizarEstado = async () => {
    setOnline(navigator.onLine);
    const count = await db.respuestas.where('estado').equals('pendiente').count();
    setPendientes(count);
  };

  useEffect(() => {
    actualizarEstado();
    const interval = setInterval(actualizarEstado, 3000);

    window.addEventListener('online', actualizarEstado);
    window.addEventListener('offline', actualizarEstado);

    return () => {
      clearInterval(interval);
      window.removeEventListener('online', actualizarEstado);
      window.removeEventListener('offline', actualizarEstado);
    };
  }, []);

  return (
    <div style={{
      padding: '10px 15px',
      borderRadius: '6px',
      marginBottom: '1rem',
      backgroundColor: online ? '#e6f4ea' : '#fce8e6',
      border: `1px solid ${online ? '#a8dab5' : '#f5c2c7'}`,
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center'
    }}>
      <span>
        <strong>Estado:</strong> {online ? '🟢 En línea' : '🔴 Sin conexión (Offline)'}
      </span>
      <span>
        <strong>Pendientes de subir:</strong> {pendientes}
      </span>
      {online && pendientes > 0 && (
        <button 
          onClick={() => sincronizarDatos()}
          style={{ padding: '5px 10px', background: '#0d6efd', color: '#fff', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
        >
          Sincronizar Ahora
        </button>
      )}
    </div>
  );
};

export default EstadoSincronizacion;