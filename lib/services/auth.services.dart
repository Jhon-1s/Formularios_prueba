import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String apiUrl = 'http://192.168.1.X:4000/graphql'; // CAMBIA TU IP
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // Guardar token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Obtener token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Guardar usuario
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  // Obtener usuario
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userStr = prefs.getString(_userKey);
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  // Limpiar sesión
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  // Verificar si está logueado
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Realizar login
  static Future<Map<String, dynamic>> login(String email, String password) async {
    const String mutation = '''
      mutation Login(\$email: String!, \$password: String!) {
        login(email: \$email, password: \$password) {
          token
          usuario {
            id
            empresa_id
            nombre
            email
            rol
            activo
          }
        }
      }
    ''';

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
        await saveToken(token);
        await saveUser(user);
        return {'success': true, 'user': user};
      }
      return {'success': false, 'error': data['errors']?[0]['message'] ?? 'Error desconocido'};
    }
    return {'success': false, 'error': 'Error de conexión'};
  }
}