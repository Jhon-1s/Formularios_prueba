import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pregunta_model.dart';

class FormularioService {
  static const String apiUrl = 'http://192.168.1.X:4000/graphql'; // CAMBIA TU IP

  // Obtener estructura completa del formulario (secciones + preguntas)
  static Future<Map<String, dynamic>> getEstructuraFormulario(int formularioId) async {
    const String query = '''
      query GetFormularioEstructura(\$id: ID!) {
        getFormulario(id: \$id) {
          id
          titulo
          descripcion
          secciones {
            id
            titulo
            orden
            preguntas {
              id
              tipo_campo
              etiqueta
              ayuda
              placeholder
              orden
              obligatorio
              visible
              config
              reglas_validacion
            }
          }
        }
      }
    ''';

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'query': query,
        'variables': {'id': formularioId.toString()},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['data'] != null && data['data']['getFormulario'] != null) {
        return data['data']['getFormulario'];
      }
    }
    return {};
  }
}