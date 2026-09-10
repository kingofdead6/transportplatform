const asyncHandler = require('express-async-handler');
const Document = require('../models/Document');
const Trip = require('../models/Trip');
const { generateBonPdf } = require('../utils/pdfGenerator');

const sameId = (a, b) => a != null && b != null && String(a) === String(b);

/// Trip documents carry POD photos and signed receipts, so they are readable and
/// writable only by the parties on the trip (plus admin). These checks were absent.
function isTripParticipant(trip, user) {
  if (user.role === 'admin') return true;
  return (
    sameId(trip.shipperId, user._id) ||
    sameId(trip.assignedCarrierId, user._id) ||
    sameId(trip.assignedDriverId, user._id)
  );
}

async function loadTripFor(req, res, { requireDriver = false } = {}) {
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }
  if (requireDriver && !sameId(trip.assignedDriverId, req.user._id) && req.user.role !== 'admin') {
    res.status(403);
    throw new Error('Only the assigned driver can upload this document');
  }
  if (!isTripParticipant(trip, req.user)) {
    res.status(403);
    throw new Error('Not authorized for this trip');
  }
  return trip;
}

// @desc System-generated "bon de transport" at assignment time
async function generateBonTransport(trip) {
  const result = await generateBonPdf({
    title: 'BON DE TRANSPORT / وصل النقل',
    refLabel: 'Trajet',
    refValue: trip.reference,
    tripRef: trip.reference,
    lines: [
      `Chargeur: ${trip.shipperId}`,
      `Transporteur: ${trip.assignedCarrierId}`,
      `Départ: ${trip.pickup?.address}, ${trip.pickup?.wilaya}`,
      `Arrivée: ${trip.dropoff?.address}, ${trip.dropoff?.wilaya}`,
      `Marchandise: ${trip.goodsType} — ${trip.weightKg || ''} kg`,
      `Prix convenu: ${trip.agreedPrice} DZD`,
    ],
    publicIdFolder: 'bons-transport',
    publicId: `bt-${trip.reference}`,
  });
  return Document.create({
    tripId: trip._id,
    type: 'bon_transport',
    url: result.secure_url,
    publicId: result.public_id,
  });
}

// @desc System-generated "bon de livraison"
async function generateBonLivraison(trip) {
  const result = await generateBonPdf({
    title: 'BON DE LIVRAISON / وصل التسليم',
    refLabel: 'Trajet',
    refValue: trip.reference,
    tripRef: trip.reference,
    lines: [
      `Livré le: ${new Date().toLocaleString('fr-FR')}`,
      `Destination: ${trip.dropoff?.address}, ${trip.dropoff?.wilaya}`,
    ],
    publicIdFolder: 'bons-livraison',
    publicId: `bl-${trip.reference}`,
  });
  return Document.create({
    tripId: trip._id,
    type: 'bon_livraison',
    url: result.secure_url,
    publicId: result.public_id,
  });
}

// @route POST /api/trips/:id/documents/bon-transport
const issueBonTransport = asyncHandler(async (req, res) => {
  const trip = await loadTripFor(req, res);
  const doc = await generateBonTransport(trip);
  trip.documentsIds.push(doc._id);
  await trip.save();
  res.status(201).json(doc);
});

// @route POST /api/trips/:id/documents/bon-livraison
const issueBonLivraison = asyncHandler(async (req, res) => {
  const trip = await loadTripFor(req, res);
  const doc = await generateBonLivraison(trip);
  trip.documentsIds.push(doc._id);
  await trip.save();
  res.status(201).json(doc);
});

// @desc Driver uploads POD: photos + signature captured on screen (CHA-08)
// @route POST /api/trips/:id/documents/pod
const uploadPod = asyncHandler(async (req, res) => {
  const trip = await loadTripFor(req, res, { requireDriver: true });
  const files = req.files || [];
  if (!files.length) {
    res.status(400);
    throw new Error('At least one photo required');
  }
  const docs = await Promise.all(
    files.map((f) =>
      Document.create({
        tripId: trip._id,
        type: 'pod',
        url: f.path,
        publicId: f.filename,
        signature: {
          signedByName: req.body.signedByName,
          signatureImageUrl: req.body.signatureImageUrl,
          signedAt: new Date(),
        },
      })
    )
  );
  trip.documentsIds.push(...docs.map((d) => d._id));
  await trip.save();
  res.status(201).json(docs);
});

// @desc Upload goods photos (EXP-12, CHA-05)
// @route POST /api/trips/:id/documents/photos
const uploadGoodsPhotos = asyncHandler(async (req, res) => {
  const trip = await loadTripFor(req, res);
  const files = req.files || [];
  if (!files.length) {
    res.status(400);
    throw new Error('At least one photo required');
  }
  const docs = await Promise.all(
    files.map((f) =>
      Document.create({ tripId: trip._id, type: 'goods_photo', url: f.path, publicId: f.filename })
    )
  );
  trip.photos.push(...files.map((f) => ({ url: f.path, publicId: f.filename })));
  trip.documentsIds.push(...docs.map((d) => d._id));
  await trip.save();
  res.status(201).json(docs);
});

// @route GET /api/trips/:id/documents
const listTripDocuments = asyncHandler(async (req, res) => {
  await loadTripFor(req, res);
  const docs = await Document.find({ tripId: req.params.id }).sort({ createdAt: -1 });
  res.json(docs);
});

module.exports = {
  generateBonTransport,
  generateBonLivraison,
  issueBonTransport,
  issueBonLivraison,
  uploadPod,
  uploadGoodsPhotos,
  listTripDocuments,
};
