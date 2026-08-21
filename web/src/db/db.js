import Dexie from 'dexie';

export const db = new Dexie('InspeccionesOfflineDB');

// Definición de tablas e índices primarios
db.version(1).stores({
  formularios: 'id, titulo',                  // plantillas de formularios
  respuestas: '++id, formularioId, estado'    // respuestas/evidencias
});