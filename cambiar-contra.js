const pool = require('./src/database/db'); // Revisa que esta ruta sea correcta a tu db.js
const bcrypt = require('bcryptjs');

async function actualizar() {
  try {
    const nuevaContraPlana = 'admin123';
    // Encriptamos la nueva contraseña con bcrypt
    const nuevoHash = await bcrypt.hash(nuevaContraPlana, 10);
    
    // Actualizamos al usuario administrador en tu base de datos
    // Usamos correo o ID. Vamos a actualizar al usuario con rol ADMIN
    const [result] = await pool.query(
      "UPDATE usuarios SET password_hash = ? WHERE rol = 'ADMIN'",
      [nuevoHash]
    );

    console.log(`✅ ¡Contraseña actualizada con éxito!`);
    console.log(`🔐 Tu nueva contraseña es: admin123`);
    console.log(`Filas afectadas: ${result.affectedRows}`);
    process.exit(0);
  } catch (error) {
    console.error('❌ Error al actualizar contraseña:', error);
    process.exit(1);
  }
}

actualizar();