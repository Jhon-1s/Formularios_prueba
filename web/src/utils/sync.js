import { db } from '../db/db';

export const sincronizarDatos = async (mutationApollo) => {
  // Si no hay red, aborta
  if (!navigator.onLine) return;

  // Buscar inspecciones no subidas
  const pendientes = await db.respuestas.where('estado').equals('pendiente').toArray();
  
  if (pendientes.length === 0) return;

  console.log(`Sincronizando ${pendientes.length} registros...`);

  for (const registro of pendientes) {
    try {
      // 1. Extraer archivos Blob (fotos) y subirlos si es necesario
      // 2. Ejecutar la mutación GraphQL con los datos del registro
      
      /* Ejemplo si usas la mutación de GraphQL directamente:
      await mutationApollo({
        variables: {
          formularioId: registro.formularioId,
          respuestas: registro.datos,
        },
      });
      */

      // Marcar como subido en la BD local al tener éxito
      await db.respuestas.update(registro.id, { estado: 'sincronizado' });
      console.log(`Registro ${registro.id} sincronizado con éxito.`);
    } catch (error) {
      console.error(`Error al sincronizar registro ${registro.id}:`, error);
    }
  }
};

// Escuchar automáticamente la reconexión a Internet
export const iniciarOyenteDeRed = (mutationApollo) => {
  window.addEventListener('online', () => {
    console.log('Conexión reestablecida. Iniciando sincronización...');
    sincronizarDatos(mutationApollo);
  });
};