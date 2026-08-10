const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'db_formbuilder',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

// Prueba rápida de conexión al iniciar el backend
(async () => {
  try {
    const connection = await pool.getConnection();
    console.log('✅ Conexión exitosa a MySQL (db_formbuilder)');
    connection.release();
  } catch (error) {
    console.error('❌ Error de conexión a MySQL:', error.message);
  }
})();

module.exports = pool;