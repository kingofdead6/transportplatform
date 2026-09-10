const express = require('express');
const {
  createTrip,
  publishTrip,
  listTrips,
  getTrip,
  submitOffer,
  acceptFixedPrice,
  assignCarrier,
  assignDriver,
  updateTripStatus,
  pingLocation,
  confirmPod,
  reviewTrip,
  reportIncident,
  reassignTrip,
  cancelTrip,
  getReturnLoads,
} = require('../controllers/tripController');
const {
  issueBonTransport,
  issueBonLivraison,
  uploadPod,
  uploadGoodsPhotos,
  listTripDocuments,
} = require('../controllers/documentController');
const { issueInvoice } = require('../controllers/invoiceController');
const { openDispute } = require('../controllers/disputeController');
const { protect, allowRoles, denyReadOnlyAdmin } = require('../middleware/authMiddleware');
const { makeUploader } = require('../config/cloudinary');

const router = express.Router();
const upload = makeUploader('trip-media');

router.use(protect);

router.get('/return-loads', allowRoles('carrier'), getReturnLoads);

router.post('/', allowRoles('shipper', 'admin'), denyReadOnlyAdmin, createTrip);
router.get('/', listTrips);
router.get('/:id', getTrip);

router.put('/:id/publish', allowRoles('shipper', 'admin'), denyReadOnlyAdmin, publishTrip);
router.post('/:id/offers', allowRoles('carrier'), submitOffer);
router.put('/:id/accept', allowRoles('carrier'), acceptFixedPrice);
router.put('/:id/assign', allowRoles('shipper', 'admin'), denyReadOnlyAdmin, assignCarrier);
router.put('/:id/assign-driver', allowRoles('carrier', 'admin'), denyReadOnlyAdmin, assignDriver);
router.put('/:id/status', allowRoles('driver', 'carrier', 'admin'), denyReadOnlyAdmin, updateTripStatus);
router.post('/:id/ping', allowRoles('driver'), pingLocation);
router.put('/:id/confirm-pod', allowRoles('shipper', 'admin'), denyReadOnlyAdmin, confirmPod);
router.put('/:id/cancel', allowRoles('shipper', 'admin'), denyReadOnlyAdmin, cancelTrip);
router.post('/:id/review', allowRoles('shipper'), reviewTrip);
router.post('/:id/incidents', allowRoles('driver', 'carrier', 'admin'), reportIncident);
router.put('/:id/reassign', allowRoles('admin'), denyReadOnlyAdmin, reassignTrip);

router.post('/:id/documents/bon-transport', allowRoles('admin'), denyReadOnlyAdmin, issueBonTransport);
router.post('/:id/documents/bon-livraison', allowRoles('admin', 'driver'), issueBonLivraison);
router.post('/:id/documents/pod', allowRoles('driver'), upload.array('files', 6), uploadPod);
router.post(
  '/:id/documents/photos',
  allowRoles('shipper', 'driver'),
  upload.array('files', 10),
  uploadGoodsPhotos
);
router.get('/:id/documents', listTripDocuments);

router.post('/:id/invoice', allowRoles('admin'), denyReadOnlyAdmin, issueInvoice);
router.post('/:id/disputes', openDispute);

module.exports = router;
