const express = require('express');
const { addMessage, resolveDispute, listDisputes } = require('../controllers/disputeController');
const { protect, allowRoles } = require('../middleware/authMiddleware');

const router = express.Router();
router.use(protect);

router.get('/', listDisputes);
router.post('/:id/messages', addMessage);
router.put('/:id/resolve', allowRoles('admin'), resolveDispute);

module.exports = router;
