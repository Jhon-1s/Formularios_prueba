import React, { useState } from 'react';
import { gql } from '@apollo/client';
import { useMutation } from '@apollo/client/react';

// Tipos aceptados según tu backend
const TIPOS_PREGUNTA = [
  { label: 'Texto Libre', value: 'TEXTO' },
  { label: 'Número', value: 'NUMERICO' },
  { label: 'Fecha', value: 'FECHA' },
  { label: 'Hora', value: 'HORA' },
  { label: 'Fecha y Hora', value: 'FECHA_HORA' },
  { label: 'Selección Única', value: 'SELECCION' },
  { label: 'Casilla de Verificación', value: 'CHECKBOX' },
  { label: 'Fotografía / Evidencia', value: 'FOTOGRAFIA' },
  { label: 'Firma Digital', value: 'FIRMA' },
  { label: 'Ubicación GPS', value: 'UBICACION' },
];

// Mutación actualizada para recibir los campos condicionales
const CREAR_FORMULARIO_CON_PREGUNTAS = gql`
  mutation CrearFormularioConPreguntas(
    $titulo: String!
    $descripcion: String
    $preguntas: [PreguntaInput!]!
  ) {
    crearFormularioConPreguntas(
      titulo: $titulo
      descripcion: $descripcion
      preguntas: $preguntas
    ) {
      id
      titulo
    }
  }
`;

