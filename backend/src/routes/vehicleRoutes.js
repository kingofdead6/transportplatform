const express = require('express');
const {
  createVehicle,
  listMyVehicles,
  getVehicle,
  updateVehicle,
  setVehicleStatus,
  addVehicleDocument,
  deleteVehicle,
} = require('../controllers/vehicleController');
const { protect, allowRoles, denyReadOnlyAdmin } = require('../middleware/authMiddleware');
const { makeUploader } = require('../config/cloudinary');

const router = express.Router();
const upload = makeUploader('vehicle-documents');

router.use(protect, allowRoles('carrier', 'admin'), denyReadOnlyAdmin);

router.post('/', createVehicle);
router.get('/mine', listMyVehicles);
router.get('/:id', getVehicle);
router.put('/:id', updateVehicle);
router.put('/:id/status', setVehicleStatus);
router.post('/:id/documents', upload.single('file'), addVehicleDocument);
router.delete('/:id', deleteVehicle);

module.exports = router;
