import 'package:flutter/material.dart';
import '../services.dart';
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
  bool _isSaving = false;

  // Datos de prueba para preguntas (esto debería venir del backend en S6)
  final List<Map<String, dynamic>> _preguntasPrueba = [
    {'id': 1, 'tipo': 'texto', 'label': 'Nombre completo', 'placeholder': 'Ej: Juan Pérez', 'required': true},
    {'id': 2, 'tipo': 'email', 'label': 'Correo electrónico', 'placeholder': 'juan@ejemplo.com', 'required': true},
    {'id': 3, 'tipo': 'numero', 'label': 'Edad', 'placeholder': '25', 'required': false, 'min': 18, 'max': 99},
    {'id': 4, 'tipo': 'seleccion_unica', 'label': 'Nivel de satisfacción', 'options': ['Muy bueno', 'Bueno', 'Regular', 'Malo'], 'required': true},
    {'id': 5, 'tipo': 'seleccion_multiple', 'label': 'Áreas de interés', 'options': ['Ventas', 'Marketing', 'Desarrollo', 'Soporte'], 'required': false},
    {'id': 6, 'tipo': 'fecha', 'label': 'Fecha de nacimiento', 'required': false},
    {'id': 7, 'tipo': 'fechahora', 'label': 'Fecha y hora de registro', 'required': true},
    {'id': 8, 'tipo': 'hora', 'label': 'Hora de atención', 'required': false},
    {'id': 9, 'tipo': 'booleano', 'label': '¿Acepta términos y condiciones?', 'required': true},
  ];

  Widget _buildField(Map<String, dynamic> pregunta) {
    int id = pregunta['id'];
    String tipo = pregunta['tipo'];
    String label = pregunta['label'];

    switch (tipo) {
      case 'texto':
      case 'email':
      case 'telefono':
        return DynamicTextField(
          label: label,
          placeholder: pregunta['placeholder'],
          required: pregunta['required'] ?? false,
          keyboardType: tipo == 'email' ? TextInputType.emailAddress : TextInputType.text,
          maxLength: pregunta['maxlength'],
          minLength: pregunta['minlength'],
          onChanged: (value) => _respuestas[id] = value,
        );

      case 'numero':
        return DynamicNumberField(
          label: label,
          placeholder: pregunta['placeholder'],
          required: pregunta['required'] ?? false,
          min: pregunta['min']?.toDouble(),
          max: pregunta['max']?.toDouble(),
        );

      case 'seleccion_unica':
        return DynamicDropdown(
          label: label,
          options: List<String>.from(pregunta['options']),
          required: pregunta['required'] ?? false,
          onChanged: (value) => _respuestas[id] = value,
        );

      case 'seleccion_multiple':
        return DynamicCheckboxGroup(
          label: label,
          options: List<String>.from(pregunta['options']),
          required: pregunta['required'] ?? false,
          onChanged: (values) => _respuestas[id] = values,
        );

      case 'fecha':
        return DynamicDatePicker(
          label: label,
          required: pregunta['required'] ?? false,
          includeTime: false,
          onChanged: (date) => _respuestas[id] = date.toIso8601String(),
        );

      case 'fechahora':
        return DynamicDatePicker(
          label: label,
          required: pregunta['required'] ?? false,
          includeTime: true,
          onChanged: (date) => _respuestas[id] = date.toIso8601String(),
        );

      case 'hora':
        // Simplificado - se puede mejorar
        return DynamicTextField(
          label: label,
          placeholder: 'HH:MM',
          required: pregunta['required'] ?? false,
          onChanged: (value) => _respuestas[id] = value,
        );

      case 'booleano':
        return DynamicSwitch(
          label: label,
          required: pregunta['required'] ?? false,
          onChanged: (value) => _respuestas[id] = value,
        );

      default:
        return DynamicTextField(
          label: label,
          required: pregunta['required'] ?? false,
          onChanged: (value) => _respuestas[id] = value,
        );
    }
  }

  Future<void> _guardarRespuestas() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // Formatear respuestas para el backend
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

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Respuestas guardadas exitosamente'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: ${result['message']}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.formulario['titulo']),
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
              // Descripción del formulario
              if (widget.formulario['descripcion'] != null)
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      widget.formulario['descripcion'],
                      style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // Campos dinámicos
              ..._preguntasPrueba.map((pregunta) => _buildField(pregunta)),

              const SizedBox(height: 30),

              // Botón guardar
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
                      : const Text('Guardar Respuestas', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}