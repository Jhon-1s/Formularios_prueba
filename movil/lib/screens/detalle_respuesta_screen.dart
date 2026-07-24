import 'dart:io';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';
import '../models/respuesta_model.dart';

class DetalleRespuestaScreen extends StatefulWidget {
  final int respuestaId;

  const DetalleRespuestaScreen({super.key, required this.respuestaId});

  @override
  State<DetalleRespuestaScreen> createState() => _DetalleRespuestaScreenState();
}

class _DetalleRespuestaScreenState extends State<DetalleRespuestaScreen> {
  Respuesta? _respuesta;
  bool _isLoading = true;
  bool _generandoPdf = false;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    setState(() => _isLoading = true);
    final data = await AuthService.getDetalleRespuesta(widget.respuestaId);
    if (data.isNotEmpty) {
      setState(() {
        _respuesta = Respuesta.fromJson(data);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // GENERAR Y DESCARGAR PDF
  // ============================================================
  Future<void> _generarPdf() async {
    setState(() => _generandoPdf = true);

    try {
      // Obtener preguntas del formulario (simulado)
      final preguntas = [
        {'id': 1, 'etiqueta': 'Nombre del auditor'},
        {'id': 2, 'etiqueta': '¿Se cumplen los requisitos?'},
        {'id': 3, 'etiqueta': 'Observaciones'},
      ];

      final file = await PdfService.generarPdf(
        tituloFormulario: _respuesta?.usuarioNombre ?? 'Formulario',
        empresaNombre: 'FormBuilder Solutions',
        logoUrl: '',
        respuesta: _respuesta!,
        preguntas: preguntas,
      );

      setState(() => _generandoPdf = false);

      // Mostrar éxito
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('✅ PDF Generado'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.picture_as_pdf, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text('PDF guardado en: ${file.path}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _generandoPdf = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error generando PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_respuesta == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle')),
        body: const Center(child: Text('No se encontró la respuesta')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Respuesta'),
        backgroundColor: const Color(0xFF3498db),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _generandoPdf 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                : const Icon(Icons.picture_as_pdf),
            onPressed: _generandoPdf ? null : _generarPdf,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info general
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            _respuesta!.usuarioNombre?.substring(0, 1).toUpperCase() ?? '?',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _respuesta!.usuarioNombre ?? 'Anónimo',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _respuesta!.usuarioEmail ?? '',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildInfoRow('📅 Fecha', _respuesta!.fechaFormateada),
                    _buildInfoRow('⏱️ Tiempo', _respuesta!.tiempoFormateado),
                    _buildInfoRow('📍 Ubicación', 
                        _respuesta!.latitud != null 
                            ? '${_respuesta!.latitud}, ${_respuesta!.longitud}' 
                            : 'No disponible'),
                    _buildInfoRow('📊 Estado', 
                        _respuesta!.estado, 
                        color: _respuesta!.estado == 'completado' ? Colors.green : Colors.orange),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Respuestas
            const Text(
              '📝 Respuestas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...?(_respuesta?.detalles?.map((detalle) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        detalle.preguntaEtiqueta ?? 'Pregunta ${detalle.preguntaId}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          detalle.valorMostrado,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )).toList()),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generandoPdf ? null : _generarPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(_generandoPdf ? 'Generando...' : '📄 Descargar PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: color ?? Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}