export default function FormBuilder({ onGuardarExitoso }) {
  const [titulo, setTitulo] = useState('');
  const [descripcion, setDescripcion] = useState('');
  const [preguntas, setPreguntas] = useState([]);

  // Estado del creador de preguntas con la lógica condicional integrada
  const [nuevaPregunta, setNuevaPregunta] = useState({
    etiqueta: '',
    tipo: 'TEXTO',
    requerido: false,
    opciones: '',
    esCondicional: false,
    dependeDeCampoId: '',
    mostrarSiValorIgualA: '',
  });

  const [crearFormulario, { loading, error }] = useMutation(
    CREAR_FORMULARIO_CON_PREGUNTAS,
    {
      refetchQueries: ['ObtenerFormularios'], 
      awaitRefetchQueries: true,
      onCompleted: () => {
        alert('¡Formulario creado con éxito!');
        setTitulo('');
        setDescripcion('');
        setPreguntas([]);
        if (onGuardarExitoso) onGuardarExitoso();
      },
    }
  );

  const handleAgregarPregunta = (e) => {
    e.preventDefault();
    if (!nuevaPregunta.etiqueta.trim()) {
      alert('Ingresa el texto de la pregunta');
      return;
    }

    const opcionesProcesadas =
      (nuevaPregunta.tipo === 'SELECCION' || nuevaPregunta.tipo === 'CHECKBOX') && nuevaPregunta.opciones
        ? JSON.stringify(
            nuevaPregunta.opciones.split(',').map((o) => o.trim()).filter(Boolean)
          )
        : null;

    const item = {
      id: Date.now().toString(), // ID temporal local
      etiqueta: nuevaPregunta.etiqueta,
      tipo: nuevaPregunta.tipo,
      requerido: nuevaPregunta.requerido,
      opciones: opcionesProcesadas,
      dependeDeCampoId: nuevaPregunta.esCondicional ? nuevaPregunta.dependeDeCampoId : null,
      mostrarSiValorIgualA: nuevaPregunta.esCondicional ? nuevaPregunta.mostrarSiValorIgualA : null,
    };

    setPreguntas([...preguntas, item]);

    // Limpiar formulario para la siguiente pregunta
    setNuevaPregunta({
      etiqueta: '',
      tipo: 'TEXTO',
      requerido: false,
      opciones: '',
      esCondicional: false,
      dependeDeCampoId: '',
      mostrarSiValorIgualA: '',
    });
  };

  const moverPregunta = (index, direccion) => {
    const nuevasPreguntas = [...preguntas];
    const targetIndex = index + direccion;
    if (targetIndex < 0 || targetIndex >= preguntas.length) return;

    const [temp] = nuevasPreguntas.splice(index, 1);
    nuevasPreguntas.splice(targetIndex, 0, temp);
    setPreguntas(nuevasPreguntas);
  };

  const handleEliminarPregunta = (id) => {
    setPreguntas(preguntas.filter((p) => p.id !== id));
  };

  const handleGuardarFormulario = () => {
  if (!titulo.trim()) return alert('Ingresa un título para el formulario');
  if (preguntas.length === 0) return alert('Agrega al menos una pregunta');

  // Mapear al objeto estricto incluyendo el ID temporal
  const preguntasInput = preguntas.map((p, index) => ({
    id: String(p.id), // <--- ¡AÑADIR ESTA LÍNEA! (ID temporal)
    etiqueta: p.etiqueta,
    tipo: p.tipo,
    requerido: Boolean(p.requerido),
    orden: index + 1,
    opciones: p.opciones,
    dependeDeCampoId: p.dependeDeCampoId || null,
    mostrarSiValorIgualA: p.mostrarSiValorIgualA || null,
  }));

  crearFormulario({
    variables: {
      titulo,
      descripcion,
      preguntas: preguntasInput,
    },
  });
};

  return (
    <div style={{ color: '#333', maxWidth: '800px', margin: '0 auto' }}>
      <h2>Constructor de Formularios (Form Builder)</h2>

      {/* 1. Información General */}
      <div style={{ background: '#fff', padding: '1.5rem', borderRadius: '8px', marginBottom: '1.5rem', border: '1px solid #ddd' }}>
        <h3>1. Información General</h3>
        <div style={{ marginBottom: '1rem' }}>
          <label style={{ display: 'block', fontWeight: 'bold', marginBottom: '0.5rem' }}>Título *</label>
          <input
            type="text"
            value={titulo}
            onChange={(e) => setTitulo(e.target.value)}
            placeholder="Ej: Check-list de Mantenimiento"
            style={{ width: '100%', padding: '0.6rem', borderRadius: '4px', border: '1px solid #ccc' }}
          />
        </div>
        <div>
          <label style={{ display: 'block', fontWeight: 'bold', marginBottom: '0.5rem' }}>Descripción</label>
          <textarea
            value={descripcion}
            onChange={(e) => setDescripcion(e.target.value)}
            rows="2"
            style={{ width: '100%', padding: '0.6rem', borderRadius: '4px', border: '1px solid #ccc' }}
          />
        </div>
      </div>

      {/* 2. Diseñar Pregunta */}
      <div style={{ background: '#fff', padding: '1.5rem', borderRadius: '8px', marginBottom: '1.5rem', border: '1px solid #ddd' }}>
        <h3>2. Diseñar Pregunta</h3>

        <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '1rem', marginBottom: '1rem' }}>
          <div>
            <label style={{ display: 'block', fontWeight: 'bold', marginBottom: '0.5rem' }}>Etiqueta / Pregunta *</label>
            <input
              type="text"
              value={nuevaPregunta.etiqueta}
              onChange={(e) => setNuevaPregunta({ ...nuevaPregunta, etiqueta: e.target.value })}
              placeholder="Ej: Estado general del motor"
              style={{ width: '100%', padding: '0.6rem', borderRadius: '4px', border: '1px solid #ccc' }}
            />
          </div>

          <div>
            <label style={{ display: 'block', fontWeight: 'bold', marginBottom: '0.5rem' }}>Tipo de Campo</label>
            <select
              value={nuevaPregunta.tipo}
              onChange={(e) => setNuevaPregunta({ ...nuevaPregunta, tipo: e.target.value })}
              style={{ width: '100%', padding: '0.6rem', borderRadius: '4px', border: '1px solid #ccc' }}
            >
              {TIPOS_PREGUNTA.map((t) => (
                <option key={t.value} value={t.value}>{t.label}</option>
              ))}
            </select>
          </div>
        </div>

        {(nuevaPregunta.tipo === 'SELECCION' || nuevaPregunta.tipo === 'CHECKBOX') && (
          <div style={{ marginBottom: '1rem' }}>
            <label style={{ display: 'block', fontWeight: 'bold', marginBottom: '0.5rem' }}>Opciones (Separadas por comas)</label>
            <input
              type="text"
              value={nuevaPregunta.opciones}
              onChange={(e) => setNuevaPregunta({ ...nuevaPregunta, opciones: e.target.value })}
              placeholder="Ej: SÍ, NO, REVISION"
              style={{ width: '100%', padding: '0.6rem', borderRadius: '4px', border: '1px solid #ccc' }}
            />
          </div>
        )}

        <div style={{ marginBottom: '1rem' }}>
          <label style={{ cursor: 'pointer' }}>
            <input
              type="checkbox"
              checked={nuevaPregunta.requerido}
              onChange={(e) => setNuevaPregunta({ ...nuevaPregunta, requerido: e.target.checked })}
            />
            {' '} Campo Requerido (Obligatorio)
          </label>
        </div>

        {/* --- NUEVA SECCIÓN DE REGLAS CONDICIONALES --- */}
        {preguntas.length > 0 && (
          <div style={{ marginBottom: '1rem', padding: '1rem', background: '#f8f9fa', borderRadius: '6px', border: '1px dashed #ccc' }}>
            <label style={{ cursor: 'pointer', fontWeight: 'bold' }}>
              <input
                type="checkbox"
                checked={nuevaPregunta.esCondicional}
                onChange={(e) => setNuevaPregunta({
                  ...nuevaPregunta,
                  esCondicional: e.target.checked,
                  dependeDeCampoId: e.target.checked ? preguntas[0].id : '',
                  mostrarSiValorIgualA: ''
                })}
              />
              {' '} ¿Esta pregunta se muestra solo si se cumple una condición?
            </label>

            {nuevaPregunta.esCondicional && (
              <div style={{ marginTop: '0.8rem', display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                <div>
                  <label style={{ fontSize: '0.9rem', fontWeight: 'bold' }}>Mostrar cuando la pregunta:</label>
                  <select
                    value={nuevaPregunta.dependeDeCampoId}
                    onChange={(e) => setNuevaPregunta({ ...nuevaPregunta, dependeDeCampoId: e.target.value })}
                    style={{ width: '100%', padding: '0.4rem', borderRadius: '4px', border: '1px solid #ccc', marginTop: '0.2rem' }}
                  >
                    {preguntas.map((p) => (
                      <option key={p.id} value={p.id}>{p.etiqueta}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label style={{ fontSize: '0.9rem', fontWeight: 'bold' }}>Tenga exactamente el valor de:</label>
                  <input
                    type="text"
                    placeholder="Ej: NO (o la opción desencadenante)"
                    value={nuevaPregunta.mostrarSiValorIgualA}
                    onChange={(e) => setNuevaPregunta({ ...nuevaPregunta, mostrarSiValorIgualA: e.target.value })}
                    style={{ width: '100%', padding: '0.4rem', borderRadius: '4px', border: '1px solid #ccc', marginTop: '0.2rem' }}
                  />
                </div>
              </div>
            )}
          </div>
        )}

        <button
          type="button"
          onClick={handleAgregarPregunta}
          style={{ padding: '0.6rem 1.2rem', background: '#17a2b8', color: '#fff', border: 'none', borderRadius: '4px', cursor: 'pointer', fontWeight: 'bold' }}
        >
          ➕ Añadir Pregunta
        </button>
      </div>

      {/* 3. Lista de Preguntas */}
      <div style={{ background: '#fff', padding: '1.5rem', borderRadius: '8px', marginBottom: '1.5rem', border: '1px solid #ddd' }}>
        <h3>3. Preguntas en el Formulario ({preguntas.length})</h3>
        {preguntas.length === 0 ? (
          <p style={{ color: '#777' }}>Aún no hay preguntas agregadas.</p>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            {preguntas.map((p, idx) => {
              const dependePregunta = p.dependeDeCampoId ? preguntas.find(orig => orig.id === p.dependeDeCampoId) : null;
              
              return (
                <div key={p.id} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0.75rem', background: '#f8f9fa', border: '1px solid #e9ecef', borderRadius: '6px' }}>
                  <div>
                    <strong>{idx + 1}. {p.etiqueta}</strong> <span style={{ fontSize: '0.8rem', color: '#555' }}>({p.tipo})</span>
                    {p.requerido && <span style={{ color: 'red', fontSize: '0.8rem', marginLeft: '0.5rem' }}>* Requerido</span>}
                    
                    {/* Visualizar si es una pregunta condicional */}
                    {dependePregunta && (
                      <div style={{ fontSize: '0.8rem', color: '#e67e22', marginTop: '4px' }}>
                        🔗 <i>Se muestra si <b>"{dependePregunta.etiqueta}"</b> = <b>"{p.mostrarSiValorIgualA}"</b></i>
                      </div>
                    )}
                  </div>

                  <div style={{ display: 'flex', gap: '0.3rem' }}>
                    <button type="button" onClick={() => moverPregunta(idx, -1)} disabled={idx === 0}>⬆️</button>
                    <button type="button" onClick={() => moverPregunta(idx, 1)} disabled={idx === preguntas.length - 1}>⬇️</button>
                    <button type="button" onClick={() => handleEliminarPregunta(p.id)} style={{ background: '#dc3545', color: '#fff', border: 'none', borderRadius: '3px', cursor: 'pointer' }}>🗑️</button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {error && <p style={{ color: 'red', fontWeight: 'bold' }}>Error al guardar: {error.message}</p>}

      <button
        type="button"
        onClick={handleGuardarFormulario}
        disabled={loading}
        style={{ width: '100%', padding: '1rem', background: '#28a745', color: '#fff', border: 'none', borderRadius: '6px', fontSize: '1.1rem', cursor: 'pointer', fontWeight: 'bold' }}
      >
        {loading ? 'Guardando en Servidor...' : 'Publicar Formulario Completo'}
      </button>
    </div>
  );
}