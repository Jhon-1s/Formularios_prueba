import 'dart:convert';

class Pregunta {
  final String id;
  final String tipoCampo;
  final String etiqueta;
  final String? ayuda;
  final String? placeholder;
  final int orden;
  final bool obligatorio;
  bool visible;
  final bool editable;
  final Map<String, dynamic>? config;
  final Map<String, dynamic>? reglasValidacion;
  final List<String>? opciones;

  Pregunta({
    required this.id,
    required this.tipoCampo,
    required this.etiqueta,
    this.ayuda,
    this.placeholder,
    required this.orden,
    required this.obligatorio,
    required this.visible,
    required this.editable,
    this.config,
    this.reglasValidacion,
    this.opciones,
  });

  factory Pregunta.fromJson(Map<String, dynamic> json) {
    print('🔍 Pregunta.fromJson: ${json.keys}');
    print('🔍 json: $json');
    
    List<String>? opcionesList;
    
    // ✅ Buscar opciones en diferentes lugares
    if (json['config'] != null && json['config']['opciones'] != null) {
      final opciones = json['config']['opciones'];
      if (opciones is String) {
        try {
          final List<dynamic> lista = List<dynamic>.from(jsonDecode(opciones));
          opcionesList = lista.map((e) => e.toString()).toList();
        } catch (e) {
          opcionesList = [];
        }
      } else if (opciones is List) {
        opcionesList = opciones.map((e) => e.toString()).toList();
      }
    }
    
    // ✅ Si no hay opciones en config, buscar directamente
    if (opcionesList == null && json['opciones'] != null) {
      if (json['opciones'] is List) {
        opcionesList = (json['opciones'] as List).map((e) => e.toString()).toList();
      }
    }

    return Pregunta(
      id: json['id']?.toString() ?? '',
      tipoCampo: json['tipo'] ?? json['tipo_campo'] ?? 'texto',
      etiqueta: json['etiqueta'] ?? '',
      ayuda: json['ayuda'] ?? json['help'] ?? '',
      placeholder: json['placeholder'] ?? json['hint'] ?? '',
      orden: json['orden'] ?? 0,
      obligatorio: json['requerido'] ?? json['obligatorio'] ?? false,
      visible: json['visible'] ?? true,
      editable: json['editable'] ?? true,
      config: json['config'] != null ? Map<String, dynamic>.from(json['config']) : null,
      reglasValidacion: json['reglas_validacion'] != null ? Map<String, dynamic>.from(json['reglas_validacion']) : null,
      opciones: opcionesList,
    );
  }

  List<String> getOpciones() {
    return opciones ?? [];
  }

  int? get maxLength => config?['maxlength'] ?? config?['maxLength'];
  int? get minLength => config?['minlength'] ?? config?['minLength'];
  int? get maxFotos => config?['max_fotos'] ?? config?['maxFotos'];
  double? get calidad => config?['calidad'] ?? config?['quality'];
  String? get formato => config?['formato'] ?? config?['format'];
}