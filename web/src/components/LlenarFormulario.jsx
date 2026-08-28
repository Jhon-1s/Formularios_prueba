import React, { useState } from 'react';
import { db } from '../db/db'; // Importamos la BD local

const CampoDinamico = ({ campo, onChange }) => {
  if (campo.tipo === 'FOTOGRAFIA') {
    return (
      <div style={{ marginBottom: '1rem' }}>
        <label style={{ display: 'block', fontWeight: 'bold', marginBottom: '0.5rem' }}>
          {campo.etiqueta}
        </label>
        <input
          type="file"
          accept="image/*"
          capture="environment"
          onChange={(e) => onChange(campo.id, e.target.files[0])}
        />
      </div>
    );
  }

  if (campo.tipo === 'ARCHIVO') {
    return (
      <div style={{ marginBottom: '1rem' }}>
        <label style={{ display: 'block', fontWeight: 'bold', marginBottom: '0.5rem' }}>
          {campo.etiqueta}
        </label>
        <input
          type="file"
          accept="image/*"
          onChange={(e) => onChange(campo.id, e.target.files[0])}
        />
      </div>
    );
  }

  return (
    <div style={{ marginBottom: '1rem' }}>
      <label style={{ display: 'block', fontWeight: 'bold', marginBottom: '0.5rem' }}>
        {campo.etiqueta}
      </label>
      <input
        type="text"
        onChange={(e) => onChange(campo.id, e.target.value)}
        style={{ width: '100%', padding: '8px', boxSizing: 'border-box' }}
      />
    </div>
  );
};

const LlenarFormulario = ({ formulario }) => {
  const [respuestas, setRespuestas] = useState({});
  const [guardando, setGuardando] = useState(false);

  const handleCambio = (campoId, valor) => {
    setRespuestas({
      ...respuestas,
      [campoId]: valor,
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setGuardando(true);

    try {
      // Guardar la inspección en la base de datos local (IndexedDB)
      await db.respuestas.add({
        formularioId: formulario?.id || 'demo-1',
        datos: respuestas,           // Guarda el objeto con textos y archivos Blob
        estado: 'pendiente',          // Marca como listo para sincronizar
        fecha: new Date().toISOString()
      });

      alert('Inspección guardada localmente en el dispositivo.');
      setRespuestas({});
    } catch (error) {
      console.error('Error guardando en BD local:', error);
      alert('Error al guardar localmente');
    } finally {
      setGuardando(false);
    }
  };

  return (
    <div style={{ padding: '1rem', border: '1px solid #ccc', borderRadius: '8px', background: '#fff' }}>
      <h2>Llenar Inspección</h2>
      <form onSubmit={handleSubmit}>
        {formulario?.campos?.map((campo) => (
          <CampoDinamico key={campo.id} campo={campo} onChange={handleCambio} />
        ))}
        <button 
          type="submit" 
          disabled={guardando} 
          style={{ padding: '10px 20px', background: '#28a745', color: '#fff', border: 'none', borderRadius: '4px' }}
        >
          {guardando ? 'Guardando...' : 'Guardar Inspección (Offline)'}
        </button>
      </form>
    </div>
  );
};

export default LlenarFormulario;