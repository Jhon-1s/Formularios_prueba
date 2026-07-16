const pool = require('../database/db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const resolvers = {
  Query: {    
    ping: () => "pong",

    perfil: async (_, __, context) => {
      if (!context.usuario) throw new Error('No autorizado. Token inválido o ausente.');
      const [rows] = await pool.query('SELECT id, empresa_id, nombre, correo as email, rol, estado FROM usuarios WHERE id = ?', [context.usuario.id]);
      return rows[0];
    },

    getEmpresas: async () => {
      const [rows] = await pool.query('SELECT id, nombre, logo_url, estado FROM empresas');
      return rows;
    },

    getEmpresa: async (_, { id }) => {
      const [rows] = await pool.query('SELECT id, nombre, logo_url, estado FROM empresas WHERE id = ?', [id]);
      return rows[0];
    },

    getFormulariosDisponibles: async () => {
      try {
        const [rows] = await pool.query(
          "SELECT id, titulo, descripcion, '1' as version, estado FROM formularios WHERE estado = 1"
        );
        return rows;
      } catch (error) {
        throw new Error(`Error al obtener formularios: ${error.message}`);
      }
    },

    getCamposPorSeccion: async (_, { seccion_id }) => {
      try {
        const [rows] = await pool.query(
          `SELECT id, formulario_id as seccion_id, tipo, etiqueta, orden, configuracion 
           FROM campos_formulario 
           WHERE formulario_id = ? 
           ORDER BY orden ASC`,
          [seccion_id]
        );

        return rows.map(campo => ({
          id: campo.id,
          seccion_id: campo.seccion_id,
          tipo_campo: campo.tipo,
          etiqueta: campo.etiqueta,
          ayuda: "",
          placeholder: "",
          orden: campo.orden,
          obligatorio: campo.configuracion?.requerido || false,
          visible: true,
          editable: true,
          config: JSON.stringify(campo.configuracion || {}),
          reglas_validacion: "{}"
        }));
      } catch (error) {
        throw new Error(`Error al obtener campos de la sección: ${error.message}`);
      }
    },

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

    getInspeccionesPorEmpresa: async (_, { empresaId }, context) => {
      try {
        if (!context.usuario) {
          throw new Error('No autorizado. Token inválido o ausente.');
        }

        if (context.usuario.rol !== 'ADMIN') {
          throw new Error('Acceso denegado. Se requieren permisos de Administrador.');
        }

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
        throw new Error(`[Módulo Reportes Error]: ${error.message}`);
      }
    },

    // === NUEVAS QUERIES MÓDULO DASHBOARD SEMANA 10 ===
    totalInspeccionesPorEmpresa: async (_, { empresaId }, context) => {
      try {
        if (!context.usuario || context.usuario.rol !== 'ADMIN') {
          throw new Error('No autorizado para ver estadísticas globales.');
        }

        const [rows] = await pool.query(
          `SELECT COUNT(rf.id) AS total 
           FROM respuestas_formulario rf
           JOIN formularios f ON rf.formulario_id = f.id
           WHERE f.empresa_id = ?`,
          [empresaId]
        );
        
        return rows[0].total || 0;
      } catch (error) {
        throw new Error(`Error al calcular total de inspecciones: ${error.message}`);
      }
    },

    obtenerResumenEstatusFormularios: async (_, { empresaId }, context) => {
      try {
        if (!context.usuario || context.usuario.rol !== 'ADMIN') {
          throw new Error('No autorizado para ver estadísticas globales.');
        }

        const [rows] = await pool.query(
          `SELECT 
            SUM(CASE WHEN estado = 1 THEN 1 ELSE 0 END) AS activos,
            SUM(CASE WHEN estado = 0 THEN 1 ELSE 0 END) AS inactivos,
            COUNT(*) AS total
           FROM formularios 
           WHERE empresa_id = ?`,
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
    }
  }, // <--- Aquí se cierra Query correctamente

  Mutation: {
    login: async (_, { email, password }) => {
      const [rows] = await pool.query('SELECT * FROM usuarios WHERE correo = ?', [email]);
      if (rows.length === 0) throw new Error('Usuario no registrado.');

      const usuario = rows[0];
      const contraseñaValida = (usuario.password_hash === password) || await bcrypt.compare(password, usuario.password_hash);
      
      if (!contraseñaValida) throw new Error('Contraseña incorrecta.');

      const token = jwt.sign(
        { id: usuario.id, rol: usuario.rol, empresa_id: usuario.empresa_id },
        process.env.JWT_SECRET || 'clave_secreta_por_defecto',
        { expiresIn: '8h' }
      );

      return { 
        token, 
        usuario: {
          ...usuario,
          email: usuario.correo,
          activo: usuario.estado === 1
        } 
      };
    },

    crearEmpresa: async (_, { nombre, logo_url }) => {
      const [result] = await pool.query('INSERT INTO empresas (nombre, logo_url) VALUES (?, ?)', [nombre, logo_url]);
      const [rows] = await pool.query('SELECT id, nombre, logo_url, estado FROM empresas WHERE id = ?', [result.insertId]);
      return rows[0];
    },

    guardarRespuestaMovil: async (_, { formulario_id, usuario_email, usuario_nombre_completo, respuestas }) => {
      try {
        return { success: true, message: "Modo dinámico activo. Redirigido a guardarRespuestasFormulario.", encabezado_id: 1 };
      } catch (error) {
        return { success: false, message: `Error: ${error.message}`, encabezado_id: null };
      }
    },

    guardarRespuestasFormulario: async (_, { formularioId, usuarioId, respuestas, gps }, context) => {
      try {
        if (!formularioId || !usuarioId || !respuestas || respuestas.length === 0) {
          throw new Error('Datos incompletos. El formulario debe contener respuestas.');
        }

        const { latitud, longitud } = gps;
        if (latitud === undefined || longitud === undefined) {
          throw new Error('Se requiere geolocalización GPS válida para registrar la inspección.');
        }

        const respuestasJsonString = JSON.stringify(respuestas);

        const [insertResult] = await pool.query(
          `INSERT INTO respuestas_formulario 
           (formulario_id, usuario_id, latitud, longitud, valores_respuestas) 
           VALUES (?, ?, ?, ?, ?)`,
          [formularioId, usuarioId, latitud, longitud, respuestasJsonString]
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