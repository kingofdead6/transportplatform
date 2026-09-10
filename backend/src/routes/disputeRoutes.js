const express = require('express');
const {
  getDispute,
  addMessage,
  resolveDispute,
  listDisputes,
} = require('../controllers/disputeController');
const { protect, allowRoles, denyReadOnlyAdmin } = require('../middleware/authMiddleware');

const router = express.Router();
router.use(protect);

router.get('/', listDisputes);
router.get('/:id', getDispute);
router.post('/:id/messages', addMessage);
router.put('/:id/resolve', allowRoles('admin'), denyReadOnlyAdmin, resolveDispute);

module.exports = router;
