import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

class UploadService {
  static const String apiUrl = 'https://presoak-edge-chance.ngrok-free.dev/graphql';
  
  // ============================================================
  // SUBIR ARCHIVO (FOTO O FIRMA) AL SERVIDOR
  // ============================================================
  static Future<Map<String, dynamic>> subirArchivo({
    required File archivo,
    required String tipo, // 'foto' o 'firma'
    required int preguntaId,
    required int formularioId,
  }) async {
    try {
      // 1. Convertir archivo a Base64
      final bytes = await archivo.readAsBytes();
      final base64String = base64Encode(bytes);
      final mimeType = _getMimeType(archivo.path);
      
      // 2. Crear el objeto de archivo para GraphQL
      final archivoInput = {
        'nombreOriginal': path.basename(archivo.path),
        'mimeType': mimeType,
        'base64': base64String,
        'tipo': tipo,
        'preguntaId': preguntaId,
        'formularioId': formularioId,
      };
      
      // 3. Enviar al backend
      const String mutation = '''
        mutation SubirArchivo(\$archivo: ArchivoInput!) {
          subirArchivo(archivo: \$archivo) {
            success
            url
            mensaje
          }
        }
      ''';

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'query': mutation,
          'variables': {'archivo': archivoInput},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['subirArchivo'] != null) {
          return data['data']['subirArchivo'];
        }
      }
      return {'success': false, 'mensaje': 'Error al subir archivo'};
    } catch (e) {
      return {'success': false, 'mensaje': 'Error: $e'};
    }
  }

  // ============================================================
  // OBTENER MIME TYPE DEL ARCHIVO
  // ============================================================
  static String _getMimeType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  // ============================================================
  // SUBIR MÚLTIPLES ARCHIVOS
  // ============================================================
  static Future<List<Map<String, dynamic>>> subirMultiplesArchivos({
    required List<File> archivos,
    required String tipo,
    required int preguntaId,
    required int formularioId,
  }) async {
    final List<Map<String, dynamic>> resultados = [];
    for (var archivo in archivos) {
      final resultado = await subirArchivo(
        archivo: archivo,
        tipo: tipo,
        preguntaId: preguntaId,
        formularioId: formularioId,
      );
      resultados.add(resultado);
    }
    return resultados;
  }
}