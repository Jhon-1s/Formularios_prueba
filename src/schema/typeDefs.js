const { gql } = require('apollo-server-express');

const typeDefs = gql`
  # === TIPOS DE AUTENTICACIÓN Y EMPRESA ===
  type Empresa {
    id: ID!
    nombre: String!
    logo_url: String
    activo: Boolean
  }

  type Usuario {
    id: ID!
    empresa_id: ID!
    nombre: String!
    email: String!
    rol: String!
    activo: Boolean
  }

  type AuthPayload {
    token: String!
    usuario: Usuario!
  }

  type FormularioDisponible {
    id: ID!
    titulo: String!
    descripcion: String
    version: String
    estado: String
  }

  type CampoSeccion {
    id: ID!
    seccion_id: ID!
    tipo_campo: String!
    etiqueta: String!
    ayuda: String
    placeholder: String
    orden: Int!
    obligatorio: Boolean!
    visible: Boolean!
    editable: Boolean!
    config: String
    reglas_validacion: String
    dependeDeCampoId: ID
    mostrarSiValorIgualA: String
  }

  type MutacionMovilResponse {
    success: Boolean!
    message: String!
    encabezado_id: ID
  }

  type PDFResponse {
    success: Boolean!
    url: String
    mensaje: String
  }

  # === TIPOS DEL MOTOR DINÁMICO Y GPS ===
  type CampoConfig {
  id: ID!
  tipo: String!        
  etiqueta: String!     
  requerido: Boolean!
  orden: Int!
  opciones: String
  placeholder: String
  ayuda: String
  config: String
  dependeDeCampoId: ID
  mostrarSiValorIgualA: String
 }

  type FormularioEstructura {
  id: ID!
  titulo: String!
  descripcion: String
  empresaId: ID!        
  campos: [CampoConfig!]! 
 }

  type UbicacionGPS {
    latitud: Float!
    longitud: Float!
  }

  type RespuestaCampo {
    campoId: ID!
    pregunta: String
    valor: String          
  }

  type RespuestaDetalle {
    pregunta_id: ID
    valor_texto: String
    valor_numero: Float
    valor_fecha: String
    valor_booleano: Boolean
    pregunta_etiqueta: String
    tipo_campo: String
  }

  type Regla {
    id: ID
    preguntaOrigenIndex: Int
    condicion: String
    valor: String
    accion: String
  }

  # === MÓDULO DE REPORTES / HISTORIAL ===
  type InspeccionReporte {
    id: ID!
    formularioId: ID
    tituloFormulario: String
    usuarioId: ID
    nombreUsuario: String
    fechaCreado: String
    latitud: Float
    longitud: Float
    formulario_id: ID
    formulario_titulo: String
    usuario_nombre_completo: String
    usuario_email: String
    fecha_completado: String
    estado: String
    ubicacion_lat: Float
    ubicacion_lng: Float
    tiempo_respuesta_segundos: Int
    pdf_generado: Boolean

    respuestas: [RespuestaCampo!]
    detalles: [RespuestaDetalle!]
  }

  # === ESTADÍSTICAS DEL DASHBOARD ===
  type FormularioEstadistica {
    activos: Int!
    inactivos: Int!
    total: Int!
    pendientes: Int
    finalizados: Int
  }

  # === QUERIES UNIFICADAS ===
  type Query {
    ping: String!
    perfil: Usuario
    getEmpresas: [Empresa!]!
    getEmpresa(id: ID!): Empresa
    getFormulariosDisponibles: [FormularioDisponible!]!
    getCamposPorSeccion(seccion_id: ID!): [CampoSeccion!]!
    getFormularioPorId(id: ID!, empresaId: ID): FormularioEstructura!
    getInspeccionesPorEmpresa(empresaId: ID): [InspeccionReporte!]!
    getHistorialRespuestas: [InspeccionReporte!]!
    getDetalleRespuesta(id: ID!): InspeccionReporte
    getReglasFormulario(formulario_id: ID!): [Regla!]
    totalInspeccionesPorEmpresa(empresaId: ID): Int!
    obtenerResumenEstatusFormularios(empresaId: ID): FormularioEstadistica!
  }

  # === MUTATIONS UNIFICADAS ===
  type Mutation {
    login(email: String!, password: String!): AuthPayload!
    
    registrarUsuario(
      email: String!
      password: String!
      nombre: String!
      empresaId: Int!
      rol: String
    ): AuthPayload!

    crearEmpresa(nombre: String!, logo_url: String): Empresa!
    
    guardarRespuestaMovil(
      formulario_id: ID!
      usuario_email: String!
      usuario_nombre_completo: String!
      respuestas: [RespuestaMovilInput!]!
    ): MutacionMovilResponse!

    guardarRespuestasFormulario(
      formularioId: String!
      usuarioId: String!
      respuestas: [RespuestaInput!]!
      gps: GPSInput
      archivos: [ArchivoInput]
    ): Boolean!

    crearFormularioConPreguntas(
      titulo: String!
      descripcion: String
      empresaId: ID
      preguntas: [PreguntaInput!]!
    ): FormularioEstructura!

    eliminarFormulario(id: ID!): Boolean!
    cambiarEstadoFormulario(id: ID!, activo: Boolean!): Boolean!
    generarPDF(respuestaId: ID!, empresaId: Int): PDFResponse!
  }

  # === INPUTS DE LA APLICACIÓN ===
  input RespuestaMovilInput {
    pregunta_id: ID!
    valor_texto: String
    valor_numero: Float
    valor_booleano: Boolean
  }

  input UbicacionGPSInput {
    latitud: Float!
    longitud: Float!
  }

  input GPSInput {
    latitud: Float
    longitud: Float
  }

  input RespuestaCampoInput {
    campoId: ID!
    valor: String
  }

  input RespuestaInput {
    campoId: ID!
    valor: String
  }

  input ArchivoInput {
    campoId: ID
    nombre: String
    uri: String
    tipo: String
  }
  
  input ReglaInput {
    preguntaOrigenIndex: Int!
    condicion: String!
    valor: String!
    accion: String!
  }

  input PreguntaInput {
    id: String
    etiqueta: String!
    tipo: String!
    requerido: Boolean!
    orden: Int!
    opciones: String
    dependeDeCampoId: ID
    mostrarSiValorIgualA: String
    regla: ReglaInput
  }
`;

module.exports = typeDefs;