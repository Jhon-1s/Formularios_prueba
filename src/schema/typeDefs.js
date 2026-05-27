const { gql } = require('apollo-server-express');

const typeDefs = gql`
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

  type Query {
    ping: String!
    perfil: Usuario
    getEmpresas: [Empresa!]!
    getEmpresa(id: ID!): Empresa
  }

  type Mutation {
    login(email: String!, password: String!): AuthPayload!
    crearEmpresa(nombre: String!, logo_url: String): Empresa!
  }
`;

module.exports = typeDefs;