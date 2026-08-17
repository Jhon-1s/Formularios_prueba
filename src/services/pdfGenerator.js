const PDFDocument = require('pdfkit');

function formatearFecha(fechaRaw) {
  if (!fechaRaw) return new Date().toLocaleDateString('es-MX');
  try {
    const d = new Date(fechaRaw);
    if (isNaN(d.getTime())) return String(fechaRaw);
    const dia = String(d.getDate()).padStart(2, '0');
    const mes = String(d.getMonth() + 1).padStart(2, '0');
    const anio = d.getFullYear();
    const horas = String(d.getHours()).padStart(2, '0');
    const minutos = String(d.getMinutes()).padStart(2, '0');
    return `${dia}/${mes}/${anio} ${horas}:${minutos}`;
  } catch (e) {
    return String(fechaRaw);
  }
}

function generarPDFInspeccion(inspeccionData) {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({ margin: 40, size: 'A4' });
      const buffers = [];

      doc.on('data', buffers.push.bind(buffers));
      doc.on('end', () => resolve(Buffer.concat(buffers)));

      // ENCABEZADO
      doc.rect(40, 40, 515, 65).fill('#1e3a8a');
      doc.fillColor('#ffffff').fontSize(16).font('Helvetica-Bold').text('REPORTES Y AUDITORÍAS S.A.', 55, 52);
      doc.fontSize(8).font('Helvetica').fillColor('#93c5fd').text('SISTEMA INTEGRADO DE GESTIÓN', 55, 72);
      doc.fillColor('#ffffff').fontSize(12).font('Helvetica-Bold').text('REPORTE DE INSPECCIÓN', 350, 55, { align: 'right', width: 190 });
      doc.fontSize(9).fillColor('#4ade80').text(`ESTADO: ${inspeccionData.estado || 'FINALIZADO'}`, 350, 72, { align: 'right', width: 190 });

      // METADATOS
      const startYMeta = 120;
      doc.rect(40, startYMeta, 515, 85).strokeColor('#cbd5e1').lineWidth(1).stroke();
      doc.fillColor('#0f172a').fontSize(10).font('Helvetica-Bold').text('I. DATOS GENERALES', 50, startYMeta + 10);
      
      doc.fontSize(8.5).font('Helvetica');
      doc.fillColor('#475569').text('ID Registro:', 50, startYMeta + 28);
      doc.fillColor('#0f172a').font('Helvetica-Bold').text(`#INSP-${inspeccionData.id}`, 120, startYMeta + 28, { width: 180 });

      doc.fillColor('#475569').font('Helvetica').text('Formulario:', 50, startYMeta + 44);
      doc.fillColor('#0f172a').font('Helvetica-Bold').text(`${inspeccionData.tituloFormulario}`, 120, startYMeta + 44, { width: 180 });

      doc.fillColor('#475569').font('Helvetica').text('Inspector:', 50, startYMeta + 60);
      doc.fillColor('#0f172a').font('Helvetica-Bold').text(`${inspeccionData.nombreUsuario}`, 120, startYMeta + 60, { width: 180 });

      const fechaTexto = formatearFecha(inspeccionData.fechaCreado);
      doc.fillColor('#475569').font('Helvetica').text('Fecha:', 310, startYMeta + 50);
      doc.fillColor('#0f172a').font('Helvetica-Bold').text(fechaTexto, 380, startYMeta + 28, { width: 165 });

      if (inspeccionData.latitud && inspeccionData.longitud) {
        doc.fillColor('#475569').font('Helvetica').text('Ubicación GPS:', 310, startYMeta + 50);
        doc.fillColor('#1d4ed8').font('Helvetica-Bold').text(`📍 ${inspeccionData.latitud}, ${inspeccionData.longitud}`, 380, startYMeta + 50, { width: 165 });
      }

      // PREGUNTAS Y RESPUESTAS
      let currentY = startYMeta + 105;
      doc.fillColor('#0f172a').fontSize(10).font('Helvetica-Bold').text('II. DETALLE DE RESPUESTAS', 40, currentY);
      currentY += 15;

      doc.rect(40, currentY, 515, 20).fill('#f1f5f9');
      doc.fillColor('#334155').fontSize(8).font('Helvetica-Bold');
      doc.text('#', 45, currentY + 6, { width: 25 });
      doc.text('Pregunta / Campo', 75, currentY + 6, { width: 240 });
      doc.text('Respuesta / Valor', 320, currentY + 6, { width: 225 });
      currentY += 20;

      inspeccionData.respuestas.forEach((item, index) => {
        const esImagen = typeof item.valor === 'string' && item.valor.startsWith('data:image/');
        const rowHeight = esImagen ? 70 : 28;

        if (currentY + rowHeight > 730) {
          doc.addPage();
          currentY = 40;
        }

        if (index % 2 === 0) doc.rect(40, currentY, 515, rowHeight).fill('#f8fafc');

        doc.fillColor('#2563eb').fontSize(8.5).font('Helvetica-Bold').text(`${index + 1}`, 45, currentY + 7, { width: 25 });
        doc.fillColor('#1e293b').font('Helvetica-Bold').text(item.pregunta, 75, currentY + 7, { width: 235 });

        if (esImagen) {
          try {
            const base64Data = item.valor.replace(/^data:image\/\w+;base64,/, '');
            doc.image(Buffer.from(base64Data, 'base64'), 320, currentY + 5, { fit: [150, 60] });
          } catch (e) {
            doc.fillColor('#dc2626').text('[ Error de Imagen ]', 320, currentY + 7);
          }
        } else {
          doc.fillColor('#0f172a').font('Helvetica').text(String(item.valor || 'Sin respuesta'), 320, currentY + 7, { width: 225 });
        }

        doc.moveTo(40, currentY + rowHeight).lineTo(555, currentY + rowHeight).strokeColor('#e2e8f0').lineWidth(0.5).stroke();
        currentY += rowHeight;
      });

      doc.end();
    } catch (err) {
      reject(err);
    }
  });
}

module.exports = { generarPDFInspeccion };