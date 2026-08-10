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
  }

  type MutacionMovilResponse {
    success: Boolean!
    message: String!
    encabezado_id: ID
  }

  # === TIPOS DEL MOTOR DINÁMICO Y GPS ===
  type CampoConfig {
    id: ID!
    tipo: String!        
    etiqueta: String!     
    requerido: Boolean!
    orden: Int!
  }

  type FormularioEstructura {
    id: ID!
    titulo: String!
    empresaId: ID!        
    campos: [CampoConfig!]! 
  }

  type UbicacionGPS {
    latitud: Float!
    longitud: Float!
  }

  type RespuestaCampo {
    campoId: ID!
    valor: String          
  }

  # === MÓDULO DE REPORTES / HISTORIAL ===
  type InspeccionReporte {
    id: ID!
    formularioId: ID!
    tituloFormulario: String
    usuarioId: ID!
    nombreUsuario: String
    fechaCreado: String
    latitud: Float
    longitud: Float
    respuestas: [RespuestaCampo!]!
  }

  # === ESTADÍSTICAS DEL DASHBOARD ===
  type FormularioEstadistica {
    activos: Int!
    inactivos: Int!
    total: Int!
  }

  # === QUERIES UNIFICADAS ===
  type Query {
    ping: String!
    perfil: Usuario
    getEmpresas: [Empresa!]!
    getEmpresa(id: ID!): Empresa
    getFormulariosDisponibles: [FormularioDisponible!]!
    getCamposPorSeccion(seccion_id: ID!): [CampoSeccion!]!
    
    # Se hace empresaId opcional (ID) para evitar errores si la app móvil solo envía id
    getFormularioPorId(id: ID!, empresaId: ID): FormularioEstructura!
    getInspeccionesPorEmpresa(empresaId: ID): [InspeccionReporte!]!
    
    # HISTORIAL MÓVIL
    getHistorialRespuestas: [InspeccionReporte!]!

    # QUERIES DASHBOARD
    totalInspeccionesPorEmpresa(empresaId: ID): Int!
    obtenerResumenEstatusFormularios(empresaId: ID): FormularioEstadistica!
  }

  # === MUTATIONS UNIFICADAS ===
  type Mutation {
    login(email: String!, password: String!): AuthPayload!
    crearEmpresa(nombre: String!, logo_url: String): Empresa!
    
    guardarRespuestaMovil(
      formulario_id: ID!,
      usuario_email: String!,
      usuario_nombre_completo: String!,
      respuestas: [RespuestaMovilInput!]!
    ): MutacionMovilResponse!

    # Registro de Respuestas + GPS + Archivos (Compatibilidad con la App Móvil)
    guardarRespuestasFormulario(
      formularioId: ID!
      usuarioId: ID!
      respuestas: [RespuestaInput!]!
      gps: GPSInput
      archivos: [ArchivoInput]
    ): Boolean!
  }

  # === INPUTS QUE SOLICITA LA APP MÓVIL ===
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
`;

module.exports = typeDefs;