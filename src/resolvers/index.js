const pool = require('../database/db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const resolvers = {
  Query: {
    ping: () => '🚀 Servidor conectado a formularios_dinamicos',
    
    perfil: async (_, __, context) => {
      if (!context.usuario) throw new Error('No autorizado.');
      const [rows] = await pool.query('SELECT id, nombre, email, rol, empresa_id FROM usuario WHERE id = ?', [context.usuario.id]);
      return rows[0];
    },

    getEmpresas: async (_, __, context) => {
      if (!context.usuario) throw new Error('No autorizado.');
      const [rows] = await pool.query('SELECT * FROM empresa');
      return rows;
    },

    getEmpresa: async (_, { id }, context) => {
      if (!context.usuario) throw new Error('No autorizado.');
      const [rows] = await pool.query('SELECT * FROM empresa WHERE id = ?', [id]);
      return rows[0] || null;
    }
  },

  Mutation: {
    login: async (_, { email, password }) => {
      // 1. Buscamos por email
      const [rows] = await pool.query('SELECT * FROM usuario WHERE email = ?', [email]);
      if (rows.length === 0) throw new Error('Usuario no registrado.');
      
      const usuario = rows[0];

      // 2. Comparamos contraseña (híbrido texto plano o bcrypt)
      // Nota: Tu script usa el campo "password_hash"
      const contraseñaValida = (usuario.password_hash === password) || await bcrypt.compare(password, usuario.password_hash);
      if (!contraseñaValida) throw new Error('Contraseña incorrecta.');

      // 3. Generamos Token
      const token = jwt.sign(
        { id: usuario.id, rol: usuario.rol, empresa_id: usuario.empresa_id },
        process.env.JWT_SECRET,
        { expiresIn: '8h' }
      );

      return { token, usuario };
    },

    crearEmpresa: async (_, { nombre, logo_url }, context) => {
      // Modificado para alinearse al AUTO_INCREMENT de tu tabla SQL
      try {
        const [result] = await pool.query('INSERT INTO empresa (nombre, logo_url) VALUES (?, ?)', [nombre, logo_url]);
        const [rows] = await pool.query('SELECT * FROM empresa WHERE id = ?', [result.insertId]);
        return rows[0];
      } catch (error) {
        throw new Error(`Error al crear empresa: ${error.message}`);
      }
    }
  }
};

module.exports = resolvers;