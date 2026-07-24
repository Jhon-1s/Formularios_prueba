import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import '../models/respuesta_model.dart';

class PdfService {
  // ============================================================
  // GENERAR PDF DEL FORMULARIO
  // ============================================================
  static Future<File> generarPdf({
    required String tituloFormulario,
    required String empresaNombre,
    required String logoUrl,
    required Respuesta respuesta,
    required List<Map<String, dynamic>> preguntas,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            // HEADER
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              color: PdfColors.blue50,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        empresaNombre,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        tituloFormulario,
                        style: const pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.blue700,
                        ),
                      ),
                    ],
                  ),
                  if (logoUrl.isNotEmpty)
                    pw.Image(
                      pw.MemoryImage(
                        await _descargarLogo(logoUrl),
                      ),
                      width: 60,
                      height: 60,
                    ),
                ],
              ),
            ),

            // INFO GENERAL
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '📋 Información General',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text('👤 Usuario: ${respuesta.usuarioNombre ?? 'N/A'}'),
                      ),
                      pw.Expanded(
                        child: pw.Text('📧 Email: ${respuesta.usuarioEmail ?? 'N/A'}'),
                      ),
                    ],
                  ),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text('📅 Fecha: ${respuesta.fechaFormateada}'),
                      ),
                      pw.Expanded(
                        child: pw.Text('⏱️ Tiempo: ${respuesta.tiempoFormateado}'),
                      ),
                    ],
                  ),
                  if (respuesta.latitud != null)
                    pw.Text('📍 Ubicación: ${respuesta.latitud}, ${respuesta.longitud}'),
                ],
              ),
            ),

            // RESPUESTAS
            pw.SizedBox(height: 16),
            pw.Text(
              '📝 Respuestas',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            ...preguntas.map((pregunta) {
              final detalle = respuesta.detalles?.firstWhere(
                (d) => d.preguntaId == pregunta['id'],
                orElse: () => RespuestaDetalle(
                  preguntaId: pregunta['id'],
                  valorTexto: 'Sin respuesta',
                ),
              );
              return pw.Container(
                padding: const pw.EdgeInsets.all(8),
                margin: const pw.EdgeInsets.only(bottom: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey200),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        pregunta['etiqueta'] ?? '',
                        style: const pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        detalle?.valorMostrado ?? 'Sin respuesta',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),

            // FOOTER
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              color: PdfColors.grey100,
              child: pw.Center(
                child: pw.Text(
                  'Documento generado automáticamente por FormBuilder',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ),
          ];
        },
      ),
    );

    // Guardar PDF en archivo temporal
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/reporte_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ============================================================
  // DESCARGAR LOGO
  // ============================================================
  static Future<List<int>> _descargarLogo(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print('Error descargando logo: $e');
    }
    // Logo por defecto
    return _defaultLogo();
  }

  static List<int> _defaultLogo() {
    final pdf = pw.Document();
    return pdf.save();
  }
}