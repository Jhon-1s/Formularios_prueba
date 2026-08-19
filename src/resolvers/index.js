const pool = require('../database/db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const SECRET_KEY = process.env.JWT_SECRET || 'clave_secreta_por_defecto';

// Helper de autorización
const requerirAuth = (usuario) => {
  if (!usuario) {
    throw new Error('No autorizado: Token inválido o ausente.');
  }
};

// Helper para obtener el texto real de las preguntas a partir de sus IDs
const construirMapaPreguntas = async (formularioIds) => {
  const idsUnicos = [...new Set((formularioIds || []).filter(Boolean))];
  if (idsUnicos.length === 0) return {};

  const [preguntas] = await pool.query(
    `SELECT s.formulario_id, p.id AS pregunta_id, p.texto 
     FROM pregunta p
     INNER JOIN seccion s ON p.seccion_id = s.id
     WHERE s.formulario_id IN (?)`,
    [idsUnicos]
  );

  const mapa = {};
  preguntas.forEach(p => {
    const fId = String(p.formulario_id);
    if (!mapa[fId]) mapa[fId] = {};
    mapa[fId][String(p.pregunta_id)] = p.texto;
  });

  return mapa;
};

const resolvers = {
  Query: {
    ping: () => "pong",

    perfil: async (_, __, context) => {
      requerirAuth(context.usuario);
      const [rows] = await pool.query(
        'SELECT id, empresa_id, nombre, email, rol, activo FROM usuario WHERE id = ?', 
        [context.usuario.id]
      );
      return rows[0];
    },

getEmpresas: async () => {
  const [rows] = await pool.query('SELECT id, nombre, logo AS logo_url, activo FROM empresa');
  return rows;
},

getEmpresa: async (_, { id }) => {
  const [rows] = await pool.query('SELECT id, nombre, logo AS logo_url, activo FROM empresa WHERE id = ?', [id]);
  return rows[0];
},

    getFormulariosDisponibles: async (_, __, context) => {
      requerirAuth(context.usuario);
      const empresaId = context.usuario.empresa_id;

      try {
        const [rows] = await pool.query(
          `SELECT id, titulo, descripcion, CAST(version AS CHAR) AS version, activo 
           FROM formulario 
           WHERE empresa_id = ? AND activo = 1 AND eliminado_en IS NULL`,
          [empresaId]
        );
        return rows.map(f => ({ ...f, id: String(f.id) }));
      } catch (error) {
        throw new Error(`Error al obtener formularios: ${error.message}`);
      }
    },

    getCamposPorSeccion: async (_, { seccion_id }, context) => {
      requerirAuth(context.usuario);

      try {
        const [rows] = await pool.query(
          `SELECT p.id, p.seccion_id, p.tipo, p.texto AS etiqueta, p.orden, p.requerido, p.visible, p.solo_lectura AS editable, p.opciones,
                  r.pregunta_origen_id AS dependeDeCampoId, r.valor AS mostrarSiValorIgualA
           FROM pregunta p
           LEFT JOIN regla r ON p.id = r.pregunta_destino_id
           WHERE p.seccion_id = ? 
           ORDER BY p.orden ASC`,
          [seccion_id]
        );

        return rows.map(campo => ({
          id: String(campo.id),
          seccion_id: String(campo.seccion_id),
          tipo_campo: campo.tipo || 'TEXTO',
          etiqueta: campo.etiqueta || '',
          ayuda: "",
          placeholder: "",
          orden: Number(campo.orden) || 1,
          obligatorio: Boolean(campo.requerido),
          visible: Boolean(campo.visible),
          editable: !Boolean(campo.editable),
          config: campo.opciones ? (typeof campo.opciones === 'string' ? campo.opciones : JSON.stringify(campo.opciones)) : "{}",
          reglas_validacion: "{}",
          dependeDeCampoId: campo.dependeDeCampoId ? String(campo.dependeDeCampoId) : null,
          mostrarSiValorIgualA: campo.mostrarSiValorIgualA || null
        }));
      } catch (error) {
        throw new Error(`Error al obtener campos de la sección: ${error.message}`);
      }
    },

    getFormularioPorId: async (_, { id }, context) => {
      try {
        const empresaId = context?.usuario?.empresa_id;
        console.log(`🔍 getFormularioPorId llamado con ID: ${id}`);

        let sqlForm = 'SELECT id, titulo, empresa_id FROM formulario WHERE id = ? AND activo = 1 AND eliminado_en IS NULL';
        let paramsForm = [id];

        if (empresaId) {
          sqlForm += ' AND empresa_id = ?';
          paramsForm.push(empresaId);
        }

        const [formularioRows] = await pool.query(sqlForm, paramsForm);

        if (formularioRows.length === 0) {
          throw new Error('El formulario solicitado no existe o no pertenece a su organización.');
        }

        const formulario = formularioRows[0];

        // Se incluye LEFT JOIN a la tabla regla para obtener reglas condicionales
        const [preguntasRows] = await pool.query(
          `SELECT 
             p.id, 
             p.tipo, 
             p.texto AS etiqueta, 
             p.orden, 
             p.requerido,
             p.opciones,
             r.pregunta_origen_id AS dependeDeCampoId,
             r.valor AS mostrarSiValorIgualA
           FROM pregunta p
           INNER JOIN seccion s ON p.seccion_id = s.id
           LEFT JOIN regla r ON p.id = r.pregunta_destino_id
           WHERE s.formulario_id = ?
           ORDER BY s.orden ASC, p.orden ASC`,
          [id]
        );

        const camposMapeados = preguntasRows.map((campo) => ({
          id: String(campo.id),
          tipo: campo.tipo || 'TEXTO',
          etiqueta: campo.etiqueta || '',
          orden: Number(campo.orden) || 1,
          requerido: Boolean(campo.requerido),
          opciones: campo.opciones ? (typeof campo.opciones === 'string' ? campo.opciones : JSON.stringify(campo.opciones)) : null,
          dependeDeCampoId: campo.dependeDeCampoId ? String(campo.dependeDeCampoId) : null,
          mostrarSiValorIgualA: campo.mostrarSiValorIgualA || null,
        }));

        return {
          id: String(formulario.id),
          titulo: formulario.titulo,
          empresaId: String(formulario.empresa_id || empresaId || '1'),
          campos: camposMapeados,
        };
      } catch (error) {
        console.error('❌ Error en getFormularioPorId:', error.message);
        throw new Error(`Error en motor dinámico: ${error.message}`);
      }
    },

    // Obtiene el detalle de una inspección
    getDetalleRespuesta: async (_, { id }, context) => {
  requerirAuth(context.usuario);

  try {
    const [rows] = await pool.query(
      `SELECT 
         r.id,
         r.formulario_id AS formularioId,
         f.titulo AS tituloFormulario,
         r.usuario_id AS usuarioId,
         u.nombre AS nombreUsuario,
         u.email AS usuarioEmail,
         r.creado_en AS fechaCreado,
         r.latitud,
         r.longitud,
         r.datos AS respuestas
       FROM respuesta r
       JOIN formulario f ON r.formulario_id = f.id
       JOIN usuario u ON r.usuario_id = u.id
       WHERE r.id = ?`,
      [id]
    );

    if (rows.length === 0) {
      throw new Error('La inspección solicitada no existe.');
    }

    const row = rows[0];
    const mapaPreguntasGlobal = await construirMapaPreguntas([row.formularioId]);
    const mapaForm = mapaPreguntasGlobal[String(row.formularioId)] || {};

    // Decodificar el JSON de la columna datos
    let rawDatos = typeof row.respuestas === 'string' ? JSON.parse(row.respuestas) : (row.respuestas || {});
    let listaRespuestas = Array.isArray(rawDatos) 
      ? rawDatos 
      : (rawDatos.respuestas || rawDatos.datos || []);

    // Mapeo flexible para tolerar cualquier formato enviado por el móvil
    const respuestasEnriquecidas = listaRespuestas.map(item => {
      const cId = String(
        item.campoId || item.campo_id || item.preguntaId || item.pregunta_id || item.id || ''
      );
      
      const valorExtraido = item.valor !== undefined 
        ? item.valor 
        : (item.respuesta !== undefined ? item.respuesta : (item.texto || ''));

      return {
        campoId: cId,
        pregunta: item.pregunta || item.etiqueta || mapaForm[cId] || `Pregunta (${cId.substring(0, 8)})`,
        valor: typeof valorExtraido === 'object' ? JSON.stringify(valorExtraido) : String(valorExtraido)
      };
    });

    const fechaIso = row.fechaCreado ? new Date(row.fechaCreado).toISOString() : null;

    return {
      id: String(row.id),
      formularioId: String(row.formularioId),
      tituloFormulario: row.tituloFormulario,
      usuarioId: String(row.usuarioId),
      nombreUsuario: row.nombreUsuario,
      usuarioEmail: row.usuarioEmail || '',
      fechaCreado: fechaIso,
      latitud: row.latitud ? parseFloat(row.latitud) : null,
      longitud: row.longitud ? parseFloat(row.longitud) : null,
      respuestas: respuestasEnriquecidas
    };
  } catch (error) {
    console.error('❌ Error en getDetalleRespuesta:', error.message);
    throw new Error(`Error al obtener detalle de la inspección: ${error.message}`);
  }
},

    getInspeccionesPorEmpresa: async (_, __, context) => {
      requerirAuth(context.usuario);

      if (context.usuario.rol !== 'ADMIN') {
        throw new Error('Acceso denegado. Se requieren permisos de Administrador.');
      }

      const empresaId = context.usuario.empresa_id;

      try {
        const [rows] = await pool.query(
          `SELECT 
             r.id,
             r.formulario_id AS formularioId,
             f.titulo AS tituloFormulario,
             r.usuario_id AS usuarioId,
             u.nombre AS nombreUsuario,
             u.email AS usuarioEmail,
             r.creado_en AS fechaCreado,
             r.latitud,
             r.longitud,
             r.datos AS respuestas
           FROM respuesta r
           JOIN formulario f ON r.formulario_id = f.id
           JOIN usuario u ON r.usuario_id = u.id
           WHERE f.empresa_id = ?
           ORDER BY r.creado_en DESC`,
          [empresaId]
        );

        const formularioIds = rows.map(r => r.formularioId);
        const mapaPreguntasGlobal = await construirMapaPreguntas(formularioIds);

        return rows.map(row => {
          let rawDatos = typeof row.respuestas === 'string' ? JSON.parse(row.respuestas) : (row.respuestas || {});
          let listaRespuestas = Array.isArray(rawDatos) ? rawDatos : (rawDatos.respuestas || []);
          const mapaForm = mapaPreguntasGlobal[String(row.formularioId)] || {};

          const respuestasEnriquecidas = listaRespuestas.map(item => {
            const cId = String(item.campoId || item.preguntaId || item.id || '');
            return {
              ...item,
              campoId: cId,
              pregunta: item.pregunta || mapaForm[cId] || (cId ? `Pregunta (${cId.substring(0, 8)})` : 'Sin título'),
              valor: item.valor !== undefined ? item.valor : (item.respuesta !== undefined ? item.respuesta : '')
            };
          });

          const fechaIso = row.fechaCreado ? new Date(row.fechaCreado).toISOString() : null;
          const lat = row.latitud ? parseFloat(row.latitud) : null;
          const lng = row.longitud ? parseFloat(row.longitud) : null;

          return {
            id: String(row.id),
            formularioId: String(row.formularioId),
            formulario_id: String(row.formularioId),
            tituloFormulario: row.tituloFormulario,
            formulario_titulo: row.tituloFormulario,
            usuarioId: String(row.usuarioId),
            nombreUsuario: row.nombreUsuario,
            usuario_nombre_completo: row.nombreUsuario,
            usuario_email: row.usuarioEmail || '',
            fechaCreado: fechaIso,
            fecha_completado: fechaIso,
            estado: 'COMPLETADO',
            latitud: lat,
            ubicacion_lat: lat,
            longitud: lng,
            ubicacion_lng: lng,
            tiempo_respuesta_segundos: 0,
            pdf_generado: false,
            respuestas: respuestasEnriquecidas
          };
        });
      } catch (error) {
        throw new Error(`[Módulo Reportes Error]: ${error.message}`);
      }
    },

    totalInspeccionesPorEmpresa: async (_, __, context) => {
      requerirAuth(context.usuario);

      if (context.usuario.rol !== 'ADMIN') {
        throw new Error('No autorizado para ver estadísticas globales.');
      }

      const empresaId = context.usuario.empresa_id;

      try {
        const [rows] = await pool.query(
          `SELECT COUNT(r.id) AS total 
           FROM respuesta r
           JOIN formulario f ON r.formulario_id = f.id
           WHERE f.empresa_id = ?`,
          [empresaId]
        );
        
        return rows[0].total || 0;
      } catch (error) {
        throw new Error(`Error al calcular total de inspecciones: ${error.message}`);
      }
    },

    obtenerResumenEstatusFormularios: async (_, __, context) => {
      requerirAuth(context.usuario);

      if (context.usuario.rol !== 'ADMIN') {
        throw new Error('No autorizado para ver estadísticas globales.');
      }

      const empresaId = context.usuario.empresa_id;

      try {
        const [rows] = await pool.query(
          `SELECT 
             SUM(CASE WHEN activo = 1 THEN 1 ELSE 0 END) AS activos,
             SUM(CASE WHEN activo = 0 THEN 1 ELSE 0 END) AS inactivos,
             COUNT(*) AS total
           FROM formulario 
           WHERE empresa_id = ? AND eliminado_en IS NULL`,
          [empresaId]
        );

        const resultado = rows[0];
        return {
          activos: Number(resultado.activos) || 0,
          inactivos: Number(resultado.inactivos) || 0,
          total: Number(resultado.total) || 0
        };
      } catch (error) {
        throw new Error(`Error al obtener resumen de estatus: ${error.message}`);
      }
    },

    getHistorialRespuestas: async (_, __, context) => {
      requerirAuth(context.usuario);
      const usuarioId = context.usuario.id;

      try {
        const [rows] = await pool.query(
          `SELECT 
             r.id, 
             r.formulario_id AS formularioId, 
             f.titulo AS tituloFormulario,
             r.usuario_id AS usuarioId, 
             u.nombre AS nombreUsuario,
             u.email AS usuarioEmail,
             r.creado_en AS fechaCreado, 
             CAST(r.latitud AS DOUBLE) AS latitud, 
             CAST(r.longitud AS DOUBLE) AS longitud, 
             r.datos
           FROM respuesta r
           INNER JOIN formulario f ON r.formulario_id = f.id
           INNER JOIN usuario u ON r.usuario_id = u.id
           WHERE r.usuario_id = ?
           ORDER BY r.creado_en DESC`,
          [usuarioId]
        );

        const formularioIds = rows.map(r => r.formularioId);
        const mapaPreguntasGlobal = await construirMapaPreguntas(formularioIds);

        return rows.map((row) => {
          let rawDatos = typeof row.datos === 'string' ? JSON.parse(row.datos) : (row.datos || {});
          let listaRespuestas = Array.isArray(rawDatos) ? rawDatos : (rawDatos.respuestas || []);
          const mapaForm = mapaPreguntasGlobal[String(row.formularioId)] || {};

          const respuestasEnriquecidas = listaRespuestas.map(item => {
            const cId = String(item.campoId || item.preguntaId || item.id || '');
            return {
              ...item,
              campoId: cId,
              pregunta: item.pregunta || mapaForm[cId] || (cId ? `Pregunta (${cId.substring(0, 8)})` : 'Sin título'),
              valor: item.valor !== undefined ? item.valor : (item.respuesta !== undefined ? item.respuesta : '')
            };
          });

          const fechaIso = row.fechaCreado ? new Date(row.fechaCreado).toISOString() : null;
          const lat = row.latitud ? parseFloat(row.latitud) : null;
          const lng = row.longitud ? parseFloat(row.longitud) : null;

          return {
            id: String(row.id),
            formularioId: String(row.formularioId),
            formulario_id: String(row.formularioId),
            tituloFormulario: row.tituloFormulario,
            formulario_titulo: row.tituloFormulario,
            usuarioId: String(row.usuarioId),
            nombreUsuario: row.nombreUsuario,
            usuario_nombre_completo: row.nombreUsuario,
            usuario_email: row.usuarioEmail || '',
            fechaCreado: fechaIso,
            fecha_completado: fechaIso,
            estado: 'COMPLETADO',
            latitud: lat,
            ubicacion_lat: lat,
            longitud: lng,
            ubicacion_lng: lng,
            tiempo_respuesta_segundos: 0,
            pdf_generado: false,
            respuestas: respuestasEnriquecidas
          };
        });
      } catch (error) {
        console.error('❌ Error en getHistorialRespuestas:', error.message);
        throw new Error(`Error al obtener el historial: ${error.message}`);
      }
    }
  },

  Mutation: {
    login: async (_, { email, password }) => {
      const [rows] = await pool.query(
        'SELECT * FROM usuario WHERE email = ? AND activo = 1 AND eliminado_en IS NULL', 
        [email]
      );
      if (rows.length === 0) throw new Error('Usuario no registrado o inactivo.');

      const usuario = rows[0];
      const contraseñaValida = await bcrypt.compare(password, usuario.password);
      
      if (!contraseñaValida) throw new Error('Contraseña incorrecta.');

      const token = jwt.sign(
        { id: usuario.id, rol: usuario.rol, empresa_id: usuario.empresa_id, email: usuario.email },
        SECRET_KEY,
        { expiresIn: '8h' }
      );

      return { 
        token, 
        usuario: {
          id: String(usuario.id),
          empresa_id: String(usuario.empresa_id),
          nombre: usuario.nombre,
          email: usuario.email,
          rol: usuario.rol,
          activo: Boolean(usuario.activo)
        } 
      };
    },

    crearEmpresa: async (_, { nombre, logo_url }) => {
  const [uuidResult] = await pool.query('SELECT UUID() AS uuid');
  const nuevoId = uuidResult[0].uuid;

  await pool.query(
    'INSERT INTO empresa (id, nombre, logo) VALUES (?, ?, ?)',
    [nuevoId, nombre, logo_url]
  );

  const [rows] = await pool.query(
    'SELECT id, nombre, logo AS logo_url, activo FROM empresa WHERE id = ?',
    [nuevoId]
  );
  return { ...rows[0], id: String(rows[0].id) };
},

    crearFormularioConPreguntas: async (_, { titulo, descripcion, empresaId, preguntas }, context) => {
  requerirAuth(context.usuario);

  const targetEmpresaId = empresaId || context.usuario.empresa_id;
  if (!targetEmpresaId) {
    throw new Error('No se especificó la empresa a la que pertenece el formulario.');
  }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const [uuidResultForm] = await connection.query('SELECT UUID() AS uuid');
    const formularioId = uuidResultForm[0].uuid;

    await connection.query(
      `INSERT INTO formulario (id, empresa_id, titulo, descripcion, version, activo) 
       VALUES (?, ?, ?, ?, '1.0', 1)`,
      [formularioId, targetEmpresaId, titulo, descripcion || '']
    );

    const [uuidResultSeccion] = await connection.query('SELECT UUID() AS uuid');
    const seccionId = uuidResultSeccion[0].uuid;

    await connection.query(
      `INSERT INTO seccion (id, formulario_id, titulo, orden) 
       VALUES (?, ?, 'Sección General', 1)`,
      [seccionId, formularioId]
    );

    // Mapa para traducir: [ID Temporal Frontend] => [UUID Real MySQL]
    const mapaIds = {};

    // 1. Inserción de preguntas en MySQL y mapeo de IDs
    for (const preg of preguntas) {
      const [uuidResultPreg] = await connection.query('SELECT UUID() AS uuid');
      const realUuid = uuidResultPreg[0].uuid;

      // Guardamos la equivalencia del ID si viene del frontend
      if (preg.id) {
        mapaIds[String(preg.id)] = realUuid;
      }

      // Si depende de otra pregunta, arranca oculta
      const esVisible = preg.dependeDeCampoId ? 0 : 1;

      await connection.query(
        `INSERT INTO pregunta (id, seccion_id, tipo, texto, orden, requerido, visible, opciones) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          realUuid,
          seccionId,
          preg.tipo,
          preg.etiqueta,
          preg.orden,
          preg.requerido ? 1 : 0,
          esVisible,
          preg.opciones || null
        ]
      );
    }

    // 2. Inserción de Reglas usando los UUIDs traducidos
    for (const preg of preguntas) {
      if (preg.dependeDeCampoId && preg.mostrarSiValorIgualA) {
        // Traducimos los IDs temporales a los UUIDs reales recién insertados
        const origenRealUuid = mapaIds[String(preg.dependeDeCampoId)];
        const destinoRealUuid = mapaIds[String(preg.id)];

        if (origenRealUuid && destinoRealUuid) {
          const [uuidResultRegla] = await connection.query('SELECT UUID() AS uuid');
          const reglaId = uuidResultRegla[0].uuid;

          await connection.query(
            `INSERT INTO regla (id, pregunta_origen_id, pregunta_destino_id, condicion, valor, accion) 
             VALUES (?, ?, ?, 'IGUAL_A', ?, 'MOSTRAR')`,
            [
              reglaId,
              origenRealUuid,
              destinoRealUuid,
              preg.mostrarSiValorIgualA
            ]
          );
        }
      }
    }

    await connection.commit();

    return {
      id: String(formularioId),
      titulo,
      empresaId: String(targetEmpresaId),
    };
  } catch (error) {
    await connection.rollback();
    console.error('❌ Error al crear el formulario:', error.message);
    throw new Error(`Error en el servidor al guardar el formulario: ${error.message}`);
  } finally {
    connection.release();
  }
},

    cambiarEstadoFormulario: async (_, { id, activo }, context) => {
      requerirAuth(context.usuario);
      const [result] = await pool.query(
        'UPDATE formulario SET activo = ? WHERE id = ? AND empresa_id = ?', 
        [activo ? 1 : 0, id, context.usuario.empresa_id]
      );
      return result.affectedRows > 0;
    },

    eliminarFormulario: async (_, { id }, context) => {
      requerirAuth(context.usuario);
      const [result] = await pool.query(
        'UPDATE formulario SET eliminado_en = NOW() WHERE id = ? AND empresa_id = ?', 
        [id, context.usuario.empresa_id]
      );
      return result.affectedRows > 0;
    },

    guardarRespuestaMovil: async () => {
      return { success: true, message: "Modo dinámico activo. Utilice guardarRespuestasFormulario.", encabezado_id: 1 };
    },

    guardarRespuestasFormulario: async (_, { formularioId, usuarioId, respuestas, gps, archivos }, context) => {
      requerirAuth(context.usuario);

      try {
        if (!formularioId || !usuarioId || !respuestas || respuestas.length === 0) {
          throw new Error('Datos incompletos. El formulario debe contener respuestas.');
        }

        const latitud = gps ? gps.latitud : null;
        const longitud = gps ? gps.longitud : null;
        const payloadCompleto = {
          respuestas,
          archivos: archivos || []
        };

        const [insertResult] = await pool.query(
          `INSERT INTO respuesta (id, formulario_id, usuario_id, latitud, longitud, datos) 
           VALUES (UUID(), ?, ?, ?, ?, ?)`,
          [formularioId, usuarioId, latitud, longitud, JSON.stringify(payloadCompleto)]
        );

        return insertResult.affectedRows > 0;
      } catch (error) {
        console.error(`❌ Error controlado en guardarRespuestasFormulario: ${error.message}`);
        throw new Error(`Error en el servidor al procesar la inspección: ${error.message}`);
      }
    },

    generarPDF: async (_, { respuestaId }) => {
      try {
        return {
          success: true,
          url: `/api/inspecciones/${respuestaId}/pdf`,
          mensaje: 'PDF generado correctamente'
        };
      } catch (error) {
        return {
          success: false,
          url: null,
          mensaje: error.message
        };
      }
    }
  }
};

module.exports = resolvers;