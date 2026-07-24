import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/respuesta_model.dart';
import 'detalle_respuesta_screen.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  List<Respuesta> _respuestas = [];
  bool _isLoading = true;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    setState(() => _isLoading = true);
    final data = await AuthService.getHistorialRespuestas();
    setState(() {
      _respuestas = data.map((r) => Respuesta.fromJson(r)).toList();
      _isLoading = false;
    });
  }

  List<Respuesta> get _respuestasFiltradas {
    if (_filtro.isEmpty) return _respuestas;
    return _respuestas.where((r) {
      final search = _filtro.toLowerCase();
      return r.usuarioNombre?.toLowerCase().contains(search) == true ||
          r.usuarioEmail?.toLowerCase().contains(search) == true ||
          r.fechaFormateada.contains(search);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        backgroundColor: const Color(0xFF3498db),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarHistorial,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: '🔍 Buscar...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) => setState(() => _filtro = value),
            ),
          ),
          // Contenido
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _respuestasFiltradas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No hay respuestas registradas',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _respuestasFiltradas.length,
                        itemBuilder: (context, index) {
                          final respuesta = _respuestasFiltradas[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  respuesta.usuarioNombre?.substring(0, 1).toUpperCase() ?? '?',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                respuesta.usuarioNombre ?? 'Anónimo',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(respuesta.fechaFormateada),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Chip(
                                        label: Text(respuesta.estado),
                                        backgroundColor: respuesta.estado == 'completado'
                                            ? Colors.green.shade100
                                            : Colors.orange.shade100,
                                        labelStyle: TextStyle(
                                          fontSize: 10,
                                          color: respuesta.estado == 'completado'
                                              ? Colors.green.shade800
                                              : Colors.orange.shade800,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '⏱️ ${respuesta.tiempoFormateado}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DetalleRespuestaScreen(
                                      respuestaId: respuesta.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}