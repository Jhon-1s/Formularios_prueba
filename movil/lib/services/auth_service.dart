import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String apiUrl = 'https://presoak-edge-chance.ngrok-free.dev/graphql';
  
  // ✅ USUARIOS DE PRUEBA LOCALES (FALLBACK)
  static final Map<String, Map<String, String>> _usuariosPrueba = {
    'admin@formbuilder.com': {
      'password': 'admin123',
      'nombre': 'Administrador',
      'rol': 'admin',
      'id': '1',
    },
    'juan@formbuilder.com': {
      'password': 'admin123',
      'nombre': 'Juan Pérez',
      'rol': 'encuestador',
      'id': '2',
    },
    'test@test.com': {
      'password': '123456',
      'nombre': 'Usuario Test',
      'rol': 'usuario',
      'id': '3',
    },
  };

  // ✅ HEADERS HELPER - CLAVE PARA NGROK
  static Map<String, String> _headers({String? token}) => {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  // ============================================================
  // ✅ LOGIN - CON NGROK HEADER Y FALLBACK LOCAL
  // ============================================================
  static Future<Map<String, dynamic>> login(String email, String password) async {
    print('═══════════════════════════════════════════════════');
    print('🔍 LOGIN INTENTADO: $email');
    print('🔑 Password: ${'*' * password.length}');
    
    // ✅ VERIFICAR USUARIOS LOCALES PRIMERO
    if (_usuariosPrueba.containsKey(email)) {
      final userData = _usuariosPrueba[email]!;
      if (userData['password'] == password) {
        print('✅ LOGIN LOCAL EXITOSO: $email');
        
        final user = {
          'id': userData['id'],
          'nombre': userData['nombre'],
          'email': email,
          'rol': userData['rol'],
        };
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(user));
        await prefs.remove('is_guest');
        await prefs.setBool('is_local_user', true);
        await prefs.setString('token', 'local_token_${DateTime.now().millisecondsSinceEpoch}');
        
        print('👤 Usuario guardado: ${user['nombre']}');
        print('═══════════════════════════════════════════════════');
        return {'success': true, 'user': user, 'local': true};
      } else {
        print('❌ CONTRASEÑA INCORRECTA para: $email');
        print('═══════════════════════════════════════════════════');
        return {'success': false, 'error': 'Credenciales incorrectas'};
      }
    }

    // ✅ INTENTAR CON SERVIDOR
    print('🌐 Intentando login con servidor...');
    print('📡 URL: $apiUrl');
    
    try {
      const String mutation = '''
        mutation Login(\$email: String!, \$password: String!) {
          login(email: \$email, password: \$password) {
            token
            usuario {
              id
              nombre
              email
              rol
            }
          }
        }
      ''';

      final body = jsonEncode({
        'query': mutation,
        'variables': {'email': email, 'password': password},
      });
      
      print('📤 Body: $body');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: _headers(),
        body: body,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏰ TIMEOUT - Servidor no responde');
          return http.Response('{"error": "timeout"}', 408);
        },
      );

      print('📡 STATUS: ${response.statusCode}');
      print('📡 BODY PRIMEROS 200: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      // ✅ Verificar que NO sea HTML de ngrok
      if (response.body.trim().startsWith('<!DOCTYPE html>') || 
          response.body.trim().startsWith('<html>')) {
        print('❌ Recibido HTML de ngrok');
        return _intentarLoginLocalFallback(email, password);
      }

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          
          if (data['errors'] != null) {
            print('❌ Error GraphQL: ${data['errors']}');
            return {
              'success': false,
              'error': data['errors'][0]['message'] ?? 'Error en el servidor'
            };
          }

          if (data['data'] != null && data['data']['login'] != null) {
            final token = data['data']['login']['token'];
            final user = data['data']['login']['usuario'];
            
            print('✅ LOGIN SERVIDOR EXITOSO');
            print('👤 Usuario: ${user['nombre']}');
            print('📧 Email: ${user['email']}');
            
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('token', token);
            await prefs.setString('user_data', jsonEncode(user));
            await prefs.remove('is_guest');
            await prefs.remove('is_local_user');
            
            return {'success': true, 'user': user};
          }
        } catch (e) {
          print('❌ Error decodificando JSON: $e');
          return _intentarLoginLocalFallback(email, password);
        }
      }
      
      print('❌ Servidor no respondió correctamente');
      return _intentarLoginLocalFallback(email, password);
      
    } catch (e) {
      print('❌ Excepción: $e');
      return _intentarLoginLocalFallback(email, password);
    }
  }

  // ============================================================
  // 🔧 FALLBACK: Intentar login local
  // ============================================================
  static Future<Map<String, dynamic>> _intentarLoginLocalFallback(String email, String password) async {
    print('🔄 Intentando login LOCAL como fallback...');
    
    if (_usuariosPrueba.containsKey(email)) {
      final userData = _usuariosPrueba[email]!;
      if (userData['password'] == password) {
        print('✅ LOGIN LOCAL EXITOSO (fallback): $email');
        
        final user = {
          'id': userData['id'],
          'nombre': userData['nombre'],
          'email': email,
          'rol': userData['rol'],
        };
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(user));
        await prefs.setBool('is_local_user', true);
        await prefs.remove('is_guest');
        await prefs.setString('token', 'local_token_${DateTime.now().millisecondsSinceEpoch}');
        
        return {'success': true, 'user': user, 'local': true};
      }
    }
    
    // ✅ Si password es admin123, crear usuario temporal
    if (password == 'admin123' || password == '123456') {
      print('🔧 Creando usuario temporal para: $email');
      
      final user = {
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'nombre': email.split('@').first,
        'email': email,
        'rol': 'usuario',
      };
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(user));
      await prefs.setBool('is_local_user', true);
      await prefs.remove('is_guest');
      await prefs.setString('token', 'temp_token_${DateTime.now().millisecondsSinceEpoch}');
      
      return {'success': true, 'user': user, 'local': true};
    }
    
    print('❌ Login falló para: $email');
    return {'success': false, 'error': 'Credenciales incorrectas'};
  }

  // ============================================================
  // ✅ LOGIN INVITADO
  // ============================================================
  static Future<Map<String, dynamic>> loginInvitado() async {
    try {
      final guestUser = {
        'id': 'guest_${DateTime.now().millisecondsSinceEpoch}',
        'nombre': 'Invitado',
        'email': 'invitado@temp.com',
        'rol': 'invitado',
      };
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(guestUser));
      await prefs.setBool('is_guest', true);
      await prefs.remove('is_local_user');
      
      await saveFormulariosLocal(_getFormulariosPrueba());
      
      return {'success': true, 'user': guestUser};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============================================================
  // 📋 REGISTRAR USUARIO
  // ============================================================
  static Future<Map<String, dynamic>> registrarUsuario({
    required String email,
    required String password,
    required String nombre,
    int empresaId = 1,
    String rol = 'usuario',
  }) async {
    print('🔍 Registrando: $email');
    
    if (_usuariosPrueba.containsKey(email)) {
      return {'success': false, 'error': 'El usuario ya existe'};
    }
    
    _usuariosPrueba[email] = {
      'password': password,
      'nombre': nombre,
      'rol': rol,
      'id': (int.parse(_usuariosPrueba.length.toString()) + 1).toString(),
    };
    
    print('✅ Usuario registrado localmente: $email');
    
    try {
      const String mutation = '''
        mutation RegistrarUsuario(
          \$email: String!
          \$password: String!
          \$nombre: String!
          \$empresaId: Int!
          \$rol: String!
        ) {
          registrarUsuario(
            email: \$email
            password: \$password
            nombre: \$nombre
            empresaId: \$empresaId
            rol: \$rol
          ) {
            token
            usuario {
              id
              nombre
              email
              rol
            }
          }
        }
      ''';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: _headers(),
        body: jsonEncode({
          'query': mutation,
          'variables': {
            'email': email,
            'password': password,
            'nombre': nombre,
            'empresaId': empresaId,
            'rol': rol,
          },
        }),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⏰ Timeout en registro');
          return http.Response('{"error": "timeout"}', 408);
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['registrarUsuario'] != null) {
          final token = data['data']['registrarUsuario']['token'];
          final user = data['data']['registrarUsuario']['usuario'];
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token);
          await prefs.setString('user_data', jsonEncode(user));
          await prefs.remove('is_guest');
          await prefs.remove('is_local_user');
          
          print('✅ Registro exitoso en servidor');
          return {'success': true, 'user': user};
        }
      }
      
      return {
        'success': true,
        'user': {
          'id': _usuariosPrueba[email]!['id'],
          'nombre': nombre,
          'email': email,
          'rol': rol,
        },
        'local': true
      };
      
    } catch (e) {
      print('❌ Error en registro: $e');
      return {
        'success': true,
        'user': {
          'id': _usuariosPrueba[email]!['id'],
          'nombre': nombre,
          'email': email,
          'rol': rol,
        },
        'local': true
      };
    }
  }

  // ============================================================
  // 👤 OBTENER USUARIO ACTUAL
  // ============================================================
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userStr = prefs.getString('user_data');
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  // ============================================================
  // ✅ VERIFICAR SI ES INVITADO
  // ============================================================
  static Future<bool> esInvitado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_guest') ?? false;
  }

  // ============================================================
  // ✅ VERIFICAR SI ES USUARIO LOCAL
  // ============================================================
  static Future<bool> esUsuarioLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_local_user') ?? false;
  }

  // ============================================================
  // 📋 OBTENER USUARIOS DE PRUEBA
  // ============================================================
  static List<Map<String, String>> getUsuariosPrueba() {
    return _usuariosPrueba.entries.map((entry) => {
      'email': entry.key,
      'password': entry.value['password']!,
      'nombre': entry.value['nombre']!,
      'rol': entry.value['rol']!,
    }).toList();
  }

  // ============================================================
  // 🚪 CERRAR SESIÓN
  // ============================================================
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ============================================================
  // 🔌 VERIFICAR CONEXIÓN
  // ============================================================
  static Future<bool> hasInternet() async {
    try {
      final response = await http
          .get(Uri.parse('https://httpbin.org/status/200'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // 📋 FORMULARIOS DE PRUEBA LOCALES (CON TODOS LOS CAMPOS)
  // ============================================================
  static List<Map<String, dynamic>> _getFormulariosPrueba() {
    return [
      // ✅ FORMULARIO COMPLETO - CON TODOS LOS TIPOS DE CAMPOS
      {
        'id': '1',
        'titulo': '📋 FORMULARIO COMPLETO',
        'descripcion': 'Formulario con todos los tipos de campos: foto, firma, fecha, hora, ubicación y más',
        'estado': 'publicado',
        'campos': [
          // 📝 Texto
          {'id': '1_1', 'etiqueta': 'Nombre completo', 'tipo': 'texto', 'requerido': true, 'orden': 1, 'placeholder': 'Ej: Juan Pérez', 'config': {'maxlength': 100, 'minlength': 3}},
          {'id': '1_2', 'etiqueta': 'Descripción detallada', 'tipo': 'texto_largo', 'requerido': false, 'orden': 2, 'placeholder': 'Describe en detalle...', 'config': {'maxlength': 500, 'filas': 4}},
          
          // 📧 Email y Teléfono
          {'id': '1_3', 'etiqueta': 'Correo electrónico', 'tipo': 'email', 'requerido': true, 'orden': 3, 'placeholder': 'ejemplo@correo.com'},
          {'id': '1_4', 'etiqueta': 'Número de teléfono', 'tipo': 'telefono', 'requerido': false, 'orden': 4, 'placeholder': '55 1234 5678'},
          
          // 🔢 Número
          {'id': '1_5', 'etiqueta': 'Edad', 'tipo': 'numerico', 'requerido': false, 'orden': 5, 'placeholder': '18', 'config': {'min': 1, 'max': 120}},
          {'id': '1_6', 'etiqueta': 'Cantidad de productos', 'tipo': 'numerico', 'requerido': false, 'orden': 6, 'placeholder': '0'},
          
          // 📅 Fecha y Hora
          {'id': '1_7', 'etiqueta': 'Fecha de registro', 'tipo': 'fecha', 'requerido': true, 'orden': 7, 'config': {'formato': 'DD/MM/YYYY'}},
          {'id': '1_8', 'etiqueta': 'Hora de atención', 'tipo': 'hora', 'requerido': false, 'orden': 8, 'config': {'formato': 'HH:MM'}},
          {'id': '1_9', 'etiqueta': 'Fecha y hora del evento', 'tipo': 'fecha_hora', 'requerido': false, 'orden': 9, 'config': {'formato': 'DD/MM/YYYY HH:MM'}},
          
          // 📋 Selección
          {'id': '1_10', 'etiqueta': 'Tipo de servicio', 'tipo': 'seleccion', 'requerido': true, 'orden': 10, 'config': {'opciones': ['Mantenimiento', 'Instalación', 'Consultoría', 'Capacitación', 'Otro']}},
          {'id': '1_11', 'etiqueta': 'Intereses', 'tipo': 'checkbox', 'requerido': false, 'orden': 11, 'config': {'opciones': ['Tecnología', 'Deportes', 'Arte', 'Música', 'Ciencia', 'Literatura']}},
          
          // ☑️ Checkbox simple
          {'id': '1_12', 'etiqueta': 'Acepto los términos y condiciones', 'tipo': 'checkbox', 'requerido': true, 'orden': 12},
          {'id': '1_13', 'etiqueta': '¿Desea recibir notificaciones?', 'tipo': 'checkbox', 'requerido': false, 'orden': 13},
          
          // 📸 Foto
          {'id': '1_14', 'etiqueta': 'Foto de perfil', 'tipo': 'fotografia', 'requerido': false, 'orden': 14, 'config': {'max_fotos': 1, 'calidad': 0.8}},
          {'id': '1_15', 'etiqueta': 'Evidencia fotográfica', 'tipo': 'fotografia', 'requerido': true, 'orden': 15, 'config': {'max_fotos': 5, 'calidad': 0.8}},
          
          // ✍️ Firma
          {'id': '1_16', 'etiqueta': 'Firma del participante', 'tipo': 'firma', 'requerido': true, 'orden': 16, 'config': {'color': '#000000'}},
          
          // 📍 Ubicación
          {'id': '1_17', 'etiqueta': 'Ubicación actual', 'tipo': 'ubicacion', 'requerido': false, 'orden': 17, 'config': {'zoom': 15}},
        ]
      },
      
      // 📝 Encuesta de Satisfacción
      {
        'id': '2',
        'titulo': '📝 Encuesta de Satisfacción',
        'descripcion': 'Encuesta para medir la satisfacción del cliente',
        'estado': 'publicado',
        'campos': [
          {'id': '2_1', 'etiqueta': 'Nombre completo', 'tipo': 'texto', 'requerido': true, 'orden': 1, 'placeholder': 'Tu nombre'},
          {'id': '2_2', 'etiqueta': 'Fecha de atención', 'tipo': 'fecha', 'requerido': true, 'orden': 2},
          {'id': '2_3', 'etiqueta': 'Correo electrónico', 'tipo': 'email', 'requerido': true, 'orden': 3, 'placeholder': 'correo@ejemplo.com'},
          {'id': '2_4', 'etiqueta': 'Satisfacción General', 'tipo': 'seleccion', 'requerido': true, 'orden': 4, 'config': {'opciones': ['Muy Satisfecho', 'Satisfecho', 'Neutral', 'Insatisfecho', 'Muy Insatisfecho']}},
          {'id': '2_5', 'etiqueta': '¿Qué mejorarías?', 'tipo': 'checkbox', 'requerido': false, 'orden': 5, 'config': {'opciones': ['Atención', 'Tiempo de espera', 'Calidad', 'Precio', 'Instalaciones']}},
          {'id': '2_6', 'etiqueta': 'Comentarios adicionales', 'tipo': 'texto_largo', 'requerido': false, 'orden': 6, 'placeholder': 'Escribe tus comentarios...'},
          {'id': '2_7', 'etiqueta': 'Evidencia', 'tipo': 'fotografia', 'requerido': false, 'orden': 7},
          {'id': '2_8', 'etiqueta': 'Firma', 'tipo': 'firma', 'requerido': false, 'orden': 8},
          {'id': '2_9', 'etiqueta': 'Ubicación', 'tipo': 'ubicacion', 'requerido': false, 'orden': 9},
        ]
      },
      
      // 🔧 Evaluación de Proveedores
      {
        'id': '3',
        'titulo': '🔧 Evaluación de Proveedores',
        'descripcion': 'Formulario para evaluar proveedores',
        'estado': 'publicado',
        'campos': [
          {'id': '3_1', 'etiqueta': 'Nombre del Proveedor', 'tipo': 'texto', 'requerido': true, 'orden': 1, 'placeholder': 'Nombre de la empresa'},
          {'id': '3_2', 'etiqueta': 'Fecha de Evaluación', 'tipo': 'fecha', 'requerido': true, 'orden': 2},
          {'id': '3_3', 'etiqueta': 'Hora de Visita', 'tipo': 'hora', 'requerido': true, 'orden': 3},
          {'id': '3_4', 'etiqueta': 'Email de Contacto', 'tipo': 'email', 'requerido': true, 'orden': 4, 'placeholder': 'contacto@empresa.com'},
          {'id': '3_5', 'etiqueta': 'Teléfono', 'tipo': 'telefono', 'requerido': false, 'orden': 5, 'placeholder': '55 1234 5678'},
          {'id': '3_6', 'etiqueta': 'Calificación', 'tipo': 'seleccion', 'requerido': true, 'orden': 6, 'config': {'opciones': ['Excelente', 'Bueno', 'Regular', 'Malo', 'Pésimo']}},
          {'id': '3_7', 'etiqueta': 'Servicios que ofrece', 'tipo': 'checkbox', 'requerido': false, 'orden': 7, 'config': {'opciones': ['Mantenimiento', 'Construcción', 'Limpieza', 'Seguridad', 'Catering', 'Transporte']}},
          {'id': '3_8', 'etiqueta': 'Observaciones', 'tipo': 'texto_largo', 'requerido': false, 'orden': 8, 'placeholder': 'Observaciones adicionales...'},
          {'id': '3_9', 'etiqueta': 'Evidencia Fotográfica', 'tipo': 'fotografia', 'requerido': false, 'orden': 9, 'config': {'max_fotos': 10, 'calidad': 0.9}},
          {'id': '3_10', 'etiqueta': 'Firma del Evaluador', 'tipo': 'firma', 'requerido': true, 'orden': 10},
          {'id': '3_11', 'etiqueta': 'Ubicación', 'tipo': 'ubicacion', 'requerido': false, 'orden': 11},
          {'id': '3_12', 'etiqueta': 'Fecha y Hora de registro', 'tipo': 'fecha_hora', 'requerido': false, 'orden': 12},
        ]
      }
    ];
  }

  // ============================================================
  // 📋 FORMULARIOS DISPONIBLES (PRIORIZA SERVIDOR)
  // ============================================================
  static Future<List<dynamic>> getFormulariosDisponibles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // ✅ SI HAY TOKEN REAL, intentar con el servidor
      if (token != null && !token.startsWith('local_') && !token.startsWith('temp_')) {
        print('🌐 Obteniendo formularios del servidor...');
        
        const String query = '''
          query {
            getFormulariosDisponibles {
              id
              titulo
              descripcion
              estado
            }
          }
        ''';

        final response = await http.post(
          Uri.parse(apiUrl),
          headers: _headers(token: token),
          body: jsonEncode({'query': query}),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('⏰ Timeout obteniendo formularios');
            return http.Response('{"error": "timeout"}', 408);
          },
        );

        print('📡 Status formularios: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          if (data['errors'] != null) {
            print('❌ Error GraphQL: ${data['errors']}');
            return await _getFormulariosFallback();
          }

          if (data['data'] != null && data['data']['getFormulariosDisponibles'] != null) {
            final formularios = data['data']['getFormulariosDisponibles'];
            print('✅ ${formularios.length} formularios obtenidos del servidor');
            
            // ✅ Guardar en caché para offline
            await saveFormulariosLocal(formularios);
            return formularios;
          }
        }
        
        print('⚠️ Servidor no respondió, usando fallback');
        return await _getFormulariosFallback();
      }

      // ✅ Si es usuario local/invitado, usar fallback
      print('📱 Usuario local/invitado, usando formularios de prueba');
      return await _getFormulariosFallback();
      
    } catch (e) {
      print('❌ Error en getFormulariosDisponibles: $e');
      return await _getFormulariosFallback();
    }
  }

  // ============================================================
  // 📋 FALLBACK PARA FORMULARIOS
  // ============================================================
  static Future<List<dynamic>> _getFormulariosFallback() async {
    // 1. Intentar caché local
    final cached = await getFormulariosLocal();
    if (cached.isNotEmpty) {
      print('📂 Usando formularios de caché: ${cached.length}');
      return cached;
    }
    
    // 2. Si no hay caché, usar formularios de prueba
    print('📂 Usando formularios de prueba locales');
    return _getFormulariosPrueba();
  }

  // ============================================================
  // 💾 GUARDAR FORMULARIOS EN CACHÉ
  // ============================================================
  static Future<void> saveFormulariosLocal(List<dynamic> formularios) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('formularios_cache', jsonEncode(formularios));
  }

  static Future<List<dynamic>> getFormulariosLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final String? formsStr = prefs.getString('formularios_cache');
    if (formsStr != null) {
      return jsonDecode(formsStr);
    }
    return [];
  }

  // ============================================================
  // 📋 ESTRUCTURA DEL FORMULARIO (PRIORIZA SERVIDOR)
  // ============================================================

