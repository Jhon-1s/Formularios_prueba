const { gql } = require('apollo-server-express');

const typeDefs = gql`
  # --- SEMANA 1, 2 Y 3 (Autenticación y Empresas) ---
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

  # --- NUEVOS TIPOS: SEMANA 4 (Sincronización de Formularios) ---
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

  # --- QUERIES ---
  type Query {
    ping: String!
    perfil: Usuario
    getEmpresas: [Empresa!]!
    getEmpresa(id: ID!): Empresa
    
    # Endpoint Semana 4: Flutter descarga la lista de formularios
    getFormulariosDisponibles: [Formulario!]!
  }

  # --- MUTATIONS ---
  type Mutation {
    login(email: String!, password: String!): AuthPayload!
    crearEmpresa(nombre: String!, logo_url: String): Empresa!
    
    # Endpoint Semana 4: Flutter envía las respuestas capturadas
    guardarRespuestaMovil(
      formulario_id: Int!
      usuario_email: String!
      usuario_nombre_completo: String!
      respuestas: [RespuestaDetalleInput!]!
    ): GuardarRespuestaResponse!
  }
`;

module.exports = typeDefs;