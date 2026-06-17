import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import '../services/auth_service.dart';
import '../models/pregunta_model.dart';
import '../models/regla_model.dart';

class ResponderFormularioScreen extends StatefulWidget {
  final Map<String, dynamic> formulario;
  final String usuarioId;

  const ResponderFormularioScreen({
    super.key,
    required this.formulario,
    required this.usuarioId,
  });

  @override
  State<ResponderFormularioScreen> createState() => _ResponderFormularioScreenState();
}

class _ResponderFormularioScreenState extends State<ResponderFormularioScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<int, dynamic> _respuestas = {};
  final Map<int, File> _fotos = {};
  final Map<int, SignatureController> _firmaControllers = {};

  bool _isLoading = true;
  bool _isSaving = false;
  List<Pregunta> _preguntas = [];
  String? _formularioTitulo;
  Position? _ubicacionActual;
  String? _ubicacionError;
  List<ReglaCondicional> _reglas = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _obtenerUbicacion();
  }

  // ✅ CORREGIDO
  Future<void> _obtenerUbicacion() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _ubicacionError = '⚠️ Habilita el GPS');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _ubicacionError = '⚠️ Permiso denegado');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() => _ubicacionActual = position);
    } catch (e) {
      setState(() => _ubicacionError = '⚠️ Error: $e');
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

    final estructura = await AuthService.getEstructuraFormulario(
      widget.formulario['id'].toString(),
    );

    final reglasData = await AuthService.getReglasFormulario(
      widget.formulario['id'].toString(),
    );

    setState(() {
      _formularioTitulo = estructura['titulo'];
      final campos = estructura['campos'] ?? [];
      _preguntas = campos.map((c) => Pregunta.fromJson(c)).toList();
      _preguntas.sort((a, b) => a.orden.compareTo(b.orden));
      _reglas = reglasData.map((r) => ReglaCondicional.fromJson(r)).toList();

      for (var pregunta in _preguntas) {
        if (pregunta.tipoCampo.toUpperCase() == 'FIRMA') {
          _firmaControllers[pregunta.id] = SignatureController(
            penStrokeWidth: 2,
            penColor: Colors.black,
            exportBackgroundColor: Colors.white,
          );
        }
      }
      _isLoading = false;
    });
  }

  void _evaluarReglas(int preguntaId, dynamic valor) {
    final reglasAplicables = _reglas.where((r) => r.preguntaOrigenId == preguntaId).toList();

    setState(() {
      for (var regla in reglasAplicables) {
        final bool cumple = regla.evaluar(valor);
        final preguntaDestino = _preguntas.firstWhere(
          (p) => p.id == regla.preguntaDestinoId,
          orElse: () => throw Exception('Pregunta destino no encontrada'),
        );
        if (regla.accion == 'mostrar') {
          preguntaDestino.visible = cumple;
        } else if (regla.accion == 'ocultar') {
          preguntaDestino.visible = !cumple;
        }
      }
    });
  }

  Future<void> _tomarFoto(int preguntaId) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _fotos[preguntaId] = File(image.path);
        _respuestas[preguntaId] = image.path;
      });
      _evaluarReglas(preguntaId, image.path);
    }
  }

  Widget _buildCampo(Pregunta pregunta) {
    if (!pregunta.visible) return const SizedBox.shrink();

    final String tipo = pregunta.tipoCampo.toUpperCase();

    switch (tipo) {
      case 'TEXTO':
      case 'EMAIL':
      case 'TELEFONO':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            decoration: InputDecoration(
              labelText: pregunta.etiqueta,
              hintText: pregunta.placeholder,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
            ),
            keyboardType: tipo == 'EMAIL' ? TextInputType.emailAddress : TextInputType.text,
            onChanged: (value) {
              _respuestas[pregunta.id] = value;
              _evaluarReglas(pregunta.id, value);
            },
            validator: (value) {
              if (pregunta.obligatorio && (value == null || value.isEmpty)) {
                return 'Este campo es obligatorio';
              }
              return null;
            },
          ),
        );

      case 'NUMERO':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: pregunta.etiqueta,
              hintText: pregunta.placeholder,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
            ),
            onChanged: (value) {
              _respuestas[pregunta.id] = value;
              _evaluarReglas(pregunta.id, value);
            },
            validator: (value) {
              if (pregunta.obligatorio && (value == null || value.isEmpty)) {
                return 'Este campo es obligatorio';
              }
              return null;
            },
          ),
        );

      case 'SELECTOR':
      case 'SELECCION_UNICA':
        final opciones = pregunta.getOpciones();
        if (opciones.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: pregunta.etiqueta,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
            ),
            items: opciones.map((opt) {
              return DropdownMenuItem(value: opt, child: Text(opt));
            }).toList(),
            onChanged: (value) {
              _respuestas[pregunta.id] = value;
              _evaluarReglas(pregunta.id, value);
            },
            validator: (value) {
              if (pregunta.obligatorio && (value == null || value.isEmpty)) {
                return 'Seleccione una opción';
              }
              return null;
            },
          ),
        );

      case 'FOTO':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pregunta.etiqueta, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    if (_fotos.containsKey(pregunta.id))
                      Image.file(_fotos[pregunta.id]!, height: 150, fit: BoxFit.cover),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _tomarFoto(pregunta.id),
                      icon: const Icon(Icons.camera_alt),
                      label: Text(_fotos.containsKey(pregunta.id) ? 'Re-tomar foto' : 'Tomar foto'),
                    ),
                  ],
                ),
              ),
              if (pregunta.obligatorio && !_fotos.containsKey(pregunta.id))
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Requerido', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
        );

      case 'FIRMA':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pregunta.etiqueta, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Signature(
                  controller: _firmaControllers[pregunta.id]!,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _firmaControllers[pregunta.id]!.clear(),
                    icon: const Icon(Icons.clear),
                    label: const Text('Limpiar'),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () async {
                      final data = await _firmaControllers[pregunta.id]!.toPngBytes();
                      if (data != null) {
                        final base64 = 'data:image/png;base64,${Uri.encodeComponent(String.fromCharCodes(data))}';
                        _respuestas[pregunta.id] = base64;
                        _evaluarReglas(pregunta.id, base64);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Firma capturada')),
                        );
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar firma'),
                  ),
                ],
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _guardarRespuestas() async {
    if (!_formKey.currentState!.validate()) return;

    for (var pregunta in _preguntas) {
      if (!pregunta.visible) continue;
      if (pregunta.obligatorio) {
        final valor = _respuestas[pregunta.id];
        if (valor == null || valor.toString().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ ${pregunta.etiqueta} es obligatorio'), backgroundColor: Colors.orange),
          );
          return;
        }
      }
    }

    if (_ubicacionActual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Esperando ubicación GPS...'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    final respuestasFormateadas = _respuestas.entries.map((entry) {
      return {
        'campoId': entry.key.toString(),
        'valor': entry.value.toString(),
      };
    }).toList();

    final success = await AuthService.guardarRespuestasFormulario(
      formularioId: widget.formulario['id'].toString(),
      usuarioId: widget.usuarioId,
      latitud: _ubicacionActual!.latitude,
      longitud: _ubicacionActual!.longitude,
      respuestas: respuestasFormateadas,
    );

    setState(() => _isSaving = false);

    if (mounted && success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('¡Éxito!'),
            ],
          ),
          content: const Text('El formulario se ha guardado correctamente.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Error al guardar'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_formularioTitulo ?? widget.formulario['titulo']),
        backgroundColor: const Color(0xFF3498db),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _ubicacionActual != null ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _ubicacionActual != null ? Colors.green.shade200 : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _ubicacionActual != null ? Icons.location_on : Icons.location_searching,
                      color: _ubicacionActual != null ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _ubicacionActual != null
                            ? '📍 ${_ubicacionActual!.latitude.toStringAsFixed(6)}, ${_ubicacionActual!.longitude.toStringAsFixed(6)}'
                            : (_ubicacionError ?? '🔄 Obteniendo ubicación...'),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ..._preguntas.map((pregunta) => _buildCampo(pregunta)),
              const SizedBox(height: 30),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _guardarRespuestas,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3498db),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          '📤 Enviar Formulario',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              if (_reglas.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🔧 ${_reglas.length} reglas condicionales activas',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _firmaControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}