const express = require('express');
const asyncHandler = require('express-async-handler');
const AuditLog = require('../models/AuditLog');
const { protect, allowRoles } = require('../middleware/authMiddleware');

const router = express.Router();
router.use(protect, allowRoles('admin'));

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const filter = {};
    if (req.query.tripId) filter.tripId = req.query.tripId;
    const logs = await AuditLog.find(filter).sort({ createdAt: -1 }).limit(300);
    res.json(logs);
  })
);

module.exports = router;
