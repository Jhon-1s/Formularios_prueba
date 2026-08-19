class ReglaCondicional {
  final int id;
  final String preguntaOrigenId;
  final String preguntaDestinoId;
  final String condicionOperador;
  final String? valorEsperado;
  final String accion;
  final bool activo;

  ReglaCondicional({
    required this.id,
    required this.preguntaOrigenId,
    required this.preguntaDestinoId,
    required this.condicionOperador,
    this.valorEsperado,
    required this.accion,
    required this.activo,
  });

  factory ReglaCondicional.fromJson(Map<String, dynamic> json) {
    return ReglaCondicional(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      preguntaOrigenId: json['preguntaOrigenId']?.toString() ?? '',
      preguntaDestinoId: json['preguntaDestinoId']?.toString() ?? '',
      condicionOperador: json['condicionOperador'] ?? 'igual',
      valorEsperado: json['valorEsperado'],
      accion: json['accion'] ?? 'mostrar',
      activo: json['activo'] ?? true,
    );
  }

  bool evaluar(dynamic valor) {
    if (!activo) return false;
    
    final valorStr = valor?.toString().toLowerCase() ?? '';
    final esperadoStr = valorEsperado?.toLowerCase() ?? '';

    switch (condicionOperador.toLowerCase()) {
      case 'igual':
        return valorStr == esperadoStr;
      case 'diferente':
        return valorStr != esperadoStr;
      case 'contiene':
        return valorStr.contains(esperadoStr);
      case 'no_contiene':
        return !valorStr.contains(esperadoStr);
      case 'vacio':
        return valorStr.isEmpty || valor == null;
      case 'no_vacio':
        return valorStr.isNotEmpty && valor != null;
      default:
        return false;
    }
  }
}