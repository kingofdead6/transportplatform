const express = require('express');
const {
  recordPayment,
  listInvoices,
  overdueInvoices,
  sendReminder,
} = require('../controllers/invoiceController');
const { protect, allowRoles } = require('../middleware/authMiddleware');

const router = express.Router();
router.use(protect);

router.get('/', listInvoices);
router.get('/overdue', allowRoles('admin'), overdueInvoices);
router.put('/:id/pay', allowRoles('admin'), recordPayment);
router.put('/:id/remind', allowRoles('admin'), sendReminder);

module.exports = router;