static Future<Map<String, dynamic>> getEstructuraFormulario(String formularioId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // ✅ SI HAY TOKEN REAL, intentar con el servidor
    if (token != null && !token.startsWith('local_') && !token.startsWith('temp_')) {
      print('🌐 Obteniendo estructura del servidor para: $formularioId');
      
      // ✅ CONSULTA CORREGIDA - SOLO CAMPOS QUE EXISTEN
      const String query = '''
        query GetFormularioPorId(\$id: ID!) {
          getFormularioPorId(id: \$id) {
            id
            titulo
            empresaId
            campos {
              id
              etiqueta
              tipo
              requerido
              orden
            }
          }
        }
      ''';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: _headers(token: token),
        body: jsonEncode({
          'query': query,
          'variables': {'id': formularioId},
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏰ Timeout obteniendo estructura');
          return http.Response('{"error": "timeout"}', 408);
        },
      );

      print('📡 Status estructura: ${response.statusCode}');
      print('📡 Body estructura: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['errors'] != null) {
          print('❌ Error GraphQL: ${data['errors']}');
          // ✅ Si hay error, usar estructura local
          return await _getEstructuraFallback(formularioId);
        }

        if (data['data'] != null && data['data']['getFormularioPorId'] != null) {
          final estructura = data['data']['getFormularioPorId'];
          print('✅ Estructura obtenida del servidor');
          print('📋 Campos: ${estructura['campos']?.length ?? 0}');
          return estructura;
        }
      }
      
      print('⚠️ Servidor no respondió, usando fallback');
      return await _getEstructuraFallback(formularioId);
    }

    // ✅ Si es usuario local/invitado, usar fallback
    print('📱 Usuario local/invitado, usando estructura local');
    return await _getEstructuraFallback(formularioId);
    
  } catch (e) {
    print('❌ Error en getEstructuraFormulario: $e');
    return await _getEstructuraFallback(formularioId);
  }
}
  // ============================================================
