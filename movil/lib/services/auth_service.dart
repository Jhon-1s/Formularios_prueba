import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String apiUrl = 'https://presoak-edge-chance.ngrok-free.dev/graphql';

  // ============================================================
  // AUTENTICACIÓN
  // ============================================================
  static Future<Map<String, dynamic>> login(String email, String password) async {
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

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': mutation,
          'variables': {'email': email, 'password': password},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['login'] != null) {
          final token = data['data']['login']['token'];
          final user = data['data']['login']['usuario'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token);
          await prefs.setString('user_data', jsonEncode(user));
          return {'success': true, 'user': user};
        }
      }
      return {'success': false};
    } catch (e) {
      return {'success': false};
    }
  }

  // ============================================================
  // SEMANA 8: GUARDAR RESPUESTAS CON FOTOS Y FIRMAS
  // ============================================================
  static Future<bool> guardarRespuestasConEvidencias({
    required String formularioId,
    required String usuarioId,
    required double latitud,
    required double longitud,
    required List<Map<String, dynamic>> respuestas,
    required List<Map<String, dynamic>> archivos,
  }) async {
    const String mutation = '''
      mutation GuardarInspeccionCompleta(
        \$formularioId: String!
        \$usuarioId: String!
        \$gps: GPSInput!
        \$respuestas: [RespuestaInput!]!
        \$archivos: [ArchivoInput!]!
      ) {
        guardarRespuestasFormulario(
          formularioId: \$formularioId
          usuarioId: \$usuarioId
          gps: \$gps
          respuestas: \$respuestas
          archivos: \$archivos
        )
      }
    ''';

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('⚠️ No hay token, no se pueden guardar respuestas');
        return false;
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
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
            'archivos': archivos,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['guardarRespuestasFormulario'] != null) {
          return data['data']['guardarRespuestasFormulario'] == true;
        }
      }
      return false;
    } catch (e) {
      print('❌ Error al guardar: $e');
      return false;
    }
  }

  // ============================================================
  // SEMANA 10: OBTENER DETALLE DE RESPUESTA (CON UUID)
  // ============================================================
  static Future<Map<String, dynamic>> getDetalleRespuesta(String respuestaId) async {
    try {
      const String query = '''
        query GetDetalleRespuesta(\$id: ID!) {
          getDetalleRespuesta(id: \$id) {
            id
            formulario_id
            formulario_titulo
            usuario_nombre_completo
            usuario_email
            fecha_completado
            estado
            ubicacion_lat
            ubicacion_lng
            tiempo_respuesta_segundos
            detalles {
              pregunta_id
              valor_texto
              valor_numero
              valor_fecha
              valor_booleano
              pregunta_etiqueta
              tipo_campo
            }
          }
        }
      ''';

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('⚠️ No hay token, no se puede obtener detalle');
        return {};
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'query': query,
          'variables': {'id': respuestaId},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['getDetalleRespuesta'] != null) {
          return data['data']['getDetalleRespuesta'];
        }
      }
      return {};
    } catch (e) {
      print('❌ Error obteniendo detalle: $e');
      return {};
    }
  }

  // ============================================================
  // SEMANA 9: GUARDAR RESPUESTAS OFFLINE
  // ============================================================
  static Future<void> guardarRespuestaOffline({
    required String formularioId,
    required String usuarioId,
    required Map<String, dynamic> respuestas,
    required List<Map<String, dynamic>> archivos,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    final pendientesStr = prefs.getString('respuestas_pendientes');
    List<dynamic> pendientes = pendientesStr != null 
        ? jsonDecode(pendientesStr) 
        : [];
    
    pendientes.add({
      'formularioId': formularioId,
      'usuarioId': usuarioId,
      'fecha': DateTime.now().toIso8601String(),
      'respuestas': respuestas,
      'archivos': archivos,
    });
    
    await prefs.setString('respuestas_pendientes', jsonEncode(pendientes));
  }

  // ============================================================
  // SEMANA 9: SINCRONIZAR RESPUESTAS PENDIENTES
  // ============================================================
  static Future<int> sincronizarRespuestasPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final pendientesStr = prefs.getString('respuestas_pendientes');
    
    if (pendientesStr == null) return 0;
    
    final pendientes = jsonDecode(pendientesStr);
    int sincronizadas = 0;
    
    for (var respuesta in pendientes) {
      try {
        final success = await guardarRespuestasConEvidencias(
          formularioId: respuesta['formularioId'],
          usuarioId: respuesta['usuarioId'],
          latitud: 0.0,
          longitud: 0.0,
          respuestas: List<Map<String, dynamic>>.from(respuesta['respuestas']),
          archivos: List<Map<String, dynamic>>.from(respuesta['archivos']),
        );
        
        if (success) {
          sincronizadas++;
        }
      } catch (e) {
        print('Error sincronizando: $e');
      }
    }
    
    if (sincronizadas > 0) {
      await prefs.remove('respuestas_pendientes');
    }
    
    return sincronizadas;
  }

  // ============================================================
  // SEMANA 9: VERIFICAR CONEXIÓN A INTERNET
  // ============================================================
  static Future<bool> hasInternet() async {
    try {
      final client = http.Client();
      try {
        final response = await client
            .get(Uri.parse('https://www.google.com'))
            .timeout(const Duration(seconds: 5));
        return response.statusCode == 200;
      } finally {
        client.close();
      }
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // USUARIO Y SESIÓN
  // ============================================================
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userStr = prefs.getString('user_data');
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ============================================================
  // FORMULARIOS DISPONIBLES (CON CACHÉ Y TOKEN)
  // ============================================================
  static Future<List<dynamic>> getFormulariosDisponibles() async {
    try {
      final cached = await getFormulariosLocal();
      if (cached.isNotEmpty) {
        return cached;
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('⚠️ No hay token, cargando desde caché');
        return await getFormulariosLocal();
      }

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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['getFormulariosDisponibles'] != null) {
          final formularios = data['data']['getFormulariosDisponibles'];
          await saveFormulariosLocal(formularios);
          return formularios;
        }
      }
      return await getFormulariosLocal();
    } catch (e) {
      print('❌ Error en getFormulariosDisponibles: $e');
      return await getFormulariosLocal();
    }
  }

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
  // SEMANA 6: ESTRUCTURA DEL FORMULARIO (CON TOKEN)
  // ============================================================
  static Future<Map<String, dynamic>> getEstructuraFormulario(String formularioId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('⚠️ No hay token, no se puede obtener estructura');
        return {};
      }

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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'query': query,
          'variables': {'id': formularioId},
        }),
      );

      print('🔍 Response status: ${response.statusCode}');
      print('🔍 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['getFormularioPorId'] != null) {
          return data['data']['getFormularioPorId'];
        } else if (data['errors'] != null) {
          print('❌ Error GraphQL: ${data['errors']}');
        }
      } else {
        print('❌ Error HTTP: ${response.statusCode}');
      }
      return {};
    } catch (e) {
      print('❌ Error en getEstructuraFormulario: $e');
      return {};
    }
  }

  // ============================================================
  // SEMANA 12: OBTENER HISTORIAL COMPLETO (CON TOKEN)
  // ============================================================
  static Future<List<Map<String, dynamic>>> getHistorialRespuestas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('⚠️ No hay token, no se puede obtener historial');
        return [];
      }

      const String query = '''
        query {
          getHistorialRespuestas {
            id
            formulario_id
            formulario_titulo
            usuario_nombre_completo
            usuario_email
            fecha_completado
            estado
            ubicacion_lat
            ubicacion_lng
            tiempo_respuesta_segundos
            pdf_generado
          }
        }
      ''';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['getHistorialRespuestas'] != null) {
          return List<Map<String, dynamic>>.from(data['data']['getHistorialRespuestas']);
        }
      }
      return [];
    } catch (e) {
      print('❌ Error obteniendo historial: $e');
      return [];
    }
  }

  // ============================================================
  // SEMANA 7: REGLAS CONDICIONALES - RETORNA LISTA VACÍA (NO LLAMA AL BACKEND)
  // ============================================================
  // ============================================================
