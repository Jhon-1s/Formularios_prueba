import React from 'react';
import { gql } from '@apollo/client';
import { useQuery } from '@apollo/client/react';

const GET_RESPUESTAS = gql`
  query GetHistorialRespuestas {
    getHistorialRespuestas {
      id
      formulario_id
      formulario_titulo
      tituloFormulario
      usuario_nombre_completo
      nombreUsuario
      fecha_completado
      fechaCreado
      estado
    }
  }
`;

export default function RespuestasList() {
  const { data, loading, error, refetch } = useQuery(GET_RESPUESTAS, {
    fetchPolicy: 'network-only', // Fuerza a traer siempre datos frescos del servidor
  });

  if (loading) return <p>Cargando respuestas de usuarios...</p>;
  if (error)
    return (
      <div style={{ color: 'red', padding: '1rem' }}>
        <p>Error al obtener respuestas: {error.message}</p>
        <button onClick={() => refetch()}>Reintentar</button>
      </div>
    );

  const respuestas = data?.getHistorialRespuestas || [];

  return (
    <div style={{ color: '#333' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h2>Respuestas / Inspecciones Recibidas</h2>
        <button 
          onClick={() => refetch()} 
          style={{ padding: '0.5rem 1rem', background: '#007bff', color: '#fff', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
        >
          Actualizar Lista
        </button>
      </div>

      {respuestas.length === 0 ? (
        <p style={{ marginTop: '1rem', color: '#666' }}>Aún no hay respuestas registradas.</p>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: '1rem' }}>
          <thead>
            <tr style={{ background: '#f8f9fa', textAlign: 'left', borderBottom: '2px solid #dee2e6' }}>
              <th style={{ padding: '0.75rem' }}>Formulario</th>
              <th style={{ padding: '0.75rem' }}>Usuario / Respondiente</th>
              <th style={{ padding: '0.75rem' }}>Fecha</th>
              <th style={{ padding: '0.75rem' }}>Estado</th>
              <th style={{ padding: '0.75rem' }}>Acciones</th> {/* 👈 NUEVA COLUMNA */}
            </tr>
          </thead>
          <tbody>
            {respuestas.map((resp) => {
              const titulo = resp.tituloFormulario || resp.formulario_titulo || 'Sin título';
              const usuario = resp.nombreUsuario || resp.usuario_nombre_completo || 'Anónimo';
              const fecha = resp.fechaCreado || resp.fecha_completado || 'Sin fecha';

              return (
                <tr key={resp.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                  <td style={{ padding: '0.75rem', fontWeight: '500' }}>{titulo}</td>
                  <td style={{ padding: '0.75rem' }}>{usuario}</td>
                  <td style={{ padding: '0.75rem' }}>{fecha}</td>
                  <td style={{ padding: '0.75rem' }}>
                    <span style={{
                      padding: '0.25rem 0.5rem',
                      borderRadius: '4px',
                      fontSize: '0.85rem',
                      background: resp.estado === 'FINALIZADO' ? '#d4edda' : '#fff3cd',
                      color: resp.estado === 'FINALIZADO' ? '#155724' : '#856404',
                    }}>
                      {resp.estado || 'REGISTRADO'}
                    </span>
                  </td>
                  {/* 👈 NUEVA CELDA CON EL BOTÓN/ENLACE DE PDF */}
                  <td style={{ padding: '0.75rem' }}>
                    <a
                      href={`http://localhost:4000/api/inspecciones/${resp.id}/pdf`}
                      target="_blank"
                      rel="noopener noreferrer"
                      style={{
                        padding: '0.35rem 0.75rem',
                        backgroundColor: '#dc3545',
                        color: '#ffffff',
                        borderRadius: '4px',
                        textDecoration: 'none',
                        fontSize: '0.85rem',
                        fontWeight: '500',
                        display: 'inline-block',
                      }}
                    >
                      📄 Ver PDF
                    </a>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}
    </div>
  );
}