import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'responder_formulario_screen.dart';

class FormulariosScreen extends StatefulWidget {
  const FormulariosScreen({super.key});

  @override
  State<FormulariosScreen> createState() => _FormulariosScreenState();
}

class _FormulariosScreenState extends State<FormulariosScreen> {
  List<dynamic> _formularios = [];
  bool _isLoading = true;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _cargarFormularios();
  }

  Future<void> _cargarFormularios() async {
    setState(() => _isLoading = true);
    final formulariosAPI = await AuthService.getFormulariosDisponibles();
    if (formulariosAPI.isNotEmpty) {
      await AuthService.saveFormulariosLocal(formulariosAPI);
      setState(() {
        _formularios = formulariosAPI;
        _isOnline = true;
      });
    } else {
      final formulariosLocal = await AuthService.getFormulariosLocal();
      setState(() {
        _formularios = formulariosLocal;
        _isOnline = false;
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _refreshFormularios() async {
    await _cargarFormularios();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_formularios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _isOnline ? 'No hay formularios disponibles' : 'Sin conexión',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refreshFormularios,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshFormularios,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _formularios.length,
        itemBuilder: (context, index) {
          final formulario = _formularios[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () async {
                final user = await AuthService.getUser();
                final usuarioId = user?['id']?.toString() ?? '2';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResponderFormularioScreen(
                      formulario: {
                        'id': formulario['id'],
                        'titulo': formulario['titulo'],
                        'descripcion': formulario['descripcion'],
                      },
                      usuarioId: usuarioId,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3498db).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.assignment, color: Color(0xFF3498db), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formulario['titulo'] ?? 'Sin título',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (formulario['descripcion'] != null && formulario['descripcion'].isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                formulario['descripcion'],
                                style: const TextStyle(fontSize: 14, color: Colors.grey),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Chip(
                            label: Text(formulario['estado'] ?? 'borrador'),
                            backgroundColor: Colors.green.withOpacity(0.2),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}