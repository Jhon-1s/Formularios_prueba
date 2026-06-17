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
  // FORMULARIOS DISPONIBLES
  // ============================================================
  static Future<List<dynamic>> getFormulariosDisponibles() async {
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

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['getFormulariosDisponibles'] != null) {
          return data['data']['getFormulariosDisponibles'];
        }
      }
      return [];
    } catch (e) {
      return [];
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
  // SEMANA 6: ESTRUCTURA DEL FORMULARIO
  // ============================================================
  static Future<Map<String, dynamic>> getEstructuraFormulario(String formularioId) async {
    const String query = '''
      query ObtenerFormulario(\$id: String!) {
        getFormularioPorId(id: \$id, empresaId: "1") {
          id
          titulo
          campos {
            id
            tipo
            etiqueta
            orden
            requerido
          }
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'variables': {'id': formularioId},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['getFormularioPorId'] != null) {
          return data['data']['getFormularioPorId'];
        }
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // ============================================================
  // SEMANA 7: REGLAS CONDICIONALES
  // ============================================================
  static Future<List<Map<String, dynamic>>> getReglasFormulario(String formularioId) async {
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

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'variables': {'id': formularioId},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['getReglasFormulario'] != null) {
          return List<Map<String, dynamic>>.from(data['data']['getReglasFormulario']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // SEMANA 6: GUARDAR RESPUESTAS CON GPS
  // ============================================================
  static Future<bool> guardarRespuestasFormulario({
    required String formularioId,
    required String usuarioId,
    required double latitud,
    required double longitud,
    required List<Map<String, dynamic>> respuestas,
  }) async {
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

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
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
      return false;
    }
  }
}