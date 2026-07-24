class Respuesta {
  final int id;
  final int formularioId;
  final String? usuarioNombre;
  final String? usuarioEmail;
  final DateTime fechaCompletado;
  final String estado;
  final double? latitud;
  final double? longitud;
  final int? tiempoSegundos;
  final List<RespuestaDetalle>? detalles;

  Respuesta({
    required this.id,
    required this.formularioId,
    this.usuarioNombre,
    this.usuarioEmail,
    required this.fechaCompletado,
    required this.estado,
    this.latitud,
    this.longitud,
    this.tiempoSegundos,
    this.detalles,
  });

  factory Respuesta.fromJson(Map<String, dynamic> json) {
    return Respuesta(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      formularioId: json['formulario_id'] is String 
          ? int.parse(json['formulario_id']) 
          : json['formulario_id'],
      usuarioNombre: json['usuario_nombre_completo'],
      usuarioEmail: json['usuario_email'],
      fechaCompletado: DateTime.parse(json['fecha_completado'] ?? json['created_at']),
      estado: json['estado'] ?? 'completado',
      latitud: json['ubicacion_lat']?.toDouble(),
      longitud: json['ubicacion_lng']?.toDouble(),
      tiempoSegundos: json['tiempo_respuesta_segundos'],
      detalles: json['detalles'] != null 
          ? (json['detalles'] as List).map((d) => RespuestaDetalle.fromJson(d)).toList()
          : null,
    );
  }

  String get tiempoFormateado {
    if (tiempoSegundos == null) return 'N/A';
    final minutos = tiempoSegundos! ~/ 60;
    final segundos = tiempoSegundos! % 60;
    return '${minutos}m ${segundos}s';
  }

  String get fechaFormateada {
    return '${fechaCompletado.day.toString().padLeft(2, '0')}/${fechaCompletado.month.toString().padLeft(2, '0')}/${fechaCompletado.year} ${fechaCompletado.hour.toString().padLeft(2, '0')}:${fechaCompletado.minute.toString().padLeft(2, '0')}';
  }
}

class RespuestaDetalle {
  final int preguntaId;
  final String? valorTexto;
  final double? valorNumero;
  final String? valorFecha;
  final bool? valorBooleano;
  final String? preguntaEtiqueta;
  final String? tipoCampo;

  RespuestaDetalle({
    required this.preguntaId,
    this.valorTexto,
    this.valorNumero,
    this.valorFecha,
    this.valorBooleano,
    this.preguntaEtiqueta,
    this.tipoCampo,
  });

  factory RespuestaDetalle.fromJson(Map<String, dynamic> json) {
    return RespuestaDetalle(
      preguntaId: json['pregunta_id'] is String 
          ? int.parse(json['pregunta_id']) 
          : json['pregunta_id'],
      valorTexto: json['valor_texto'],
      valorNumero: json['valor_numero']?.toDouble(),
      valorFecha: json['valor_fecha'],
      valorBooleano: json['valor_booleano'],
      preguntaEtiqueta: json['pregunta_etiqueta'],
      tipoCampo: json['tipo_campo'],
    );
  }

  String get valorMostrado {
    if (valorTexto != null && valorTexto!.isNotEmpty) return valorTexto!;
    if (valorNumero != null) return valorNumero!.toString();
    if (valorFecha != null) return valorFecha!;
    if (valorBooleano != null) return valorBooleano! ? 'Sí' : 'No';
    return 'Sin respuesta';
  }
}