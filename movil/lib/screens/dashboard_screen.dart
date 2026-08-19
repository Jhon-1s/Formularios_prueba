import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'formularios_screen.dart';
import 'historial_screen.dart';
import 'estadisticas_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
  }

  Future<void> _cargarUsuario() async {
    try {
      final user = await AuthService.getUser();
      setState(() {
        _userData = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.clearSession();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  final List<Widget> _screens = [
    const HomeContent(),
    const FormulariosScreen(),
    const HistorialScreen(),
    const EstadisticasScreen(),
  ];

  final List<String> _titles = [
    'Inicio',
    'Formularios',
    'Historial',
    'Estadísticas'
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: const Color(0xFF3498db),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF3498db),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Formularios'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Estadísticas'),
        ],
      ),
    );
  }
}

// ============================================================
// HOME CONTENT - VERSIÓN SIMPLIFICADA Y CORREGIDA
// ============================================================
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  Map<String, dynamic>? _estadisticas;
  bool _cargando = true;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    _user = await AuthService.getUser();
    await _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    setState(() => _cargando = true);
    try {
      final historial = await AuthService.getHistorialRespuestas();
      
      final completados = historial.where((r) => 
        r['estado']?.toString().toUpperCase() == 'COMPLETADO'
      ).length;
      final enProceso = historial.where((r) => 
        r['estado']?.toString().toUpperCase() == 'EN_PROCESO'
      ).length;

      setState(() {
        _estadisticas = {
          'formularios': historial.length,
          'completados': completados,
          'pendientes': enProceso,
          'sincronizados': historial.length,
        };
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _estadisticas = {
          'formularios': 0,
          'completados': 0,
          'pendientes': 0,
          'sincronizados': 0,
        };
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Perfil del usuario
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF3498db),
                    child: Text(
                      user != null && user['nombre'] != null && user['nombre'].toString().isNotEmpty
                          ? user['nombre'].toString().substring(0, 1).toUpperCase()
                          : 'U',
                      style: const TextStyle(fontSize: 40, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?['nombre'] ?? 'Usuario',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?['email'] ?? 'correo@ejemplo.com',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(user?['rol'] ?? 'usuario'),
                    backgroundColor: const Color(0xFF3498db).withOpacity(0.2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '📊 Estadísticas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_cargando)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    Icons.assignment,
                    'Formularios',
                    _estadisticas?['formularios']?.toString() ?? '0',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    Icons.check_circle,
                    'Completados',
                    _estadisticas?['completados']?.toString() ?? '0',
                    Colors.green,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          if (!_cargando)
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    Icons.pending,
                    'Pendientes',
                    _estadisticas?['pendientes']?.toString() ?? '0',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    Icons.cloud_sync,
                    'Sincronizados',
                    _estadisticas?['sincronizados']?.toString() ?? '0',
                    Colors.purple,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String title, String value, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}