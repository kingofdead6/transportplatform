const express = require('express');
const {
  createVehicle,
  listMyVehicles,
  updateVehicle,
  setVehicleStatus,
  addVehicleDocument,
} = require('../controllers/vehicleController');
const { protect, allowRoles } = require('../middleware/authMiddleware');
const { makeUploader } = require('../config/cloudinary');

const router = express.Router();
const upload = makeUploader('vehicle-documents');

router.use(protect, allowRoles('carrier', 'admin'));

router.post('/', createVehicle);
router.get('/mine', listMyVehicles);
router.put('/:id', updateVehicle);
router.put('/:id/status', setVehicleStatus);
router.post('/:id/documents', upload.single('file'), addVehicleDocument);

module.exports = router;
