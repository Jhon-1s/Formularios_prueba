const pool = require('../database/db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const resolvers = {
  Query: {
    // --- SEMANA 1, 2 Y 3 ---
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

    // --- SEMANA 4: DESCARGA DE FORMULARIOS ---
    // Endpoint para que Flutter descargue los formularios publicados
    getFormulariosDisponibles: async () => {
      try {
        const [rows] = await pool.query(
          "SELECT id, titulo, descripcion, version, estado FROM formulario WHERE estado = 'publicado'"
        );
        return rows;
      } catch (error) {
        throw new Error(`Error al obtener formularios: ${error.message}`);
      }
    }
  },

  Mutation: {
    // --- SEMANA 2: LOGIN CON AUTENTICACIÓN HÍBRIDA ---
    login: async (_, { email, password }) => {
      // 1. Buscar usuario por email
      const [rows] = await pool.query('SELECT * FROM usuario WHERE email = ?', [email]);
      if (rows.length === 0) {
        throw new Error('Usuario no registrado.');
      }

      const usuario = rows[0];

      // 2. Validar contraseña (Acepta texto plano para desarrollo y Bcrypt)
      const contraseñaValida = (usuario.password_hash === password) || await bcrypt.compare(password, usuario.password_hash);
      
      if (!contraseñaValida) {
        throw new Error('Contraseña incorrecta.');
      }

      // 3. Generar Token JWT válido por 8 horas
      const token = jwt.sign(
        { id: usuario.id, rol: usuario.rol, empresa_id: usuario.empresa_id },
        process.env.JWT_SECRET || 'clave_secreta_por_defecto',
        { expiresIn: '8h' }
      );

      return {
        token,
        usuario
      };
    },

    // --- SEMANA 3: GESTIÓN DE EMPRESAS ---
    crearEmpresa: async (_, { nombre, logo_url }) => {
      const [result] = await pool.query(
        'INSERT INTO empresa (nombre, logo_url) VALUES (?, ?)',
        [nombre, logo_url]
      );
      const [rows] = await pool.query('SELECT * FROM empresa WHERE id = ?', [result.insertId]);
      return rows[0];
    },

    // --- SEMANA 4: GUARDADO DE RESPUESTAS DESDE MÓVIL ---
    // Endpoint para recibir y almacenar las respuestas del celular
    guardarRespuestaMovil: async (_, { formulario_id, usuario_email, usuario_nombre_completo, respuestas }) => {
      try {
        // A. Insertar el encabezado de la respuesta
        const [encabezadoResult] = await pool.query(
          `INSERT INTO respuesta_encabezado 
          (formulario_id, usuario_email, usuario_nombre_completo, estado) 
          VALUES (?, ?, ?, 'completado')`,
          [formulario_id, usuario_email, usuario_nombre_completo]
        );

        const encabezadoId = encabezadoResult.insertId;

        // B. Insertar cada una de las respuestas de las preguntas en el detalle
        for (const resp of respuestas) {
          await pool.query(
            `INSERT INTO respuesta_detalle 
            (respuesta_encabezado_id, pregunta_id, valor_texto, valor_numero, valor_booleano) 
            VALUES (?, ?, ?, ?, ?)`,
            [encabezadoId, resp.pregunta_id, resp.valor_texto, resp.valor_numero, resp.valor_booleano]
          );
        }

        return {
          success: true,
          message: "Respuestas guardadas exitosamente en el servidor.",
          encabezado_id: encabezadoId
        };

      } catch (error) {
        return {
          success: false,
          message: `Error al almacenar respuestas: ${error.message}`,
          encabezado_id: null
        };
      }
    }
  }
};

module.exports = resolvers;