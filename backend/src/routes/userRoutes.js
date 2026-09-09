const express = require('express');
const {
  updateProfile,
  uploadDocument,
  addDriver,
  listMyDrivers,
  listUsers,
  getUser,
  setUserStatus,
  documentExpiryAlerts,
} = require('../controllers/userController');
const { protect, allowRoles } = require('../middleware/authMiddleware');
const { makeUploader } = require('../config/cloudinary');

const router = express.Router();
const upload = makeUploader('user-documents');

router.use(protect);

router.put('/me', updateProfile);
router.post('/me/documents', upload.single('file'), uploadDocument);

router.post('/drivers', allowRoles('carrier'), addDriver);
router.get('/drivers', allowRoles('carrier'), listMyDrivers);

router.get('/alerts/documents', allowRoles('admin'), documentExpiryAlerts);
router.get('/', allowRoles('admin'), listUsers);
router.get('/:id', allowRoles('admin'), getUser);
router.put('/:id/status', allowRoles('admin'), setUserStatus);

module.exports = router;
