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
  List<Respuesta> _respuestasFiltradas = [];
  bool _isLoading = true;
  String _filtroEstado = 'todos';
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  // ============================================================
  // CARGAR HISTORIAL (VERSIÓN SIMPLIFICADA)
  // ============================================================
 Future<void> _cargarHistorial() async {
  setState(() => _isLoading = true);
  
  try {
    // 1. Obtener lista de respuestas
    final data = await AuthService.getHistorialRespuestas();
    print('🔍 Historial: ${data.length} registros');
    
    // 2. Para cada respuesta, obtener sus detalles
    final List<Respuesta> respuestasConDetalles = [];
    
    for (var item in data) {
      try {
        final respuestaId = item['id']?.toString() ?? '';
        print('🔍 Cargando detalles para: $respuestaId');
        
        // ✅ Obtener detalles completos
        final detallesData = await AuthService.getDetalleRespuesta(respuestaId);
        
        // ✅ Combinar encabezado + detalles
        final respuestaCompleta = {
          ...item,
          'detalles': detallesData['detalles'] ?? [],
          'formulario_titulo': detallesData['formulario_titulo'] ?? item['formulario_titulo'],
        };
        
        final respuesta = Respuesta.fromJson(respuestaCompleta);
        print('✅ Respuesta cargada con ${respuesta.totalDetalles} detalles');
        respuestasConDetalles.add(respuesta);
        
      } catch (e) {
        print('❌ Error con respuesta ${item['id']}: $e');
        // Si falla, agregar solo el encabezado
        respuestasConDetalles.add(Respuesta.fromJson(item));
      }
    }
    
    setState(() {
      _respuestas = respuestasConDetalles;
      _aplicarFiltros();
      _isLoading = false;
    });
    
  } catch (e) {
    print('❌ Error cargando historial: $e');
    setState(() {
      _respuestas = [];
      _respuestasFiltradas = [];
      _isLoading = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error cargando historial: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
  void _aplicarFiltros() {
    setState(() {
      _respuestasFiltradas = _respuestas.where((r) {
        final estadoMatch = _filtroEstado == 'todos' || r.estado == _filtroEstado;
        final busquedaMatch = _busqueda.isEmpty ||
            (r.usuarioNombre?.toLowerCase().contains(_busqueda.toLowerCase()) ?? false) ||
            (r.usuarioEmail?.toLowerCase().contains(_busqueda.toLowerCase()) ?? false);
        bool fechaMatch = true;
        if (_fechaInicio != null) {
          fechaMatch = fechaMatch && r.fechaCompletado.isAfter(_fechaInicio!);
        }
        if (_fechaFin != null) {
          fechaMatch = fechaMatch && r.fechaCompletado.isBefore(_fechaFin!);
        }
        return estadoMatch && busquedaMatch && fechaMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Historial'),
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
          // Filtros
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: '🔍 Buscar por usuario...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) {
                    _busqueda = value;
                    _aplicarFiltros();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filtroEstado,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'todos', child: Text('📊 Todos')),
                          DropdownMenuItem(value: 'completado', child: Text('✅ Completados')),
                          DropdownMenuItem(value: 'en_proceso', child: Text('⏳ En proceso')),
                        ],
                        onChanged: (value) {
                          _filtroEstado = value!;
                          _aplicarFiltros();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.calendar_today,
                        color: _fechaInicio != null || _fechaFin != null
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      onPressed: _seleccionarFechas,
                    ),
                    if (_fechaInicio != null || _fechaFin != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.red),
                        onPressed: () {
                          _fechaInicio = null;
                          _fechaFin = null;
                          _aplicarFiltros();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Lista
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
                              _respuestas.isEmpty
                                  ? 'No hay respuestas en el historial'
                                  : 'No hay respuestas con estos filtros',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _cargarHistorial,
                              child: const Text('Recargar'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargarHistorial,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _respuestasFiltradas.length,
                          itemBuilder: (context, index) {
                            final respuesta = _respuestasFiltradas[index];
                            return _buildCard(respuesta);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Respuesta respuesta) {
    final totalRespuestas = respuesta.totalDetalles;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: totalRespuestas > 0 ? Colors.green.shade50 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    totalRespuestas > 0 
                        ? '$totalRespuestas respuestas' 
                        : 'Sin respuestas',
                    style: TextStyle(
                      fontSize: 10,
                      color: totalRespuestas > 0 ? Colors.green : Colors.grey,
                    ),
                  ),
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
  }

  Future<void> _seleccionarFechas() async {
    final now = DateTime.now();
    final inicio = await showDatePicker(
      context: context,
      initialDate: _fechaInicio ?? now.subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: now,
      locale: const Locale('es', 'MX'),
    );

    if (inicio == null) return;

    final fin = await showDatePicker(
      context: context,
      initialDate: _fechaFin ?? now,
      firstDate: inicio,
      lastDate: now,
      locale: const Locale('es', 'MX'),
    );

    if (fin == null) return;

    setState(() {
      _fechaInicio = inicio;
      _fechaFin = fin;
      _aplicarFiltros();
    });
  }
}