// 📋 FALLBACK PARA ESTRUCTURA (LOCAL)
// ============================================================
static Future<Map<String, dynamic>> _getEstructuraFallback(String formularioId) async {
  // Buscar en formularios de prueba
  final formularios = _getFormulariosPrueba();
  for (var f in formularios) {
    if (f['id'].toString() == formularioId) {
      print('📂 Usando estructura local para: $formularioId');
      
      // ✅ Convertir campos al formato esperado por el modelo Pregunta
      final campos = (f['campos'] as List).map((campo) {
        return {
          'id': campo['id'],
          'etiqueta': campo['etiqueta'],
          'tipo': campo['tipo'],
          'requerido': campo['requerido'] ?? false,
          'orden': campo['orden'] ?? 0,
          'placeholder': campo['placeholder'] ?? '',
          'ayuda': campo['ayuda'] ?? '',
          'config': campo['config'] ?? {},
        };
      }).toList();
      
      return {
        'id': f['id'],
        'titulo': f['titulo'],
        'descripcion': f['descripcion'] ?? '',
        'empresaId': 1,
        'campos': campos,
      };
    }
  }
  
  // Buscar en caché
  final cached = await getFormulariosLocal();
  for (var f in cached) {
    if (f['id'].toString() == formularioId) {
      print('📂 Usando estructura de caché para: $formularioId');
      return {
        'id': f['id'],
        'titulo': f['titulo'] ?? 'Formulario',
        'descripcion': f['descripcion'] ?? '',
        'empresaId': 1,
        'campos': f['campos'] ?? [],
      };
    }
  }
  
  // Si no existe, devolver estructura básica
  print('⚠️ Formulario no encontrado: $formularioId, usando estructura básica');
  return {
    'id': formularioId,
    'titulo': 'Formulario $formularioId',
    'descripcion': 'Formulario de prueba',
    'empresaId': 1,
    'campos': [
      {'id': '1', 'etiqueta': 'Nombre', 'tipo': 'texto', 'requerido': true, 'orden': 1},
      {'id': '2', 'etiqueta': 'Email', 'tipo': 'email', 'requerido': true, 'orden': 2},
      {'id': '3', 'etiqueta': 'Comentarios', 'tipo': 'texto_largo', 'requerido': false, 'orden': 3},
    ]
  };
}

  // ============================================================
  // 💾 GUARDAR RESPUESTAS
  // ============================================================
  static Future<Map<String, dynamic>> guardarRespuestasFormulario({
    required String formularioId,
    required String usuarioId,
    required double latitud,
    required double longitud,
    required List<Map<String, dynamic>> respuestas,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // Intentar guardar en servidor (si hay token real)
      if (token != null && !token.startsWith('local_') && !token.startsWith('temp_')) {
        try {
          const String mutation = '''
            mutation GuardarInspeccion(
              \$formularioId: String!
              \$usuarioId: String!
              \$gps: GPSInput!
              \$respuestas: [RespuestaInput!]!
            ) {
              guardarRespuestasFormulario(
                formularioId: \$formularioId
                usuarioId: \$usuarioId
                gps: \$gps
                respuestas: \$respuestas
              )
            }
          ''';

          final response = await http.post(
            Uri.parse(apiUrl),
            headers: _headers(token: token),
            body: jsonEncode({
              'query': mutation,
              'variables': {
                'formularioId': formularioId,
                'usuarioId': usuarioId,
                'gps': {
                  'latitud': latitud,
                  'longitud': longitud,
                },
                'respuestas': respuestas,
              },
            }),
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('⏰ Timeout guardando respuestas');
              return http.Response('{"error": "timeout"}', 408);
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['data'] != null && data['data']['guardarRespuestasFormulario'] != null) {
              final success = data['data']['guardarRespuestasFormulario'] == true;
              if (success) {
                print('✅ Respuestas guardadas en servidor');
              }
            }
          }
        } catch (e) {
          print('❌ Error guardando en servidor: $e');
        }
      }

      // ✅ SIEMPRE guardar localmente
      final respuesta = {
        'id': 'resp_${DateTime.now().millisecondsSinceEpoch}',
        'formulario_id': formularioId,
        'formulario_titulo': await _getFormularioTitulo(formularioId),
        'usuario_nombre_completo': (await getUser())?['nombre'] ?? 'Usuario',
        'usuario_email': (await getUser())?['email'] ?? 'usuario@test.com',
        'fecha_completado': DateTime.now().toIso8601String(),
        'estado': 'COMPLETADO',
        'ubicacion_lat': latitud,
        'ubicacion_lng': longitud,
        'respuestas': respuestas,
      };
      
      await _guardarEnHistorial(respuesta);
      print('✅ Respuestas guardadas localmente');
      
      return {'success': true, 'id': respuesta['id']};
    } catch (e) {
      print('❌ Error guardando: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<void> _guardarEnHistorial(Map<String, dynamic> respuesta) async {
    final prefs = await SharedPreferences.getInstance();
    final historialStr = prefs.getString('historial_respuestas');
    List<dynamic> historial = historialStr != null ? jsonDecode(historialStr) : [];
    historial.add(respuesta);
    await prefs.setString('historial_respuestas', jsonEncode(historial));
  }

  static Future<String> _getFormularioTitulo(String formularioId) async {
    // Primero buscar en formularios de prueba
    final formularios = _getFormulariosPrueba();
    for (var f in formularios) {
      if (f['id'].toString() == formularioId) {
        return f['titulo'] ?? 'Formulario';
      }
    }
    // Buscar en caché
    final cached = await getFormulariosLocal();
    for (var f in cached) {
      if (f['id'].toString() == formularioId) {
        return f['titulo'] ?? 'Formulario';
      }
    }
    return 'Formulario $formularioId';
  }

  // ============================================================
  // 📋 OBTENER HISTORIAL
  // ============================================================
  static Future<List<Map<String, dynamic>>> getHistorialRespuestas() async {
    final prefs = await SharedPreferences.getInstance();
    final historialStr = prefs.getString('historial_respuestas');
    if (historialStr != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(historialStr));
    }
    return [];
  }

  // ============================================================
  // 📋 OBTENER DETALLE DE RESPUESTA
  // ============================================================
  static Future<Map<String, dynamic>> getDetalleRespuesta(String respuestaId) async {
    final prefs = await SharedPreferences.getInstance();
    final historialStr = prefs.getString('historial_respuestas');
    if (historialStr != null) {
      final historial = jsonDecode(historialStr);
      for (var item in historial) {
        if (item['id'] == respuestaId) {
          return item;
        }
      }
    }
    return {};
  }

  // ============================================================
  // 📋 REGLAS CONDICIONALES
  // ============================================================
  static Future<List<Map<String, dynamic>>> getReglasFormulario(String formularioId) async {
    return [];
  }

  // ============================================================
  // 💾 GUARDAR OFFLINE
  // ============================================================
  static Future<void> guardarRespuestaOffline({
    required String formularioId,
    required String usuarioId,
    required Map<String, dynamic> respuestas,
    required List<Map<String, dynamic>> archivos,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final pendientesStr = prefs.getString('respuestas_pendientes');
    List<dynamic> pendientes = pendientesStr != null ? jsonDecode(pendientesStr) : [];
    pendientes.add({
      'formularioId': formularioId,
      'usuarioId': usuarioId,
      'fecha': DateTime.now().toIso8601String(),
      'respuestas': respuestas,
      'archivos': archivos,
    });
    await prefs.setString('respuestas_pendientes', jsonEncode(pendientes));
    print('💾 Respuesta guardada localmente (offline)');
  }

  // ============================================================
  // 💾 GUARDAR RESPUESTAS CON EVIDENCIAS
  // ============================================================
  static Future<bool> guardarRespuestasConEvidencias({
    required String formularioId,
    required String usuarioId,
    required double latitud,
    required double longitud,
    required List<Map<String, dynamic>> respuestas,
    required List<Map<String, dynamic>> archivos,
  }) async {
    final result = await guardarRespuestasFormulario(
      formularioId: formularioId,
      usuarioId: usuarioId,
      latitud: latitud,
      longitud: longitud,
      respuestas: respuestas,
    );
    return result['success'] == true;
  }

  // ============================================================
  // 💾 SINCRONIZAR RESPUESTAS PENDIENTES
  // ============================================================
  static Future<int> sincronizarRespuestasPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final pendientesStr = prefs.getString('respuestas_pendientes');
    
    if (pendientesStr == null) return 0;
    
    final pendientes = jsonDecode(pendientesStr);
    int sincronizadas = 0;
    List<dynamic> pendientesRestantes = [];
    
    for (var respuesta in pendientes) {
      try {
        final respuestasFormateadas = (respuesta['respuestas']['respuestas'] as List)
            .map((r) => ({
              'campoId': r['campoId'] ?? r['id'],
              'valor': r['valor'] ?? '',
            }))
            .toList();
        
        final result = await guardarRespuestasFormulario(
          formularioId: respuesta['formularioId'],
          usuarioId: respuesta['usuarioId'],
          latitud: respuesta['respuestas']['gps']?['lat'] ?? 0.0,
          longitud: respuesta['respuestas']['gps']?['lng'] ?? 0.0,
          respuestas: respuestasFormateadas,
        );
        
        if (result['success'] == true) {
          sincronizadas++;
        } else {
          pendientesRestantes.add(respuesta);
        }
      } catch (e) {
        pendientesRestantes.add(respuesta);
      }
    }
    
    if (pendientesRestantes.isNotEmpty) {
      await prefs.setString('respuestas_pendientes', jsonEncode(pendientesRestantes));
    } else {
      await prefs.remove('respuestas_pendientes');
    }
    
    return sincronizadas;
  }

  // ============================================================
  // 📋 CONTAR RESPUESTAS PENDIENTES
  // ============================================================
  static Future<int> contarRespuestasPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final pendientesStr = prefs.getString('respuestas_pendientes');
    if (pendientesStr == null) return 0;
    final pendientes = jsonDecode(pendientesStr);
    return pendientes.length;
  }

  // ============================================================
  // 📋 VERIFICAR SI HAY RESPUESTAS PENDIENTES
  // ============================================================
  static Future<bool> hayRespuestasPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final pendientesStr = prefs.getString('respuestas_pendientes');
    if (pendientesStr == null) return false;
    final pendientes = jsonDecode(pendientesStr);
    return pendientes.isNotEmpty;
  }

  // ============================================================
  // 📊 ESTADÍSTICAS
  // ============================================================
  
  /// Contar el número total de formularios disponibles
  static Future<int> contarFormulariosTotales() async {
    try {
      final formularios = await getFormulariosDisponibles();
      return formularios.length;
    } catch (e) {
      print('❌ Error contando formularios: $e');
      return 0;
    }
  }

  /// Contar el número de formularios completados
  static Future<int> contarFormulariosCompletados() async {
    try {
      final historial = await getHistorialRespuestas();
      return historial.where((r) => 
        r['estado']?.toString().toUpperCase() == 'COMPLETADO'
      ).length;
    } catch (e) {
      print('❌ Error contando completados: $e');
      return 0;
    }
  }

  /// Contar el número de formularios en proceso
  static Future<int> contarFormulariosEnProceso() async {
    try {
      final historial = await getHistorialRespuestas();
      return historial.where((r) => 
        r['estado']?.toString().toUpperCase() == 'EN_PROCESO'
      ).length;
    } catch (e) {
      print('❌ Error contando en proceso: $e');
      return 0;
    }
  }

  /// Obtener estadísticas completas
  static Future<Map<String, int>> getEstadisticas() async {
    try {
      final historial = await getHistorialRespuestas();
      final formularios = await getFormulariosDisponibles();
      
      return {
        'total_formularios': formularios.length,
        'completados': historial.where((r) => 
          r['estado']?.toString().toUpperCase() == 'COMPLETADO'
        ).length,
        'en_proceso': historial.where((r) => 
          r['estado']?.toString().toUpperCase() == 'EN_PROCESO'
        ).length,
        'pendientes': await contarRespuestasPendientes(),
      };
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return {
        'total_formularios': 0,
        'completados': 0,
        'en_proceso': 0,
        'pendientes': 0,
      };
    }
  }
}