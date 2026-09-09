const PDFDocument = require('pdfkit');
const { cloudinary } = require('../config/cloudinary');

function buildPdfBuffer(drawFn) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ margin: 40, size: 'A4' });
    const chunks = [];
    doc.on('data', (chunk) => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
    drawFn(doc);
    doc.end();
  });
}

function uploadBufferToCloudinary(buffer, folder, publicId) {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder: `prosim-planat/${folder}`, public_id: publicId, resource_type: 'raw', format: 'pdf' },
      (err, result) => (err ? reject(err) : resolve(result))
    );
    stream.end(buffer);
  });
}

function drawHeader(doc, title, refLabel, refValue) {
  doc.rect(0, 0, doc.page.width, 70).fill('#16222A');
  doc.fillColor('#F2A81D').fontSize(18).text('PROSIM PLANAT', 40, 22, { continued: false });
  doc.fillColor('#F1F3F4').fontSize(10).text('Plateforme de transport routier de marchandises', 40, 46);
  doc.fillColor('#16222A').fontSize(16).text(title, 40, 90);
  doc.fontSize(10).fillColor('#3E5261').text(`${refLabel}: ${refValue}`, 40, 112);
  doc.moveDown(2);
  doc.moveTo(40, 135).lineTo(555, 135).strokeColor('#3E5261').stroke();
}

async function generateInvoicePdf(invoice, trip, shipper, carrier) {
  const buffer = await buildPdfBuffer((doc) => {
    drawHeader(doc, 'FACTURE / فاتورة', 'N°', invoice.number);

    doc.moveDown(3);
    doc.fontSize(11).fillColor('#16222A');
    doc.text(`Date: ${new Date(invoice.createdAt || Date.now()).toLocaleDateString('fr-FR')}`);
    doc.moveDown();

    doc.fontSize(12).fillColor('#16222A').text('Client (Chargeur)', { underline: true });
    doc.fontSize(10).fillColor('#3E5261');
    doc.text(`${shipper?.companyName || shipper?.fullName || ''}`);
    doc.text(`NIF: ${shipper?.taxId || '-'}   RC: ${shipper?.tradeRegister || '-'}`);
    doc.text(`${shipper?.address || ''}, ${shipper?.wilaya || ''}`);
    doc.moveDown();

    if (carrier) {
      doc.fontSize(12).fillColor('#16222A').text('Transporteur', { underline: true });
      doc.fontSize(10).fillColor('#3E5261');
      doc.text(`${carrier?.companyName || carrier?.fullName || ''}`);
      doc.moveDown();
    }

    doc.fontSize(12).fillColor('#16222A').text('Détails du transport', { underline: true });
    doc.fontSize(10).fillColor('#3E5261');
    doc.text(`Trajet: ${trip?.pickup?.wilaya || ''} -> ${trip?.dropoff?.wilaya || ''}`);
    doc.text(`Référence trajet: ${trip?.reference || ''}`);
    doc.text(`Type de marchandise: ${trip?.goodsType || ''}`);
    doc.moveDown();

    doc.fontSize(12).fillColor('#16222A').text('Montants', { underline: true });
    doc.fontSize(10).fillColor('#3E5261');
    doc.text(`Montant convenu (HT): ${invoice.agreedAmount?.toLocaleString('fr-FR')} DZD`);
    doc.text(`Commission Prosim Planat: ${invoice.commissionAmount?.toLocaleString('fr-FR')} DZD`);
    doc.text(`TVA (${invoice.vatPercent}%): ${invoice.vatAmount?.toLocaleString('fr-FR')} DZD`);
    doc.fontSize(12).fillColor('#16222A').text(`Total TTC: ${invoice.totalAmount?.toLocaleString('fr-FR')} DZD`, {
      underline: true,
    });
    doc.moveDown();

    doc.fontSize(9).fillColor('#3E5261').text(
      `Facture générée automatiquement par la plateforme Prosim Planat — ${invoice.number}`,
      40,
      760
    );
  });

  const result = await uploadBufferToCloudinary(buffer, 'invoices', invoice.number);
  return result;
}

async function generateBonPdf({ title, refLabel, refValue, tripRef, lines, publicIdFolder, publicId }) {
  const buffer = await buildPdfBuffer((doc) => {
    drawHeader(doc, title, refLabel, refValue);
    doc.moveDown(3);
    doc.fontSize(10).fillColor('#3E5261').text(`Référence trajet: ${tripRef}`);
    doc.moveDown();
    lines.forEach((line) => {
      doc.fontSize(11).fillColor('#16222A').text(line);
      doc.moveDown(0.5);
    });
  });
  const result = await uploadBufferToCloudinary(buffer, publicIdFolder, publicId);
  return result;
}

module.exports = { generateInvoicePdf, generateBonPdf };
