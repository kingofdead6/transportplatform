const express = require('express');
const {
  recordPayment,
  listInvoices,
  getInvoice,
  overdueInvoices,
  sendReminder,
} = require('../controllers/invoiceController');
const { protect, allowRoles, denyReadOnlyAdmin } = require('../middleware/authMiddleware');

const router = express.Router();
router.use(protect);

router.get('/', listInvoices);
router.get('/overdue', allowRoles('admin'), overdueInvoices);
router.get('/:id', getInvoice);
router.put('/:id/pay', allowRoles('admin'), denyReadOnlyAdmin, recordPayment);
router.put('/:id/remind', allowRoles('admin'), denyReadOnlyAdmin, sendReminder);

module.exports = router;
