import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
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
  final Map<int, File> _firmas = {};
  final Map<int, SignatureController> _firmaControllers = {};

  bool _isLoading = true;
  bool _isSaving = false;
  List<Pregunta> _preguntas = [];
  String? _formularioTitulo;
  Position? _ubicacionActual;
  String? _ubicacionError;
  List<ReglaCondicional> _reglas = [];
  List<Map<String, dynamic>> _archivosSubidos = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _obtenerUbicacion();
  }

  // ============================================================
  // OBTENER UBICACIÓN GPS
  // ============================================================
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

  // ============================================================
  // CARGAR DATOS DEL FORMULARIO
  // ============================================================
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

  // ============================================================
  // EVALUAR REGLAS CONDICIONALES
  // ============================================================
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

  // ============================================================
  // SEMANA 8: TOMAR FOTO
  // ============================================================
  Future<void> _tomarFoto(int preguntaId) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        final file = File(image.path);
        setState(() {
          _fotos[preguntaId] = file;
          _respuestas[preguntaId] = image.path;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📸 Foto capturada correctamente'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al tomar foto: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ============================================================
  // SEMANA 8: CAPTURAR FIRMA
  // ============================================================
  Future<void> _guardarFirma(int preguntaId) async {
    try {
      final controller = _firmaControllers[preguntaId];
      if (controller == null) return;
      
      final data = await controller.toPngBytes();
      if (data != null) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/firma_$preguntaId.png';
        final file = File(filePath);
        await file.writeAsBytes(data);
        
        setState(() {
          _firmas[preguntaId] = file;
          _respuestas[preguntaId] = filePath;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Firma guardada correctamente'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al guardar firma: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ============================================================
  // SEMANA 8: SUBIR ARCHIVO AL SERVIDOR
  // ============================================================
  Future<Map<String, dynamic>> _subirArchivo({
    required File archivo,
    required String tipo,
    required int preguntaId,
  }) async {
    try {
      final bytes = await archivo.readAsBytes();
      final base64String = base64Encode(bytes);
      final extension = archivo.path.split('.').last;
      final nombreOriginal = '${tipo}_$preguntaId.$extension';
      
      final mutation = '''
        mutation SubirArchivo(\$archivo: ArchivoInput!) {
          subirArchivo(archivo: \$archivo) {
            success
            url
            mensaje
          }
        }
      ''';

      final archivoInput = {
        'nombreOriginal': nombreOriginal,
        'mimeType': 'image/png',
        'base64': base64String,
        'tipo': tipo,
        'preguntaId': preguntaId,
        'formularioId': int.parse(widget.formulario['id']),
      };

      final prefs = await AuthService.getUser();
      final token = prefs?['token'];

      final response = await http.post(
        Uri.parse(AuthService.apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'query': mutation,
          'variables': {'archivo': archivoInput},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['subirArchivo'] != null) {
          return data['data']['subirArchivo'];
        }
      }
      return {'success': false, 'mensaje': 'Error al subir archivo'};
    } catch (e) {
      return {'success': false, 'mensaje': 'Error: $e'};
    }
  }

  // ============================================================
  // CONSTRUIR CAMPO SEGÚN TIPO
  // ============================================================
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

      // ============================================================
      // SEMANA 8: CAMPO FOTO ACTUALIZADO
      // ============================================================
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _fotos[pregunta.id]!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image, size: 40, color: Colors.grey),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _tomarFoto(pregunta.id),
                          icon: const Icon(Icons.camera_alt),
                          label: Text(_fotos.containsKey(pregunta.id) ? 'Re-tomar' : 'Tomar foto'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3498db),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        if (_fotos.containsKey(pregunta.id))
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _fotos.remove(pregunta.id);
                                _respuestas.remove(pregunta.id);
                              });
                            },
                          ),
                      ],
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

      // ============================================================
      // SEMANA 8: CAMPO FIRMA ACTUALIZADO
      // ============================================================
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
                    onPressed: () => _guardarFirma(pregunta.id),
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar'),
                  ),
                  if (_firmas.containsKey(pregunta.id))
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                ],
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // ============================================================
  // SEMANA 8: GUARDAR RESPUESTAS CON ARCHIVOS
  // ============================================================
  Future<void> _guardarRespuestas() async {
    if (!_formKey.currentState!.validate()) return;

    // Validar campos obligatorios
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

    try {
      // 1. Subir fotos
      List<Map<String, dynamic>> archivosSubidos = [];
      for (var entry in _fotos.entries) {
        final resultado = await _subirArchivo(
          archivo: entry.value,
          tipo: 'foto',
          preguntaId: entry.key,
        );
        if (resultado['success'] == true) {
          archivosSubidos.add({
            'preguntaId': entry.key,
            'url': resultado['url'],
            'tipo': 'foto',
          });
        }
      }

      // 2. Subir firmas
      for (var entry in _firmas.entries) {
        final resultado = await _subirArchivo(
          archivo: entry.value,
          tipo: 'firma',
          preguntaId: entry.key,
        );
        if (resultado['success'] == true) {
          archivosSubidos.add({
            'preguntaId': entry.key,
            'url': resultado['url'],
            'tipo': 'firma',
          });
        }
      }

      // 3. Formatear respuestas
      final respuestasFormateadas = _respuestas.entries.map((entry) {
        return {
          'campoId': entry.key.toString(),
          'valor': entry.value.toString(),
        };
      }).toList();

      // 4. Guardar todo
      final success = await AuthService.guardarRespuestasConEvidencias(
        formularioId: widget.formulario['id'].toString(),
        usuarioId: widget.usuarioId,
        latitud: _ubicacionActual!.latitude,
        longitud: _ubicacionActual!.longitude,
        respuestas: respuestasFormateadas,
        archivos: archivosSubidos,
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('El formulario se ha guardado correctamente.'),
                if (archivosSubidos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('📸 ${archivosSubidos.length} archivo(s) subido(s)'),
                  ),
              ],
            ),
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
          const SnackBar(content: Text('❌ Error al guardar el formulario'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
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
              // GPS
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