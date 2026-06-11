import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_service.dart';
import '../services/formulario_service.dart';
import '../models/pregunta_model.dart';
import '../widgets/form_fields.dart';

class ResponderFormularioScreen extends StatefulWidget {
  final Map<String, dynamic> formulario;

  const ResponderFormularioScreen({super.key, required this.formulario});

  @override
  State<ResponderFormularioScreen> createState() => _ResponderFormularioScreenState();
}

class _ResponderFormularioScreenState extends State<ResponderFormularioScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<int, dynamic> _respuestas = {};
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _estructura;
  Position? _ubicacionActual;
  String? _direccionActual;

  @override
  void initState() {
    super.initState();
    _cargarEstructura();
    _obtenerUbicacion();
  }

  // Obtener ubicación GPS
  Future<void> _obtenerUbicacion() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Habilita el GPS para continuar')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _ubicacionActual = position;
      _direccionActual = 'Lat: ${position.latitude}, Lng: ${position.longitude}';
    });
  }

  // Cargar estructura del formulario desde backend
  Future<void> _cargarEstructura() async {
    setState(() => _isLoading = true);
    
    final estructura = await AuthService.getEstructuraFormulario(widget.formulario['id']);
    
    setState(() {
      _estructura = estructura;
      _isLoading = false;
    });
  }

  // Construir campo según tipo
  Widget _buildField(Pregunta pregunta) {
    if (!pregunta.visible) return const SizedBox.shrink();

    switch (pregunta.tipoCampo) {
      case 'texto':
      case 'email':
      case 'telefono':
        return DynamicTextField(
          label: pregunta.etiqueta,
          placeholder: pregunta.placeholder,
          required: pregunta.obligatorio,
          keyboardType: pregunta.tipoCampo == 'email' 
              ? TextInputType.emailAddress 
              : TextInputType.text,
          maxLength: pregunta.maxLength,
          minLength: pregunta.minLength,
          onChanged: (value) => _respuestas[pregunta.id] = value,
        );

      case 'numero':
        return DynamicNumberField(
          label: pregunta.etiqueta,
          placeholder: pregunta.placeholder,
          required: pregunta.obligatorio,
          onChanged: (value) => _respuestas[pregunta.id] = value,
        );

      case 'seleccion_unica':
        return DynamicDropdown(
          label: pregunta.etiqueta,
          options: pregunta.getOpciones(),
          required: pregunta.obligatorio,
          onChanged: (value) => _respuestas[pregunta.id] = value,
        );

      case 'seleccion_multiple':
        return DynamicCheckboxGroup(
          label: pregunta.etiqueta,
          options: pregunta.getOpciones(),
          required: pregunta.obligatorio,
          onChanged: (values) => _respuestas[pregunta.id] = values,
        );

      case 'fecha':
        return DynamicDatePicker(
          label: pregunta.etiqueta,
          required: pregunta.obligatorio,
          includeTime: false,
          onChanged: (date) => _respuestas[pregunta.id] = date.toIso8601String(),
        );

      case 'fechahora':
        return DynamicDatePicker(
          label: pregunta.etiqueta,
          required: pregunta.obligatorio,
          includeTime: true,
          onChanged: (date) => _respuestas[pregunta.id] = date.toIso8601String(),
        );

      case 'booleano':
        return DynamicSwitch(
          label: pregunta.etiqueta,
          required: pregunta.obligatorio,
          onChanged: (value) => _respuestas[pregunta.id] = value,
        );

      default:
        return DynamicTextField(
          label: pregunta.etiqueta,
          placeholder: pregunta.placeholder,
          required: pregunta.obligatorio,
          onChanged: (value) => _respuestas[pregunta.id] = value,
        );
    }
  }

  // Guardar respuestas
  Future<void> _guardarRespuestas() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final respuestasFormateadas = _respuestas.entries.map((entry) {
      return {
        'pregunta_id': entry.key,
        'valor_texto': entry.value is String ? entry.value : null,
        'valor_numero': entry.value is num ? entry.value : null,
        'valor_booleano': entry.value is bool ? entry.value : null,
      };
    }).toList();

    final user = await AuthService.getUser();
    final result = await AuthService.guardarRespuesta(
      formularioId: widget.formulario['id'],
      usuarioEmail: user?['email'] ?? 'anonimo@demo.com',
      usuarioNombre: user?['nombre'] ?? 'Usuario Anónimo',
      respuestas: respuestasFormateadas,
    );

    setState(() => _isSaving = false);

    if (mounted && result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Respuestas guardadas'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_estructura == null || _estructura!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.formulario['titulo'])),
        body: const Center(child: Text('Error al cargar el formulario')),
      );
    }

    final secciones = _estructura!['secciones'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_estructura!['titulo'] ?? widget.formulario['titulo']),
        backgroundColor: const Color(0xFF3498db),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // GPS info
              if (_ubicacionActual != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.green.shade700),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_direccionActual ?? 'Ubicación obtenida')),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Secciones y preguntas dinámicas
              ...secciones.expand((seccion) {
                final preguntas = (seccion['preguntas'] as List)
                    .map((p) => Pregunta.fromJson(p))
                    .toList();
                
                return [
                  if (seccion['titulo'] != null && seccion['titulo'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        seccion['titulo'],
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ...preguntas.map((p) => _buildField(p)),
                ];
              }),

              const SizedBox(height: 30),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _guardarRespuestas,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3498db),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Guardar Respuestas', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}