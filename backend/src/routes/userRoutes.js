const express = require('express');
const {
  updateProfile,
  changePassword,
  uploadDocument,
  addDriver,
  updateDriver,
  listMyDrivers,
  listCarriers,
  listCarrierDrivers,
  listUsers,
  getUser,
  setUserStatus,
  documentExpiryAlerts,
} = require('../controllers/userController');
const { protect, allowRoles, denyReadOnlyAdmin } = require('../middleware/authMiddleware');
const { makeUploader } = require('../config/cloudinary');

const router = express.Router();
const upload = makeUploader('user-documents');

router.use(protect);

router.put('/me', updateProfile);
router.put('/me/password', changePassword);
router.post('/me/documents', upload.single('file'), uploadDocument);

router.post('/drivers', allowRoles('carrier'), addDriver);
router.get('/drivers', allowRoles('carrier'), listMyDrivers);
router.put('/drivers/:id', allowRoles('carrier'), updateDriver);

// Assignment pickers: admin needs to choose a carrier/driver by name rather than
// pasting a raw ObjectId.
router.get('/carriers', allowRoles('admin'), listCarriers);
router.get('/carriers/:id/drivers', allowRoles('admin'), listCarrierDrivers);

router.get('/alerts/documents', allowRoles('admin'), documentExpiryAlerts);
router.get('/', allowRoles('admin'), listUsers);
router.get('/:id', allowRoles('admin'), getUser);
router.put('/:id/status', allowRoles('admin'), denyReadOnlyAdmin, setUserStatus);

module.exports = router;
