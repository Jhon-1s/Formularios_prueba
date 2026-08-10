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
      const [rows] = await pool.query('SELECT id, nombre, logo_url, activo FROM empresa');
      return rows;
    },

    getEmpresa: async (_, { id }) => {
      const [rows] = await pool.query('SELECT id, nombre, logo_url, activo FROM empresa WHERE id = ?', [id]);
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
          `SELECT id, seccion_id, tipo, texto AS etiqueta, orden, requerido, visible, solo_lectura AS editable, opciones
           FROM pregunta 
           WHERE seccion_id = ? 
           ORDER BY orden ASC`,
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
          config: campo.opciones ? JSON.stringify(campo.opciones) : "{}",
          reglas_validacion: "{}"
        }));
      } catch (error) {
        throw new Error(`Error al obtener campos de la sección: ${error.message}`);
      }
    },

    getFormularioPorId: async (_, { id }, context) => {
      requerirAuth(context.usuario);
      const empresaId = context.usuario.empresa_id;

      try {
        console.log(`🔍 Cargando formulario ID: ${id} para empresa: ${empresaId}`);

        // 1. Obtener la cabecera del formulario
        const [formResult] = await pool.query(
          'SELECT id, titulo FROM formulario WHERE id = ? AND empresa_id = ? AND activo = 1 AND eliminado_en IS NULL',
          [id, empresaId]
        );

        if (formResult.length === 0) {
          throw new Error('El formulario solicitado no existe o no pertenece a su organización.');
        }

        const formulario = formResult[0];

        // 2. Obtener preguntas vinculadas al formulario o a sus secciones
        const [preguntasResult] = await pool.query(
          `SELECT p.id, p.tipo, p.texto AS etiqueta, p.orden, p.requerido 
           FROM pregunta p
           LEFT JOIN seccion s ON p.seccion_id = s.id
           WHERE p.seccion_id = ? OR s.formulario_id = ?
           ORDER BY p.orden ASC`,
          [id, id]
        );

        // 3. Mapear garantizando tipos válidos para GraphQL
        const camposMapeados = preguntasResult.map(campo => ({
          id: String(campo.id),
          tipo: campo.tipo || 'TEXTO',
          etiqueta: campo.etiqueta || '',
          orden: Number(campo.orden) || 1,
          requerido: Boolean(campo.requerido)
        }));

        return {
          id: String(formulario.id),
          titulo: formulario.titulo,
          empresaId: String(empresaId),
          campos: camposMapeados
        };
      } catch (error) {
        console.error(`❌ Error en getFormularioPorId: ${error.message}`);
        throw new Error(`Error en motor dinámico: ${error.message}`);
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
            id: String(row.id),
            formularioId: String(row.formularioId),
            tituloFormulario: row.tituloFormulario,
            usuarioId: String(row.usuarioId),
            nombreUsuario: row.nombreUsuario,
            fechaCreado: row.fechaCreado ? new Date(row.fechaCreado).toISOString() : null,
            latitud: row.latitud ? parseFloat(row.latitud) : null,
            longitud: row.longitud ? parseFloat(row.longitud) : null,
            respuestas: respuestasParseadas
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
          activos: resultado.activos || 0,
          inactivos: resultado.inactivos || 0,
          total: resultado.total || 0
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

        return rows.map((fila) => {
          let respuestasParseadas = [];
          try {
            respuestasParseadas = typeof fila.datos === 'string' 
              ? JSON.parse(fila.datos) 
              : fila.datos;
          } catch (e) {
            respuestasParseadas = [];
          }

          return {
            id: String(fila.id),
            formularioId: String(fila.formularioId),
            tituloFormulario: fila.tituloFormulario,
            usuarioId: String(fila.usuarioId),
            nombreUsuario: fila.nombreUsuario,
            fechaCreado: String(fila.fechaCreado),
            latitud: fila.latitud,
            longitud: fila.longitud,
            respuestas: respuestasParseadas,
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
      const [result] = await pool.query('INSERT INTO empresa (nombre, logo_url) VALUES (?, ?)', [nombre, logo_url]);
      const [rows] = await pool.query('SELECT id, nombre, logo_url, activo FROM empresa WHERE id = ?', [result.insertId]);
      return { ...rows[0], id: String(rows[0].id) };
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
    }
  }
};

module.exports = resolvers;