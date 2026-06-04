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
        // Cambiado a FROM pregunta para que coincida perfectamente con tu MySQL
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

        // Mapeamos los tinyint (0 o 1) de MySQL a booleanos reales de GraphQL
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
    }
  }
};

module.exports = resolvers;