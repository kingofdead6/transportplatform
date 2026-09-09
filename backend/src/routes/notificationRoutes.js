const express = require('express');
const { listMyNotifications, markRead, markAllRead } = require('../controllers/notificationController');
const { protect } = require('../middleware/authMiddleware');

const router = express.Router();
router.use(protect);

router.get('/', listMyNotifications);
router.put('/:id/read', markRead);
router.put('/read-all', markAllRead);

module.exports = router;
