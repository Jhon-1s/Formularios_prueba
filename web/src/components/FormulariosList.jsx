import { gql } from '@apollo/client';
import { useQuery } from '@apollo/client/react';

// Prueba pidiendo solo los campos mínimos esenciales
const GET_FORMULARIOS = gql`
  query GetFormulariosDisponibles {
    getFormulariosDisponibles {
      id
      titulo
    }
  }
`;

export default function FormulariosList() {
  const { data, loading, error } = useQuery(GET_FORMULARIOS);

  if (loading) return <p>Cargando formularios...</p>;
  if (error) return <p style={{ color: 'red' }}>Error: {error.message}</p>;

  return (
    <div>
      <h2>Formularios Disponibles</h2>
      <ul>
        {data?.getFormulariosDisponibles?.map((f) => (
          <li key={f.id}>
            <strong>{f.titulo}</strong>
          </li>
        ))}
      </ul>
    </div>
  );
}