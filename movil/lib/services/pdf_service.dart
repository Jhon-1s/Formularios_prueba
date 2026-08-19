import 'dart:io';
import 'dart:convert';
import 'dart:html' as html;  // ✅ IMPORTANTE: Para web
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PdfService {
  static const String apiUrl = 'https://presoak-edge-chance.ngrok-free.dev/graphql';

  // ============================================================
  // VERIFICAR SI EL PDF YA EXISTE LOCALMENTE
  // ============================================================
  static Future<bool> pdfExisteLocal(String respuestaId) async {
    try {
      if (kIsWeb) {
        return false;
      }
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/reporte_$respuestaId.pdf';
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      print('❌ Error verificando PDF: $e');
      return false;
    }
  }

  // ============================================================
  // GENERAR Y DESCARGAR PDF
  // ============================================================
  static Future<String> generarYDescargarPDF({
    required String respuestaId,
    required int empresaId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No hay sesión activa');
      }

      const String mutation = '''
        mutation GenerarPDF(\$respuestaId: ID!, \$empresaId: Int!) {
          generarPDF(respuestaId: \$respuestaId, empresaId: \$empresaId) {
            success
            url
            mensaje
          }
        }
      ''';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'query': mutation,
          'variables': {
            'respuestaId': respuestaId,
            'empresaId': empresaId,
          },
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Error al generar PDF');
      }

      final data = jsonDecode(response.body);
      if (data['data'] == null || data['data']['generarPDF'] == null) {
        throw Exception('Error en el servidor');
      }

      final pdfData = data['data']['generarPDF'];
      if (pdfData['success'] != true) {
        throw Exception(pdfData['mensaje'] ?? 'Error desconocido');
      }

      final pdfUrl = pdfData['url'];
      final fullUrl = pdfUrl.startsWith('http')
          ? pdfUrl
          : 'https://presoak-edge-chance.ngrok-free.dev$pdfUrl';

      final pdfResponse = await http.get(Uri.parse(fullUrl));

      if (pdfResponse.statusCode != 200) {
        throw Exception('Error al descargar PDF');
      }

      // ✅ GUARDAR EN WEB O MÓVIL
      if (kIsWeb) {
        // En web, descargar directamente con anchor
        final blob = html.Blob([pdfResponse.bodyBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'reporte_$respuestaId.pdf')
          ..click();
        html.Url.revokeObjectUrl(url);
        return 'PDF descargado en el navegador';
      } else {
        // En móvil, guardar localmente
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/reporte_$respuestaId.pdf';
        final file = File(filePath);
        await file.writeAsBytes(pdfResponse.bodyBytes);
        return filePath;
      }
    } catch (e) {
      print('❌ Error generando PDF: $e');
      rethrow;
    }
  }

  // ============================================================
  // ELIMINAR PDF LOCAL
  // ============================================================
  static Future<void> eliminarPDFLocal(String respuestaId) async {
    try {
      if (kIsWeb) return;
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/reporte_$respuestaId.pdf';
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('❌ Error eliminando PDF: $e');
    }
  }
}