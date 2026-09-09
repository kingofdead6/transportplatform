const express = require('express');
const {
  createTrip,
  publishTrip,
  listTrips,
  getTrip,
  submitOffer,
  assignCarrier,
  assignDriver,
  updateTripStatus,
  pingLocation,
  confirmPod,
  reviewTrip,
  reportIncident,
  reassignTrip,
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
const { protect, allowRoles } = require('../middleware/authMiddleware');
const { makeUploader } = require('../config/cloudinary');

const router = express.Router();
const upload = makeUploader('trip-media');

router.use(protect);

router.get('/return-loads', allowRoles('carrier'), getReturnLoads);

router.post('/', allowRoles('shipper', 'admin'), createTrip);
router.get('/', listTrips);
router.get('/:id', getTrip);

router.put('/:id/publish', allowRoles('shipper', 'admin'), publishTrip);
router.post('/:id/offers', allowRoles('carrier'), submitOffer);
router.put('/:id/assign', allowRoles('shipper', 'admin'), assignCarrier);
router.put('/:id/assign-driver', allowRoles('carrier', 'admin'), assignDriver);
router.put('/:id/status', allowRoles('driver', 'carrier', 'admin'), updateTripStatus);
router.post('/:id/ping', allowRoles('driver'), pingLocation);
router.put('/:id/confirm-pod', allowRoles('shipper', 'admin'), confirmPod);
router.post('/:id/review', allowRoles('shipper'), reviewTrip);
router.post('/:id/incidents', allowRoles('driver', 'carrier'), reportIncident);
router.put('/:id/reassign', allowRoles('admin'), reassignTrip);

router.post('/:id/documents/bon-transport', allowRoles('admin'), issueBonTransport);
router.post('/:id/documents/bon-livraison', allowRoles('admin', 'driver'), issueBonLivraison);
router.post('/:id/documents/pod', allowRoles('driver'), upload.array('files', 6), uploadPod);
router.post(
  '/:id/documents/photos',
  allowRoles('shipper', 'driver'),
  upload.array('files', 10),
  uploadGoodsPhotos
);
router.get('/:id/documents', listTripDocuments);

router.post('/:id/invoice', allowRoles('admin'), issueInvoice);
router.post('/:id/disputes', openDispute);

module.exports = router;
