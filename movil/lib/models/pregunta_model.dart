import 'dart:convert';

class Pregunta {
  final int id;
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
    List<String>? opcionesList;
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

    return Pregunta(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      tipoCampo: json['tipo_campo'] ?? 'texto',
      etiqueta: json['etiqueta'] ?? '',
      ayuda: json['ayuda'],
      placeholder: json['placeholder'],
      orden: json['orden'] ?? 0,
      obligatorio: json['obligatorio'] ?? false,
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

  int? get maxLength => config?['maxlength'];
  int? get minLength => config?['minlength'];
  int? get maxFotos => config?['max_fotos'];
  double? get calidad => config?['calidad'];
  String? get formato => config?['formato'];
}