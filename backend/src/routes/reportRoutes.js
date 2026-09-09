const express = require('express');
const { marginReport, summaryReport } = require('../controllers/reportController');
const { protect, allowRoles } = require('../middleware/authMiddleware');

const router = express.Router();
router.use(protect, allowRoles('admin'));

router.get('/margins', marginReport);
router.get('/summary', summaryReport);

module.exports = router;
