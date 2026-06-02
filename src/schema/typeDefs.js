const { gql } = require('apollo-server-express');

const typeDefs = gql`
  # --- TABLAS BASE (SEMANAS 1 - 3) ---
  type Usuario {
    id: ID!
    empresa_id: Int
    nombre: String!
    email: String!
    rol: String!
    activo: Boolean
  }

  type Empresa {
    id: ID!
    nombre: String!
    logo_url: String
  }

  type AuthPayload {
    token: String!
    usuario: Usuario!
  }

  # --- FORMULARIOS ENCABEZADO (SEMANA 4) ---
  type Formulario {
    id: ID!
    titulo: String!
    descripcion: String
    version: Int
    estado: String
  }

  input RespuestaDetalleInput {
    pregunta_id: Int!
    valor_texto: String
    valor_numero: Float
    valor_booleano: Boolean
  }

  type GuardarRespuestaResponse {
    success: Boolean!
    message: String!
    encabezado_id: ID
  }

  # --- MOTOR DINÁMICO ADAPTADO A TU TABLA REAL (SEMANA 5) ---
  type CampoDinamico {
    id: ID!
    seccion_id: Int
    tipo_campo: String!
    etiqueta: String!
    ayuda: String
    placeholder: String
    orden: Int!
    obligatorio: Boolean
    visible: Boolean
    editable: Boolean
    config: String             
    reglas_validacion: String  
  }

  # --- QUERIES ---
  type Query {
    ping: String!
    perfil: Usuario
    getEmpresas: [Empresa!]!
    getEmpresa(id: ID!): Empresa
    getFormulariosDisponibles: [Formulario!]!
    
    # Endpoint definitivo para tu tabla real de la Semana 5
    getCamposPorSeccion(seccion_id: ID!): [CampoDinamico!]!
  }

  # --- MUTATIONS ---
  type Mutation {
    login(email: String!, password: String!): AuthPayload!
    crearEmpresa(nombre: String!, logo_url: String): Empresa!
    guardarRespuestaMovil(
      formulario_id: Int!
      usuario_email: String!
      usuario_nombre_completo: String!
      respuestas: [RespuestaDetalleInput!]!
    ): GuardarRespuestaResponse!
  }
`;

module.exports = typeDefs;