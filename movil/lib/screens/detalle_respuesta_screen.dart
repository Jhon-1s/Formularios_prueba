import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/respuesta_model.dart';

class DetalleRespuestaScreen extends StatefulWidget {
  final String respuestaId;

  const DetalleRespuestaScreen({super.key, required this.respuestaId});

  @override
  State<DetalleRespuestaScreen> createState() => _DetalleRespuestaScreenState();
}

class _DetalleRespuestaScreenState extends State<DetalleRespuestaScreen> {
  Respuesta? _respuesta;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

Future<void> _cargarDetalle() async {
  setState(() => _isLoading = true);
  try {
    final data = await AuthService.getDetalleRespuesta(widget.respuestaId);
    
    print('🔍 Detalle respuesta recibido: ${data.keys}');
    print('🔍 Detalles: ${data['detalles']}');
    
    if (data.isNotEmpty && data['detalles'] != null) {
      setState(() {
        _respuesta = Respuesta.fromJson(data);
        _isLoading = false;
      });
      print('✅ Respuesta cargada con ${_respuesta?.totalDetalles ?? 0} detalles');
    } else {
      print('⚠️ No se encontraron detalles');
      setState(() => _isLoading = false);
    }
  } catch (e) {
    print('❌ Error cargando detalle: $e');
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al cargar: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_respuesta == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalle'),
          backgroundColor: const Color(0xFF3498db),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('No se encontró la respuesta')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Respuesta'),
        backgroundColor: const Color(0xFF3498db),
        foregroundColor: Colors.white,
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
                        Expanded(
                          child: Column(
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
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildInfoRow('📅 Fecha', _respuesta!.fechaFormateada),
                    _buildInfoRow('⏱️ Tiempo', _respuesta!.tiempoFormateado),
                    _buildInfoRow(
                      '📍 Ubicación',
                      _respuesta!.latitud != null
                          ? '${_respuesta!.latitud}, ${_respuesta!.longitud}'
                          : 'No disponible',
                    ),
                    _buildInfoRow(
                      '📊 Estado',
                      _respuesta!.estado,
                      color: _respuesta!.estado == 'completado' ? Colors.green : Colors.orange,
                    ),
                    _buildInfoRow(
                      '📋 Formulario',
                      _respuesta!.formularioTitulo ?? 'N/A',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Respuestas
            const Text(
              '📝 Respuestas del Formulario',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            if (_respuesta!.tieneDetalles)
              ..._respuesta!.detalles!.map((detalle) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList()
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      'No se encontraron respuestas detalladas',
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'El formulario puede no tener preguntas registradas',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade600),
                    ),
                  ],
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