const PDFDocument = require('pdfkit');

// Helper para identificar si un string es una imagen en Base64
function esImagenBase64(str) {
  return typeof str === 'string' && str.startsWith('data:image/');
}

// Helper para convertir Base64 a Buffer para PDFKit
function base64ToBuffer(base64Str) {
  const base64Data = base64Str.replace(/^data:image\/\w+;base64,/, '');
  return Buffer.from(base64Data, 'base64');
}

function generarPDFInspeccion(inspeccionData) {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({ margin: 40, size: 'A4' });
      const buffers = [];

      doc.on('data', buffers.push.bind(buffers));
      doc.on('end', () => {
        const pdfData = Buffer.concat(buffers);
        resolve(pdfData);
      });

      // ----------------------------------------------------
      // 1. ENCABEZADO / BRANDING
      // ----------------------------------------------------
      doc.rect(40, 40, 515, 65).fill('#1e3a8a'); // Barra azul corporativa
      
      doc.fillColor('#ffffff')
         .fontSize(16)
         .font('Helvetica-Bold')
         .text('REPORTES Y AUDITORÍAS S.A.', 55, 52);

      doc.fontSize(8)
         .font('Helvetica')
         .fillColor('#93c5fd')
         .text('SISTEMA INTEGRADO DE GESTIÓN Y CONTROL DE CALIDAD', 55, 72);

      doc.fillColor('#ffffff')
         .fontSize(12)
         .font('Helvetica-Bold')
         .text('REPORTE DE INSPECCIÓN', 350, 55, { align: 'right', width: 190 });

      doc.fontSize(9)
         .fillColor('#4ade80')
         .text(`ESTADO: ${inspeccionData.estado || 'FINALIZADO'}`, 350, 72, { align: 'right', width: 190 });

      doc.moveDown(3);

      // ----------------------------------------------------
      // 2. METADATOS GENERALES DE LA INSPECCIÓN
      // ----------------------------------------------------
      const startYMeta = 120;
      doc.rect(40, startYMeta, 515, 75).strokeColor('#cbd5e1').lineWidth(1).stroke();

      doc.fillColor('#0f172a').fontSize(10).font('Helvetica-Bold').text('I. DATOS GENERALES', 50, startYMeta + 10);
      
      doc.fontSize(8.5).font('Helvetica');
      doc.fillColor('#475569').text('ID Registro:', 50, startYMeta + 28);
      doc.fillColor('#0f172a').font('Helvetica-Bold').text(`#INSP-${inspeccionData.id || 'N/A'}`, 120, startYMeta + 28);

      doc.fillColor('#475569').font('Helvetica').text('Formulario:', 50, startYMeta + 42);
      doc.fillColor('#0f172a').font('Helvetica-Bold').text(`${inspeccionData.tituloFormulario || inspeccionData.formulario_titulo || 'Sin Título'}`, 120, startYMeta + 42);

      doc.fillColor('#475569').font('Helvetica').text('Inspector:', 50, startYMeta + 56);
      doc.fillColor('#0f172a').font('Helvetica-Bold').text(`${inspeccionData.nombreUsuario || inspeccionData.usuario_nombre_completo || 'Anónimo'}`, 120, startYMeta + 56);

      // Columna Derecha de Metadatos
      doc.fillColor('#475569').font('Helvetica').text('Fecha:', 310, startYMeta + 28);
      doc.fillColor('#0f172a').font('Helvetica-Bold').text(`${inspeccionData.fechaCreado || inspeccionData.fecha_completado || new Date().toLocaleDateString()}`, 380, startYMeta + 28);

      const lat = inspeccionData.latitud || inspeccionData.ubicacion_lat;
      const lng = inspeccionData.longitud || inspeccionData.ubicacion_lng;
      if (lat && lng) {
        doc.fillColor('#475569').font('Helvetica').text('Ubicación GPS:', 320, startYMeta + 42);
        doc.fillColor('#1d4ed8').font('Helvetica-Bold').text(`📍 ${lat}, ${lng}`, 380, startYMeta + 42);
      }

      // ----------------------------------------------------
      // 3. TABLA DINÁMICA DE PREGUNTAS Y RESPUESTAS
      // ----------------------------------------------------
      let currentY = startYMeta + 95;

      doc.fillColor('#0f172a').fontSize(10).font('Helvetica-Bold').text('II. DETALLE DE RESPUESTAS REGISTRADAS', 40, currentY);
      currentY += 15;

      // Encabezados de Tabla
      doc.rect(40, currentY, 515, 20).fill('#f1f5f9');
      doc.fillColor('#334155').fontSize(8).font('Helvetica-Bold');
      doc.text('#', 45, currentY + 6, { width: 25 });
      doc.text('Pregunta / Campo', 75, currentY + 6, { width: 240 });
      doc.text('Respuesta / Valor', 320, currentY + 6, { width: 225 });

      currentY += 20;

      // Iteración Dinámica sobre el Arreglo de Respuestas
      const listaRespuestas = Array.isArray(inspeccionData.respuestas) ? inspeccionData.respuestas : [];

      if (listaRespuestas.length === 0) {
        doc.fillColor('#64748b').fontSize(9).font('Helvetica-Oblique').text('No hay respuestas registradas para este formulario.', 45, currentY + 10);
        currentY += 30;
      } else {
        listaRespuestas.forEach((item, index) => {
          const valorRespuesta = item.valor !== undefined ? item.valor : (item.respuesta !== undefined ? item.respuesta : '');
          const esImagen = esImagenBase64(valorRespuesta);
          const esBlob = typeof valorRespuesta === 'string' && valorRespuesta.startsWith('blob:');

          // Calculamos la altura necesaria para la fila
          const rowHeight = esImagen ? 70 : 28;

          // Verificación de salto de página antes de renderizar la fila
          if (currentY + rowHeight > 730) {
            doc.addPage();
            currentY = 40;

            // Re-dibujar encabezados de tabla en la nueva página
            doc.rect(40, currentY, 515, 20).fill('#f1f5f9');
            doc.fillColor('#334155').fontSize(8).font('Helvetica-Bold');
            doc.text('#', 45, currentY + 6, { width: 25 });
            doc.text('Pregunta / Campo', 75, currentY + 6, { width: 240 });
            doc.text('Respuesta / Valor', 320, currentY + 6, { width: 225 });
            currentY += 20;
          }

          // Fondo alternado para filas
          if (index % 2 === 0) {
            doc.rect(40, currentY, 515, rowHeight).fill('#f8fafc');
          }

          // Número de pregunta
          doc.fillColor('#2563eb').fontSize(8.5).font('Helvetica-Bold').text(`${index + 1}`, 45, currentY + 7, { width: 25 });
          
          // Etiqueta/Pregunta Real
          const textoPregunta = item.pregunta || item.titulo || `Campo ID: ${item.campoId}`;
          doc.fillColor('#1e293b').font('Helvetica-Bold').text(textoPregunta, 75, currentY + 7, { width: 235 });

          // Renderizado condicional del valor (Imagen vs Texto)
          if (esImagen) {
            try {
              const imgBuffer = base64ToBuffer(valorRespuesta);
              doc.image(imgBuffer, 320, currentY + 5, { fit: [150, 60] });
            } catch (err) {
              doc.fillColor('#dc2626').fontSize(8).font('Helvetica').text('[ Error al renderizar imagen ]', 320, currentY + 7);
            }
          } else if (esBlob) {
            doc.fillColor('#d97706').fontSize(8).font('Helvetica-Oblique').text('[ Imagen local no sincronizada (URL Blob) ]', 320, currentY + 7, { width: 225 });
          } else {
            const textoValor = valorRespuesta !== '' ? String(valorRespuesta) : 'Sin Respuesta';
            doc.fillColor('#0f172a').fontSize(8.5).font('Helvetica').text(textoValor, 320, currentY + 7, { width: 225 });
          }

          // Dibujar línea divisoria tenue
          doc.moveTo(40, currentY + rowHeight).lineTo(555, currentY + rowHeight).strokeColor('#e2e8f0').lineWidth(0.5).stroke();

          currentY += rowHeight;
        });
      }

      // ----------------------------------------------------
      // 4. SECCIÓN DE FIRMAS Y PIE DE PÁGINA
      // ----------------------------------------------------
      if (currentY + 80 > 730) {
        doc.addPage();
        currentY = 50;
      }

      const signatureY = Math.max(currentY + 60, 680);

      doc.moveTo(70, signatureY).lineTo(240, signatureY).strokeColor('#0f172a').lineWidth(1).stroke();
      doc.moveTo(315, signatureY).lineTo(485, signatureY).strokeColor('#0f172a').lineWidth(1).stroke();

      doc.fillColor('#0f172a').fontSize(8.5).font('Helvetica-Bold');
      doc.text('Firma del Inspector', 70, signatureY + 5, { width: 170, align: 'center' });
      doc.text('Firma de Conformidad / Cliente', 315, signatureY + 5, { width: 170, align: 'center' });

      doc.fontSize(7.5).font('Helvetica').fillColor('#64748b');
      doc.text(`${inspeccionData.nombreUsuario || inspeccionData.usuario_nombre_completo || 'Inspector'}`, 70, signatureY + 18, { width: 170, align: 'center' });
      doc.text('Supervisión de Campo', 315, signatureY + 18, { width: 170, align: 'center' });

      doc.end();
    } catch (err) {
      reject(err);
    }
  });
}

module.exports = { generarPDFInspeccion };