import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  List<Map<String, dynamic>> _historial = [];
  Map<String, int> _estadisticas = {};
  bool _isLoading = true;
  bool _isInvitado = false;
  bool _isLocalUser = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      _isInvitado = await AuthService.esInvitado();
      _isLocalUser = await AuthService.esUsuarioLocal();
      
      final historial = await AuthService.getHistorialRespuestas();
      final estadisticas = await AuthService.getEstadisticas();
      
      setState(() {
        _historial = historial;
        _estadisticas = estadisticas;
        _isLoading = false;
      });
      
      print('📊 Historial: ${_historial.length} registros');
      print('📊 Estadísticas: $_estadisticas');
    } catch (e) {
      print('❌ Error cargando estadísticas: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Tarjeta de resumen
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.bar_chart,
                                  color: Color(0xFF3498db),
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Resumen General',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                if (_isInvitado)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      '👤 Invitado',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (_isLocalUser)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.purple,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      '📱 Local',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // ✅ Grid de estadísticas
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.2,
                              children: [
                                _buildStatCard(
                                  icon: Icons.assignment,
                                  title: 'Formularios',
                                  value: (_estadisticas['total_formularios'] ?? 0).toString(),
                                  color: Colors.blue,
                                ),
                                _buildStatCard(
                                  icon: Icons.check_circle,
                                  title: 'Completados',
                                  value: (_estadisticas['completados'] ?? 0).toString(),
                                  color: Colors.green,
                                ),
                                _buildStatCard(
                                  icon: Icons.pending,
                                  title: 'En Proceso',
                                  value: (_estadisticas['en_proceso'] ?? 0).toString(),
                                  color: Colors.orange,
                                ),
                                _buildStatCard(
                                  icon: Icons.cloud_off,
                                  title: 'Pendientes',
                                  value: (_estadisticas['pendientes'] ?? 0).toString(),
                                  color: Colors.red,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ✅ Últimas respuestas
                    Row(
                      children: [
                        const Text(
                          '📋 Últimas Respuestas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_historial.isNotEmpty)
                          Text(
                            '${_historial.length} total',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_historial.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.history,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay respuestas guardadas',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Completa un formulario para verlo aquí',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _cargarDatos,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Recargar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3498db),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _historial.length > 10 ? 10 : _historial.length,
                        itemBuilder: (context, index) {
                          final item = _historial[index];
                          final esCompletado = item['estado']?.toString().toUpperCase() == 'COMPLETADO';
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: esCompletado ? Colors.green : Colors.orange,
                                child: Icon(
                                  esCompletado ? Icons.check : Icons.pending,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                item['formulario_titulo'] ?? 'Formulario',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '👤 ${item['usuario_nombre_completo'] ?? 'Usuario'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    _formatDate(item['fecha_completado']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: item['pdf_generado'] == true
                                  ? const Icon(
                                      Icons.picture_as_pdf,
                                      color: Colors.red,
                                    )
                                  : null,
                              onTap: () {
                                _verDetalle(context, item['id']);
                              },
                            ),
                          );
                        },
                      ),

                    if (_historial.length > 10)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: Text(
                            'Mostrando 10 de ${_historial.length} respuestas',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Fecha no disponible';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  void _verDetalle(BuildContext context, String? id) {
    if (id == null) return;
    // Navegar a detalle
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalleRespuestaScreen(respuestaId: id),
      ),
    );
  }
}

// ✅ Pantalla de detalle de respuesta
class DetalleRespuestaScreen extends StatefulWidget {
  final String respuestaId;

  const DetalleRespuestaScreen({super.key, required this.respuestaId});

  @override
  State<DetalleRespuestaScreen> createState() => _DetalleRespuestaScreenState();
}

class _DetalleRespuestaScreenState extends State<DetalleRespuestaScreen> {
  Map<String, dynamic> _data = {};
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
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Respuesta'),
        backgroundColor: const Color(0xFF3498db),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
              ? const Center(child: Text('No se encontraron detalles'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _data['formulario_titulo'] ?? 'Formulario',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow('Usuario', _data['usuario_nombre_completo']),
                              _buildInfoRow('Email', _data['usuario_email']),
                              _buildInfoRow('Estado', _data['estado']),
                              _buildInfoRow('Fecha', _data['fecha_completado']),
                              if (_data['ubicacion_lat'] != null)
                                _buildInfoRow(
                                  'Ubicación',
                                  '${_data['ubicacion_lat']}, ${_data['ubicacion_lng']}',
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '📋 Respuestas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_data['respuestas'] != null)
                        ...(_data['respuestas'] as List).map((detalle) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                detalle['campoId'] ?? 'Pregunta',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                detalle['valor']?.toString() ?? 'No disponible',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value ?? 'No disponible'),
          ),
        ],
      ),
    );
  }
}