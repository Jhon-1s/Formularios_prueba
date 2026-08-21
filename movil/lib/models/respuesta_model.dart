class Respuesta {
  final String id;
  final String formularioId;
  final String? formularioTitulo;
  final String? usuarioNombre;
  final String? usuarioEmail;
  final DateTime fechaCompletado;
  final String estado;
  final double? latitud;
  final double? longitud;
  final int? tiempoSegundos;
  final bool? pdfGenerado;
  final List<RespuestaDetalle>? detalles;

  Respuesta({
    required this.id,
    required this.formularioId,
    this.formularioTitulo,
    this.usuarioNombre,
    this.usuarioEmail,
    required this.fechaCompletado,
    required this.estado,
    this.latitud,
    this.longitud,
    this.tiempoSegundos,
    this.pdfGenerado,
    this.detalles,
  });

  factory Respuesta.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    
    List<RespuestaDetalle>? detallesList;
    if (json['detalles'] != null) {
      try {
        detallesList = (json['detalles'] as List)
            .map((d) => RespuestaDetalle.fromJson(d))
            .toList();
      } catch (e) {
        detallesList = [];
      }
    }

    DateTime fecha;
    try {
      fecha = DateTime.parse(json['fecha_completado'] ?? json['created_at'] ?? DateTime.now().toIso8601String());
    } catch (e) {
      fecha = DateTime.now();
    }

    return Respuesta(
      id: id,
      formularioId: json['formulario_id']?.toString() ?? '',
      formularioTitulo: json['formulario_titulo'],
      usuarioNombre: json['usuario_nombre_completo'],
      usuarioEmail: json['usuario_email'],
      fechaCompletado: fecha,
      estado: json['estado']?.toString().toLowerCase() ?? 'completado',
      latitud: json['ubicacion_lat']?.toDouble(),
      longitud: json['ubicacion_lng']?.toDouble(),
      tiempoSegundos: json['tiempo_respuesta_segundos'],
      pdfGenerado: json['pdf_generado'] == true || json['pdf_generado'] == 1,
      detalles: detallesList,
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

  bool get tieneDetalles => detalles != null && detalles!.isNotEmpty;
  int get totalDetalles => detalles?.length ?? 0;
}

class RespuestaDetalle {
  final String preguntaId;
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
      preguntaId: json['pregunta_id']?.toString() ?? '',
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