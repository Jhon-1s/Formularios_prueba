require('dotenv').config();
const { ApolloServer } = require('apollo-server');
const jwt = require('jsonwebtoken');
const typeDefs = require('./schema/typeDefs');
const resolvers = require('./resolvers');

const server = new ApolloServer({
  typeDefs,
  resolvers,
  //Extrae y verifica el JWT en cada petición HTTP
  context: ({ req }) => {
    const authHeader = req.headers.authorization || '';
    
    // El estándar de la industria dicta recibir: "Bearer <TOKEN_AQUI>"
    if (authHeader.startsWith('Bearer ')) {
      const token = authHeader.replace('Bearer ', '');
      try {
        // Validamos el token con nuestra firma secreta
        const usuarioDecodificado = jwt.verify(token, process.env.JWT_SECRET);
        
        // Inyectamos el usuario decodificado al contexto global
        return { usuario: usuarioDecodificado };
      } catch (error) {
        console.log('⚠️ Intento de acceso con un Token inválido o expirado.');
      }
    }
    
    // Si no hay token o es erróneo, el contexto pasa al resolver como nulo
    return { usuario: null };
  },
  formatError: (error) => {
    console.error('❌ Error en Servidor:', error.message);
    return error;
  },
});

const PORT = process.env.PORT || 4000;
server.listen({ port: PORT }).then(({ url }) => {
  console.log(`🚀 Servidor GraphQL de Estadía listo en: ${url}`);
});