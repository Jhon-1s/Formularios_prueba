import React, { useState } from 'react';

export const CrearFormulario = () => {
  const [titulo, setTitulo] = useState('');
  const [descripcion, setDescripcion] = useState('');
  const [preguntas, setPreguntas] = useState([
    {
      id: 'p_temp_1',
      texto: '¿El equipo presenta fallas operativas?',
      tipo: 'SELECCION',
      opciones: '["SÍ", "NO"]',
      requerido: true,
      esCondicional: false,
      preguntaOrigenIndex: null,
      condicion: 'IGUAL_A',
      valorCondicion: 'SÍ',
      accion: 'MOSTRAR',
    },
  ]);

  // Función para agregar una nueva pregunta a la lista
  const agregarPregunta = () => {
    setPreguntas([
      ...preguntas,
      {
        id: `p_temp_${preguntas.length + 1}`,
        texto: '',
        tipo: 'TEXTO',
        opciones: '',
        requerido: false,
        esCondicional: false,
        preguntaOrigenIndex: null,
        condicion: 'IGUAL_A',
        valorCondicion: '',
        accion: 'MOSTRAR',
      },
    ]);
  };

  // Manejador de cambios en los campos de una pregunta
  const handlePreguntaChange = (index, campo, valor) => {
    const nuevas = [...preguntas];
    nuevas[index][campo] = valor;
    setPreguntas(nuevas);
  };

  return (
    <div style={{ maxWidth: '700px', margin: '0 auto', padding: '20px' }}>
      <h2>Crear Nuevo Formulario Dinámico</h2>

      <div style={{ marginBottom: '15px' }}>
        <label><strong>Título del Formulario:</strong></label>
        <input
          type="text"
          style={{ width: '100%', padding: '8px', marginTop: '5px' }}
          value={titulo}
          onChange={(e) => setTitulo(e.target.value)}
          placeholder="Ej. Inspección de Maquinaria Industrial"
        />
      </div>

      <h3>Preguntas del Formulario</h3>

      {preguntas.map((preg, index) => (
        <div
          key={preg.id}
          style={{
            border: '1px solid #cbd5e1',
            borderRadius: '8px',
            padding: '15px',
            marginBottom: '15px',
            backgroundColor: '#f8fafc',
          }}
        >
          <h4>Pregunta #{index + 1}</h4>

          <div style={{ marginBottom: '10px' }}>
            <label>Etiqueta / Texto de la pregunta:</label>
            <input
              type="text"
              style={{ width: '100%', padding: '6px' }}
              value={preg.texto}
              onChange={(e) => handlePreguntaChange(index, 'texto', e.target.value)}
              placeholder="Ej. Describa la falla encontrada"
            />
          </div>

          <div style={{ display: 'flex', gap: '10px', marginBottom: '10px' }}>
            <div>
              <label>Tipo:</label>
              <select
                value={preg.tipo}
                onChange={(e) => handlePreguntaChange(index, 'tipo', e.target.value)}
              >
                <option value="TEXTO">Texto</option>
                <option value="NUMERICO">Numérico</option>
                <option value="SELECCION">Selección (SÍ/NO o Lista)</option>
                <option value="FOTOGRAFIA">Fotografía</option>
                <option value="FIRMA">Firma</option>
              </select>
            </div>

            {preg.tipo === 'SELECCION' && (
              <div>
                <label>Opciones (separadas por coma):</label>
                <input
                  type="text"
                  value={preg.opciones}
                  onChange={(e) => handlePreguntaChange(index, 'opciones', e.target.value)}
                  placeholder="SÍ, NO, N/A"
                />
              </div>
            )}
          </div>

          {/* === OPCIÓN PARA AGREGAR REGLA CONDICIONAL === */}
          {index > 0 && (
            <div style={{ marginTop: '10px', paddingTop: '10px', borderTop: '1px dashed #cbd5e1' }}>
              <label style={{ cursor: 'pointer', fontWeight: 'bold', color: '#0369a1' }}>
                <input
                  type="checkbox"
                  checked={preg.esCondicional}
                  onChange={(e) => handlePreguntaChange(index, 'esCondicional', e.target.checked)}
                />
                {' '}¿Esta pregunta depende del resultado de otra pregunta anterior?
              </label>

              {preg.esCondicional && (
                <div style={{ marginTop: '10px', padding: '10px', backgroundColor: '#e0f2fe', borderRadius: '6px' }}>
                  <p style={{ margin: '0 0 8px 0', fontSize: '13px' }}><strong>Configurar Regla Condicional:</strong></p>
                  
                  <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                    <span>Si la Pregunta #</span>
                    <select
                      value={preg.preguntaOrigenIndex ?? ''}
                      onChange={(e) => handlePreguntaChange(index, 'preguntaOrigenIndex', e.target.value)}
                    >
                      <option value="">-- Seleccionar pregunta --</option>
                      {preguntas.slice(0, index).map((p, i) => (
                        <option key={i} value={i}>
                          #{i + 1} - {p.texto || `Pregunta ${i + 1}`}
                        </option>
                      ))}
                    </select>

                    <select
                      value={preg.condicion}
                      onChange={(e) => handlePreguntaChange(index, 'condicion', e.target.value)}
                    >
                      <option value="IGUAL_A">es IGUAL A</option>
                      <option value="DIFERENTE_DE">es DIFERENTE DE</option>
                    </select>

                    <input
                      type="text"
                      placeholder="Valor (Ej. SÍ)"
                      value={preg.valorCondicion}
                      onChange={(e) => handlePreguntaChange(index, 'valorCondicion', e.target.value)}
                    />

                    <span>➔ entonces</span>

                    <select
                      value={preg.accion}
                      onChange={(e) => handlePreguntaChange(index, 'accion', e.target.value)}
                    >
                      <option value="MOSTRAR">MOSTRAR esta pregunta</option>
                      <option value="OCULTAR">OCULTAR esta pregunta</option>
                    </select>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      ))}

      <button type="button" onClick={agregarPregunta} style={{ marginBottom: '20px' }}>
        + Agregar otra pregunta
      </button>
    </div>
  );
};