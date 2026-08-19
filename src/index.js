require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const uploadRoutes = require('./routes/upload');
const { ApolloServer } = require('apollo-server-express');
const jwt = require('jsonwebtoken');
const typeDefs = require('./schema/typeDefs');
const resolvers = require('./resolvers');
const pool = require('./database/db');
const { generarPDFInspeccion } = require('./services/pdfService');

// Helper para buscar los textos reales de las preguntas en la base de datos
const construirMapaPreguntas = async (formularioIds) => {
  const idsUnicos = [...new Set((formularioIds || []).filter(Boolean))];
  if (idsUnicos.length === 0) return {};

  const [preguntas] = await pool.query(
    `SELECT s.formulario_id, p.id AS pregunta_id, p.texto 
     FROM pregunta p
     INNER JOIN seccion s ON p.seccion_id = s.id
     WHERE s.formulario_id IN (?)`,
    [idsUnicos]
  );

  const mapa = {};
  preguntas.forEach(p => {
    const fId = String(p.formulario_id);
    if (!mapa[fId]) mapa[fId] = {};
    mapa[fId][String(p.pregunta_id)] = p.texto;
  });

  return mapa;
};

async function iniciarServidor() {
  const app = express();

  // Configuración de CORS
  app.use(cors({
    origin: '*',
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
  }));
  app.use('/', uploadRoutes);
  app.use('/uploads', express.static(path.join(__dirname, '../uploads')));
 
  // ===================================================
  // 📄 ENDPOINT REST PARA GENERAR Y DESCARGAR EL PDF
  // ===================================================
  app.get('/api/inspecciones/:id/pdf', async (req, res) => {
    try {
      const { id } = req.params;

      // 1. Obtenemos la inspección e incluimos r.formulario_id
      const [rows] = await pool.query(
        `SELECT 
           r.id, 
           r.formulario_id AS formularioId, 
           f.titulo AS tituloFormulario, 
           u.nombre AS nombreUsuario, 
           r.creado_en AS fechaCreado, 
           r.latitud, 
           r.longitud, 
           r.datos
         FROM respuesta r
         JOIN formulario f ON r.formulario_id = f.id
         JOIN usuario u ON r.usuario_id = u.id
         WHERE r.id = ?`,
        [id]
      );

      if (rows.length === 0) {
        return res.status(404).json({ error: 'Inspección no encontrada' });
      }

      const inspeccion = rows[0];

      // 2. Traemos el mapa de preguntas del formulario
      const mapaPreguntasGlobal = await construirMapaPreguntas([inspeccion.formularioId]);
      const mapaForm = mapaPreguntasGlobal[String(inspeccion.formularioId)] || {};

      // 3. Leemos el JSON de respuestas de la BD
      let rawDatos = typeof inspeccion.datos === 'string' 
        ? JSON.parse(inspeccion.datos) 
        : (inspeccion.datos || {});
      
      let listaRespuestas = Array.isArray(rawDatos) 
        ? rawDatos 
        : (rawDatos.respuestas || []);

      // 4. Mapeamos cada respuesta asignándole el texto real de la pregunta
      const respuestasEnriquecidas = listaRespuestas.map(item => {
        const cId = String(item.campoId || item.preguntaId || item.id || '');
        return {
          ...item,
          campoId: cId,
          pregunta: item.pregunta || mapaForm[cId] || (cId ? `Pregunta (${cId.substring(0, 8)})` : 'Sin título'),
          valor: item.valor !== undefined ? item.valor : (item.respuesta !== undefined ? item.respuesta : '')
        };
      });

      // 5. Preparamos el objeto final para el motor PDF
      const dataParaPDF = {
        ...inspeccion,
        respuestas: respuestasEnriquecidas
      };

      const pdfBuffer = await generarPDFInspeccion(dataParaPDF);

      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `inline; filename=inspeccion_${id}.pdf`);
      res.send(pdfBuffer);

    } catch (error) {
      console.error('❌ Error generando PDF:', error);
      res.status(500).json({ error: 'Error interno al generar el PDF' });
    }
  });

  // ===================================================
  // 🚀 CONFIGURACIÓN Y MONTAJE DE APOLLO GRAPHQL
  // ===================================================
  const server = new ApolloServer({
    typeDefs,
    resolvers,
    context: ({ req }) => {
      const authHeader = req.headers.authorization || '';
      
      if (authHeader.startsWith('Bearer ')) {
        const token = authHeader.replace('Bearer ', '');
        try {
          const usuarioDecodificado = jwt.verify(token, process.env.JWT_SECRET || 'clave_secreta_por_defecto');
          return { usuario: usuarioDecodificado };
        } catch (error) {
          console.log('⚠️ Token inválido o expirado.');
        }
      }
      return { usuario: null };
    },
    formatError: (error) => {
      console.error('❌ Error en Servidor:', error.message);
      return error;
    },
  });

  await server.start();
  server.applyMiddleware({ app, path: '/' });

  const PORT = process.env.PORT || 4000;

  app.listen(PORT, () => {
    console.log(`🚀 Servidor Backend corriendo en: http://localhost:${PORT}`);
    console.log(`📄 Endpoint de PDF disponible en: http://localhost:${PORT}/api/inspecciones/:id/pdf`);
  });
}

iniciarServidor();