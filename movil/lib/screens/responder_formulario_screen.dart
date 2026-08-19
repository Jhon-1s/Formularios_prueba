import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
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
  final Map<String, dynamic> _respuestas = {};
  final Map<String, File> _fotos = {};
  final Map<String, File> _firmas = {};
  final Map<String, SignatureController> _firmaControllers = {};
  final Map<String, List<String>> _checkboxSeleccionados = {};
  final Map<String, bool> _firmaGuardada = {};

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isWeb = false;
  List<Pregunta> _preguntas = [];
  String? _formularioTitulo;
  Position? _ubicacionActual;
  String? _ubicacionError;
  List<ReglaCondicional> _reglas = [];

  @override
  void initState() {
    super.initState();
    _isWeb = identical(0, 0.0);
    _cargarDatos();
    _obtenerUbicacion();
  }

  // ============================================================
  // OBTENER UBICACIÓN CON SIMULACIÓN PARA WEB
  // ============================================================
  Future<void> _obtenerUbicacion() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _ubicacionError = '⚠️ Habilita el GPS');
        if (_isWeb) {
          _simularUbicacion();
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _ubicacionError = '⚠️ Permiso denegado');
          if (_isWeb) {
            _simularUbicacion();
          }
          return;
        }
      }
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _ubicacionActual = position;
        _respuestas['ubicacion'] = '${position.latitude}, ${position.longitude}';
      });
    } catch (e) {
      setState(() => _ubicacionError = '⚠️ Error: $e');
      if (_isWeb) {
        _simularUbicacion();
      }
    }
  }

  void _simularUbicacion() {
    final lat = 20.268991;
    final lng = -97.963696;
    setState(() {
      _ubicacionActual = Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 10.0,
        headingAccuracy: 10.0,
      );
      _ubicacionError = '📍 Ubicación simulada (Web)';
      _respuestas['ubicacion'] = '$lat, $lng';
    });
  }

  // ============================================================
  // CARGAR DATOS CON REGLAS CONDICIONALES
  // ============================================================
  Future<void> _cargarDatos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      print('🔍 Cargando formulario ID: ${widget.formulario['id']}');
      
      // 1. Obtener estructura del formulario
      final estructura = await AuthService.getEstructuraFormulario(
        widget.formulario['id'].toString(),
      );

      print('🔍 Estructura recibida: ${estructura.keys}');
      print('🔍 Campos: ${estructura['campos']?.length ?? 0}');

      // 2. Obtener reglas condicionales
      final reglasData = await AuthService.getReglasFormulario(
        widget.formulario['id'].toString(),
      );
      print('🔍 Reglas recibidas: ${reglasData.length}');

      if (!mounted) return;

      setState(() {
        _formularioTitulo = estructura['titulo'] ?? widget.formulario['titulo'];
        
        // Convertir campos a Pregunta
        final campos = estructura['campos'] ?? [];
        final List<Pregunta> preguntasList = [];
        for (var campo in campos) {
          try {
            final pregunta = Pregunta.fromJson(campo as Map<String, dynamic>);
            preguntasList.add(pregunta);
            
            // Inicializar checkbox seleccionados
            if (pregunta.tipoCampo.toUpperCase() == 'CHECKBOX') {
              _checkboxSeleccionados[pregunta.id] = [];
            }
          } catch (e) {
            print('❌ Error convirtiendo campo: $e');
          }
        }
        _preguntas = preguntasList;
        _preguntas.sort((a, b) => a.orden.compareTo(b.orden));
        
        // ✅ Convertir reglas
        _reglas = reglasData.map((r) => ReglaCondicional.fromJson(r)).toList();
        print('✅ Reglas cargadas: ${_reglas.length}');
        _reglas.forEach((r) => print('  - ${r.preguntaOrigenId} -> ${r.preguntaDestinoId} (${r.condicionOperador})'));
        
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
    } catch (e) {
      print('❌ Error cargando datos: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _preguntas = [];
        _reglas = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al cargar formulario: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ============================================================
  // EVALUAR REGLAS CONDICIONALES
  // ============================================================
  void _evaluarReglas(String preguntaId, dynamic valor) {
    // Buscar reglas donde esta pregunta es la origen
    final reglasAplicables = _reglas.where((r) => 
      r.preguntaOrigenId == preguntaId && r.activo
    ).toList();

    if (reglasAplicables.isEmpty) return;

    print('🔍 Evaluando ${reglasAplicables.length} reglas para pregunta: $preguntaId');

    setState(() {
      for (var regla in reglasAplicables) {
        final bool cumple = regla.evaluar(valor);
        print('🔍 Regla: ${regla.preguntaOrigenId} -> ${regla.preguntaDestinoId}, cumple: $cumple');
        
        // Buscar la pregunta destino
        final preguntaDestino = _preguntas.firstWhere(
          (p) => p.id == regla.preguntaDestinoId,
          orElse: () {
            print('⚠️ Pregunta destino no encontrada: ${regla.preguntaDestinoId}');
            return null as Pregunta;
          },
        );
        
        if (preguntaDestino != null) {
          if (regla.accion == 'mostrar') {
            preguntaDestino.visible = cumple;
          } else if (regla.accion == 'ocultar') {
            preguntaDestino.visible = !cumple;
          }
          print('🔍 Pregunta "${preguntaDestino.etiqueta}" visible: ${preguntaDestino.visible}');
        }
      }
    });
  }

  Future<void> _tomarFoto(String preguntaId) async {
    try {
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        final result = await Permission.camera.request();
        if (!result.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Permiso de cámara denegado'), backgroundColor: Colors.orange),
          );
          return;
        }
      }
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
        _evaluarReglas(preguntaId, image.path);
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

  Future<void> _guardarFirma(String preguntaId) async {
    try {
      final controller = _firmaControllers[preguntaId];
      if (controller == null) return;
      
      if (controller.points.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✍️ Por favor, firma en el recuadro'), backgroundColor: Colors.orange),
        );
        return;
      }
      
      final data = await controller.toPngBytes();
      if (data != null) {
        final String base64Firma = base64Encode(data);
        
        setState(() {
          _respuestas[preguntaId] = 'data:image/png;base64,$base64Firma';
          _firmaGuardada[preguntaId] = true;
        });
        _evaluarReglas(preguntaId, base64Firma);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Firma guardada correctamente'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print('❌ Error al guardar firma: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al guardar firma: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<Map<String, dynamic>> _subirArchivo({
    required File archivo,
    required String tipo,
    required String preguntaId,
  }) async {
    try {
      print('📤 Subiendo archivo: $tipo, pregunta: $preguntaId');
      
      final bytes = await archivo.readAsBytes();
      final base64String = base64Encode(bytes);
      final extension = archivo.path.split('.').last;
      final nombreOriginal = '${tipo}_$preguntaId.$extension';
      
      // En Web, no podemos subir archivos directamente
      if (_isWeb) {
        print('🌐 Web mode: Guardando archivo en memoria (no se sube al servidor)');
        setState(() {
          _respuestas['${tipo}_${preguntaId}_base64'] = base64String;
        });
        return {
          'success': true,
          'url': 'data:image/png;base64,$base64String',
          'mensaje': 'Archivo procesado en Web'
        };
      }
      
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

      print('🔑 Token: ${token != null ? "SÍ" : "NO"}');

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

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['subirArchivo'] != null) {
          return data['data']['subirArchivo'];
        }
      }
      return {'success': false, 'mensaje': 'Error al subir archivo'};
    } catch (e) {
      print('❌ Error en _subirArchivo: $e');
      return {'success': false, 'mensaje': 'Error: $e'};
    }
  }

  // ============================================================
  // CONSTRUIR CAMPO CON LÓGICA CONDICIONAL
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

      case 'NUMERICO':
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

      case 'SELECCION':
        final opciones = pregunta.getOpciones();
        if (opciones.isEmpty) {
          final opcionesDefault = ['Opción 1', 'Opción 2', 'Opción 3'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: pregunta.etiqueta,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
              ),
              items: opcionesDefault.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
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
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: pregunta.etiqueta,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
            ),
            items: opciones.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
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

      case 'CHECKBOX':
        final opciones = pregunta.getOpciones();
        if (opciones.isEmpty) {
          final opcionesDefault = ['Opción A', 'Opción B', 'Opción C'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pregunta.etiqueta, style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                ...opcionesDefault.map((opt) {
                  return CheckboxListTile(
                    title: Text(opt),
                    value: _checkboxSeleccionados[pregunta.id]?.contains(opt) ?? false,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _checkboxSeleccionados[pregunta.id]?.add(opt);
                        } else {
                          _checkboxSeleccionados[pregunta.id]?.remove(opt);
                        }
                        _respuestas[pregunta.id] = _checkboxSeleccionados[pregunta.id]?.join(', ') ?? '';
                        _evaluarReglas(pregunta.id, _respuestas[pregunta.id]);
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  );
                }).toList(),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pregunta.etiqueta, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              ...opciones.map((opt) {
                return CheckboxListTile(
                  title: Text(opt),
                  value: _checkboxSeleccionados[pregunta.id]?.contains(opt) ?? false,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _checkboxSeleccionados[pregunta.id]?.add(opt);
                      } else {
                        _checkboxSeleccionados[pregunta.id]?.remove(opt);
                      }
                      _respuestas[pregunta.id] = _checkboxSeleccionados[pregunta.id]?.join(', ') ?? '';
                      _evaluarReglas(pregunta.id, _respuestas[pregunta.id]);
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                );
              }).toList(),
            ],
          ),
        );

      case 'FECHA':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            decoration: InputDecoration(
              labelText: pregunta.etiqueta,
              hintText: 'DD/MM/YYYY',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null) {
                final formatted = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                setState(() {
                  _respuestas[pregunta.id] = formatted;
                  _evaluarReglas(pregunta.id, formatted);
                });
              }
            },
            controller: TextEditingController(text: _respuestas[pregunta.id] ?? ''),
            validator: (value) {
              if (pregunta.obligatorio && (value == null || value.isEmpty)) {
                return 'Este campo es obligatorio';
              }
              return null;
            },
          ),
        );

      case 'HORA':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            decoration: InputDecoration(
              labelText: pregunta.etiqueta,
              hintText: 'HH:MM',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              suffixIcon: const Icon(Icons.access_time),
            ),
            readOnly: true,
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (time != null) {
                final formatted = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                setState(() {
                  _respuestas[pregunta.id] = formatted;
                  _evaluarReglas(pregunta.id, formatted);
                });
              }
            },
            controller: TextEditingController(text: _respuestas[pregunta.id] ?? ''),
            validator: (value) {
              if (pregunta.obligatorio && (value == null || value.isEmpty)) {
                return 'Este campo es obligatorio';
              }
              return null;
            },
          ),
        );

      case 'FECHA_HORA':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            decoration: InputDecoration(
              labelText: pregunta.etiqueta,
              hintText: 'DD/MM/YYYY HH:MM',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null) {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  final formatted = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                  setState(() {
                    _respuestas[pregunta.id] = formatted;
                    _evaluarReglas(pregunta.id, formatted);
                  });
                }
              }
            },
            controller: TextEditingController(text: _respuestas[pregunta.id] ?? ''),
            validator: (value) {
              if (pregunta.obligatorio && (value == null || value.isEmpty)) {
                return 'Este campo es obligatorio';
              }
              return null;
            },
          ),
        );

      case 'FOTOGRAFIA':
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
                      _isWeb
                          ? Container(
                              height: 150,
                              width: double.infinity,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image, size: 50, color: Colors.grey),
                            )
                          : ClipRRect(
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
                              _evaluarReglas(pregunta.id, null);
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
                    onPressed: () {
                      _firmaControllers[pregunta.id]!.clear();
                      setState(() {
                        _firmaGuardada[pregunta.id] = false;
                        _respuestas.remove(pregunta.id);
                      });
                      _evaluarReglas(pregunta.id, null);
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Limpiar'),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () => _guardarFirma(pregunta.id),
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar'),
                  ),
                  if (_firmaGuardada[pregunta.id] == true)
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                ],
              ),
              if (pregunta.obligatorio && _firmaGuardada[pregunta.id] != true)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Requerido', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
        );

      case 'UBICACION':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pregunta.etiqueta, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
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
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _obtenerUbicacion,
                    ),
                  ],
                ),
              ),
              if (_ubicacionActual != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '📍 Ubicación capturada automáticamente',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                  ),
                ),
            ],
          ),
        );

      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            decoration: InputDecoration(
              labelText: pregunta.etiqueta,
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
    }
  }

  // ============================================================
  // GUARDAR RESPUESTAS
  // ============================================================
  Future<void> _guardarRespuestas() async {
    print('🟢 INICIANDO GUARDADO DE RESPUESTAS...');
    
    if (!_formKey.currentState!.validate()) {
      print('❌ Validación del formulario falló');
      return;
    }

    // Validar campos obligatorios
    for (var pregunta in _preguntas) {
      if (!pregunta.visible) continue;
      if (pregunta.obligatorio) {
        if (pregunta.tipoCampo.toUpperCase() == 'UBICACION') {
          if (_ubicacionActual == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('⚠️ ${pregunta.etiqueta} es obligatoria'), backgroundColor: Colors.orange),
            );
            return;
          }
          if (_respuestas[pregunta.id] == null || _respuestas[pregunta.id].toString().isEmpty) {
            _respuestas[pregunta.id] = '${_ubicacionActual!.latitude}, ${_ubicacionActual!.longitude}';
          }
          continue;
        }
        
        final valor = _respuestas[pregunta.id];
        if (valor == null || valor.toString().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ ${pregunta.etiqueta} es obligatorio'), backgroundColor: Colors.orange),
          );
          return;
        }
      }
    }

    if (_ubicacionActual == null && _isWeb) {
      _simularUbicacion();
    }

    if (_ubicacionActual == null && !_isWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Esperando ubicación GPS...'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Formatear respuestas
      final respuestasFormateadas = _respuestas.entries
          .where((entry) => entry.key != 'ubicacion')
          .map((entry) => {
            'campoId': entry.key.toString(),
            'valor': entry.value.toString(),
          })
          .toList();

      // Archivos (fotos y firmas)
      List<Map<String, dynamic>> archivosFormateados = [];
      for (var entry in _fotos.entries) {
        archivosFormateados.add({
          'preguntaId': entry.key,
          'valor': entry.value.path,
          'tipo': 'foto',
        });
      }
      for (var entry in _firmas.entries) {
        archivosFormateados.add({
          'preguntaId': entry.key,
          'valor': entry.value.path,
          'tipo': 'firma',
        });
      }

      print('📝 Respuestas a guardar (${respuestasFormateadas.length}):');
      respuestasFormateadas.forEach((r) => print('  - ${r['campoId']}: ${r['valor']}'));
      print('📍 Ubicación: ${_ubicacionActual!.latitude}, ${_ubicacionActual!.longitude}');

      // Intentar guardar
      final success = await AuthService.guardarRespuestasFormulario(
        formularioId: widget.formulario['id'].toString(),
        usuarioId: widget.usuarioId,
        latitud: _ubicacionActual!.latitude,
        longitud: _ubicacionActual!.longitude,
        respuestas: respuestasFormateadas,
      );

      print('✅ Respuesta del servidor: success=$success');

      setState(() => _isSaving = false);

      if (mounted && success) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('¡Éxito!')],
            ),
            content: const Text('El formulario se ha guardado correctamente.'),
            actions: [
              TextButton(
                onPressed: () { Navigator.pop(context); Navigator.pop(context); },
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
      print('❌ ERROR EN GUARDADO: $e');
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red),
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
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('📤 Enviar Formulario', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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