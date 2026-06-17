const pool = require('../database/db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const resolvers = {
  Query: {    
    ping: () => "pong",

    perfil: async (_, __, context) => {
      if (!context.usuario) throw new Error('No autorizado. Token inválido o ausente.');
      const [rows] = await pool.query('SELECT id, empresa_id, nombre, email, rol, activo FROM usuario WHERE id = ?', [context.usuario.id]);
      return rows[0];
    },

    getEmpresas: async () => {
      const [rows] = await pool.query('SELECT * FROM empresa');
      return rows;
    },

    getEmpresa: async (_, { id }) => {
      const [rows] = await pool.query('SELECT * FROM empresa WHERE id = ?', [id]);
      return rows[0];
    },

    getFormulariosDisponibles: async () => {
      try {
        const [rows] = await pool.query(
          "SELECT id, titulo, descripcion, version, estado FROM formulario WHERE estado = 'publicado'"
        );
        return rows;
      } catch (error) {
        throw new Error(`Error al obtener formularios: ${error.message}`);
      }
    },

    // --- ENDPOINT SEMANA 5: Apuntando a tu tabla real 'pregunta' ---
    getCamposPorSeccion: async (_, { seccion_id }) => {
      try {
        const [rows] = await pool.query(
          `SELECT 
            id, seccion_id, tipo_campo, etiqueta, ayuda, placeholder, orden,
            obligatorio, visible, editable,
            CAST(config AS CHAR) as config, 
            CAST(reglas_validacion AS CHAR) as reglas_validacion
          FROM pregunta 
          WHERE seccion_id = ? 
          ORDER BY orden ASC`,
          [seccion_id]
        );

        return rows.map(campo => ({
          ...campo,
          obligatorio: campo.obligatorio === 1,
          visible: campo.visible === 1,
          editable: campo.editable === 1,
          config: campo.config || "{}",
          reglas_validacion: campo.reglas_validacion || "{}"
        }));

      } catch (error) {
        throw new Error(`Error al obtener campos de la sección: ${error.message}`);
      }
    },

    // AHORA SÍ: getFormularioPorId dentro de las llaves de Query
    getFormularioPorId: async (_, { id, empresaId }) => {
      try {
        const [formResult] = await pool.query(
          'SELECT id, titulo FROM formularios WHERE id = ? AND empresa_id = ? AND estado = 1',
          [id, empresaId]
        );

        if (formResult.length === 0) {
          throw new Error('El formulario solicitado no existe o no pertenece a su organización.');
        }

        const formulario = formResult[0];

        const [camposResult] = await pool.query(
          'SELECT id, tipo, etiqueta, orden, configuracion FROM campos_formulario WHERE formulario_id = ? ORDER BY orden ASC',
          [id]
        );

        const camposMapeados = camposResult.map(campo => ({
          id: campo.id,
          tipo: campo.tipo,
          etiqueta: campo.etiqueta,
          orden: campo.orden,
          requerido: campo.configuracion?.requerido || false
        }));

        return {
          id: formulario.id,
          titulo: formulario.titulo,
          empresaId: empresaId,
          campos: camposMapeados
        };
      } catch (error) {
        throw new Error(`Error en motor dinámico: ${error.message}`);
      }
    },
    getInspeccionesPorEmpresa: async (_, { empresaId }) => {
      try {
        const [rows] = await pool.query(
          `SELECT 
            rf.id,
            rf.formulario_id AS formularioId,
            f.titulo AS tituloFormulario,
            rf.usuario_id AS usuarioId,
            u.nombre AS nombreUsuario,
            rf.created_at AS fechaCreado,
            rf.latitud,
            rf.longitud,
            rf.valores_respuestas AS respuestas
          FROM respuestas_formulario rf
          JOIN formularios f ON rf.formulario_id = f.id
          JOIN usuarios u ON rf.usuario_id = u.id
          WHERE f.empresa_id = ?
          ORDER BY rf.created_at DESC`,
          [empresaId]
        );

        // Mapeamos los resultados y parseamos el JSON string nativo de MySQL
        return rows.map(row => {
          let respuestasParseadas = [];
          try {
            respuestasParseadas = typeof row.respuestas === 'string' 
              ? JSON.parse(row.respuestas) 
              : (row.respuestas || []);
          } catch (e) {
            console.error(`Error al parsear JSON de la inspección ${row.id}:`, e);
          }

          return {
            id: row.id,
            formularioId: row.formularioId,
            tituloFormulario: row.tituloFormulario,
            usuarioId: row.usuarioId,
            nombreUsuario: row.nombreUsuario,
            fechaCreado: row.fechaCreado ? new Date(row.fechaCreado).toISOString() : null,
            latitud: parseFloat(row.latitud),
            longitud: parseFloat(row.longitud),
            respuestas: respuestasParseadas
          };
        });

      } catch (error) {
        throw new Error(`Error al generar el historial de reportes: ${error.message}`);
      }
    }
  },

  Mutation: {
    login: async (_, { email, password }) => {
      const [rows] = await pool.query('SELECT * FROM usuario WHERE email = ?', [email]);
      if (rows.length === 0) throw new Error('Usuario no registrado.');

      const usuario = rows[0];
      const contraseñaValida = (usuario.password_hash === password) || await bcrypt.compare(password, usuario.password_hash);
      
      if (!contraseñaValida) throw new Error('Contraseña incorrecta.');

      const token = jwt.sign(
        { id: usuario.id, rol: usuario.rol, empresa_id: usuario.empresa_id },
        process.env.JWT_SECRET || 'clave_secreta_por_defecto',
        { expiresIn: '8h' }
      );

      return { token, usuario };
    },

    crearEmpresa: async (_, { nombre, logo_url }) => {
      const [result] = await pool.query('INSERT INTO empresa (nombre, logo_url) VALUES (?, ?)', [nombre, logo_url]);
      const [rows] = await pool.query('SELECT * FROM empresa WHERE id = ?', [result.insertId]);
      return rows[0];
    },

    guardarRespuestaMovil: async (_, { formulario_id, usuario_email, usuario_nombre_completo, respuestas }) => {
      try {
        const [encabezadoResult] = await pool.query(
          `INSERT INTO respuesta_encabezado (formulario_id, usuario_email, usuario_nombre_completo, estado) VALUES (?, ?, ?, 'completado')`,
          [formulario_id, usuario_email, usuario_nombre_completo]
        );

        const encabezadoId = encabezadoResult.insertId;

        for (const resp of respuestas) {
          await pool.query(
            `INSERT INTO respuesta_detalle (respuesta_encabezado_id, pregunta_id, valor_texto, valor_numero, valor_booleano) VALUES (?, ?, ?, ?, ?)`,
            [encabezadoId, resp.pregunta_id, resp.valor_texto, resp.valor_numero, resp.valor_booleano]
          );
        }

        return { success: true, message: "Respuestas guardadas exitosamente en el servidor.", encabezado_id: encabezadoId };
      } catch (error) {
        return { success: false, message: `Error al almacenar respuestas: ${error.message}`, encabezado_id: null };
      }
    },

    guardarRespuestasFormulario: async (_, { formularioId, usuarioId, respuestas, gps }) => {
      try {
        const { latitud, longitud } = gps;
        const respuestasJsonString = JSON.stringify(respuestas);

        const [insertResult] = await pool.query(
          `INSERT INTO respuestas_formulario 
           (formulario_id, usuario_id, latitud, longitud, valores_respuestas) 
           VALUES (?, ?, ?, ?, ?)`,
          [formularioId, usuarioId, latitud, longitud, respuestasJsonString]
        );

        return insertResult.affectedRows > 0;
      } catch (error) {
        throw new Error(`Error al almacenar respuestas y GPS: ${error.message}`);
      }
    }
  }
};

module.exports = resolvers;