import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  Map<String, dynamic>? _estadisticas;
  bool _cargando = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    setState(() {
      _cargando = true;
      _error = '';
    });

    try {
      // ✅ Obtener historial real desde el backend
      final historial = await AuthService.getHistorialRespuestas();
      
      print('🔍 Historial recibido: ${historial.length} registros');

      // Calcular estadísticas
      final total = historial.length;
      final completados = historial.where((r) => 
        r['estado']?.toString().toUpperCase() == 'COMPLETADO'
      ).length;
      final enProceso = historial.where((r) => 
        r['estado']?.toString().toUpperCase() == 'EN_PROCESO'
      ).length;
      final pdfs = historial.where((r) => 
        r['pdf_generado'] == true || r['pdf_generado'] == 1
      ).length;

      print('📊 Total: $total, Completados: $completados, Pendientes: $enProceso, PDFs: $pdfs');

      setState(() {
        _estadisticas = {
          'total': total,
          'completados': completados,
          'en_proceso': enProceso,
          'pdfs': pdfs,
        };
        _cargando = false;
      });
    } catch (e) {
      print('❌ Error cargando estadísticas: $e');
      setState(() {
        _error = 'Error al cargar estadísticas: $e';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Estadísticas'),
        backgroundColor: const Color(0xFF3498db),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarEstadisticas,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(_error, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _cargarEstadisticas,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Tarjetas de estadísticas
                      Row(
                        children: [
                          Expanded(
                            child: _tarjetaEstadistica(
                              '📝 Total',
                              _estadisticas?['total'] ?? 0,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _tarjetaEstadistica(
                              '✅ Completados',
                              _estadisticas?['completados'] ?? 0,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _tarjetaEstadistica(
                              '⏳ Pendientes',
                              _estadisticas?['en_proceso'] ?? 0,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _tarjetaEstadistica(
                              '📄 PDFs',
                              _estadisticas?['pdfs'] ?? 0,
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Gráfica de barras
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '📈 Distribución',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _barraVertical('Completados', _estadisticas?['completados'] ?? 0, Colors.green),
                                  _barraVertical('Pendientes', _estadisticas?['en_proceso'] ?? 0, Colors.orange),
                                  _barraVertical('PDFs', _estadisticas?['pdfs'] ?? 0, Colors.purple),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // ✅ Mensaje si no hay datos
                      if ((_estadisticas?['total'] ?? 0) == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Column(
                            children: [
                              Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'Aún no hay respuestas registradas',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Responde algunos formularios para ver estadísticas',
                                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  // ============================================================
  // TARJETA DE ESTADÍSTICA
  // ============================================================
  Widget _tarjetaEstadistica(String titulo, int valor, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              titulo,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              '$valor',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BARRA VERTICAL (GRÁFICA SIMPLE)
  // ============================================================
  Widget _barraVertical(String label, int valor, Color color) {
    final maxValor = [
      _estadisticas?['completados'] ?? 0,
      _estadisticas?['en_proceso'] ?? 0,
      _estadisticas?['pdfs'] ?? 0,
    ].reduce((a, b) => a > b ? a : b);

    final altura = maxValor > 0 ? (valor / maxValor) * 120 : 0;

    return Column(
      children: [
        Container(
          height: 120,
          width: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: altura.toDouble(),
              width: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$valor',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}