// SEMANA 7: REGLAS CONDICIONALES
// ============================================================
static Future<List<Map<String, dynamic>>> getReglasFormulario(String formularioId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      print('⚠️ No hay token, no se pueden obtener reglas');
      return [];
    }

    const String query = '''
      query ObtenerReglas(\$id: String!) {
        getReglasFormulario(id: \$id) {
          id
          preguntaOrigenId
          preguntaDestinoId
          condicionOperador
          valorEsperado
          accion
          activo
        }
      }
    ''';

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'query': query,
        'variables': {'id': formularioId},
      }),
    );

    print('📡 Reglas response status: ${response.statusCode}');
    print('📡 Reglas response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['data'] != null && data['data']['getReglasFormulario'] != null) {
        final reglas = List<Map<String, dynamic>>.from(data['data']['getReglasFormulario']);
        print('✅ Reglas obtenidas: ${reglas.length}');
        return reglas;
      } else if (data['errors'] != null) {
        print('❌ Error GraphQL: ${data['errors']}');
      }
    }
    return [];
  } catch (e) {
    print('❌ Error en getReglasFormulario: $e');
    return [];
  }
}

  // ============================================================
  // SEMANA 6: GUARDAR RESPUESTAS CON GPS (CON TOKEN)
  // ============================================================
  static Future<bool> guardarRespuestasFormulario({
    required String formularioId,
    required String usuarioId,
    required double latitud,
    required double longitud,
    required List<Map<String, dynamic>> respuestas,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('⚠️ No hay token, no se pueden guardar respuestas');
        return false;
      }

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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
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
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['guardarRespuestasFormulario'] != null) {
          return data['data']['guardarRespuestasFormulario'] == true;
        }
      }
      return false;
    } catch (e) {
      print('❌ Error en guardarRespuestasFormulario: $e');
      return false;
    }
  }
}