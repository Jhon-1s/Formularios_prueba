class AppConstants {
  // URL del backend
  static const String apiUrl = 'https://presoak-edge-chance.ngrok-free.dev/graphql';
  
  // Tamaños máximos
  static const int maxImageWidth = 1024;
  static const int maxImageHeight = 1024;
  static const int imageQuality = 70;
  static const int maxFileSizeMB = 10;
  
  // Cache
  static const String cacheFormulariosKey = 'formularios_cache';
  static const String cacheRespuestasKey = 'respuestas_pendientes';
  
  // Timeouts
  static const int connectionTimeoutSeconds = 30;
  static const int uploadTimeoutSeconds = 60;
  
  // Mensajes
  static const String msgSinConexion = '⚠️ Sin conexión a internet. Los datos se guardarán localmente.';
  static const String msgErrorServidor = '❌ Error en el servidor. Intenta nuevamente.';
  static const String msgExito = '✅ Formulario guardado correctamente.';
}