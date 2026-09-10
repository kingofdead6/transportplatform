const asyncHandler = require('express-async-handler');
const Invoice = require('../models/Invoice');
const Trip = require('../models/Trip');
const User = require('../models/User');
const Settings = require('../models/Settings');
const { nextInvoiceNumber } = require('../utils/invoiceNumber');
const { generateInvoicePdf } = require('../utils/pdfGenerator');
const { canTransition } = require('../utils/tripStateMachine');
const { logAction } = require('../utils/audit');
const { notifyUser } = require('./notificationController');

// @desc Admin issues an invoice for a POD-confirmed trip (ADM-14)
// @route POST /api/trips/:id/invoice
const issueInvoice = asyncHandler(async (req, res) => {
  if (req.user.role !== 'admin') {
    res.status(403);
    throw new Error('Only admin can issue invoices');
  }
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }
  if (trip.invoiceId) {
    res.status(409);
    throw new Error('This trip has already been invoiced');
  }
  if (!canTransition(trip.status, 'invoiced', true)) {
    res.status(400);
    throw new Error(`Cannot invoice from status ${trip.status}`);
  }

  // Without a price there is nothing to invoice — this previously produced an
  // invoice full of NaN totals.
  const agreedAmount = Number(trip.agreedPrice);
  if (!Number.isFinite(agreedAmount) || agreedAmount <= 0) {
    res.status(400);
    throw new Error('This trip has no agreed price to invoice');
  }

  const settings = await Settings.findOne({ key: 'global' });
  const vatPercent = Number(req.body.vatPercent ?? settings?.vatPercent ?? 19);
  if (!Number.isFinite(vatPercent) || vatPercent < 0 || vatPercent > 100) {
    res.status(400);
    throw new Error('vatPercent must be between 0 and 100');
  }

  const commissionAmount = Number(trip.commission?.computedAmount) || 0;
  const vatAmount = Number(((agreedAmount * vatPercent) / 100).toFixed(2));
  const totalAmount = Number((agreedAmount + vatAmount).toFixed(2));

  const number = await nextInvoiceNumber();

  const invoice = await Invoice.create({
    number,
    tripId: trip._id,
    shipperId: trip.shipperId,
    carrierId: trip.assignedCarrierId,
    agreedAmount,
    commissionAmount,
    vatPercent,
    vatAmount,
    totalAmount,
    balanceDue: totalAmount,
    status: 'issued',
    dueDate: req.body.dueDate,
  });

  const shipper = await User.findById(trip.shipperId);
  const carrier = trip.assignedCarrierId ? await User.findById(trip.assignedCarrierId) : null;

  // A PDF upload failure must not lose the invoice that was already created.
  try {
    const pdfResult = await generateInvoicePdf(invoice, trip, shipper, carrier);
    invoice.pdfUrl = pdfResult.secure_url;
    invoice.pdfPublicId = pdfResult.public_id;
    await invoice.save();
  } catch (err) {
    console.error('[invoice] PDF generation failed:', err.message);
  }

  trip.invoiceId = invoice._id;
  trip.status = 'invoiced';
  trip.statusHistory.push({ status: 'invoiced', changedBy: req.user._id });
  await trip.save();

  await notifyUser(trip.shipperId, {
    type: 'payment_due',
    title: 'Facture émise',
    body: `Facture ${number} — ${totalAmount.toFixed(2)} DA pour le trajet ${trip.reference}`,
    tripId: trip._id,
    isCritical: true,
  });

  await logAction({
    actorId: req.user._id,
    actorRole: 'admin',
    action: 'invoice_issued',
    tripId: trip._id,
    metadata: { invoiceNumber: number, totalAmount },
  });

  res.status(201).json(invoice);
});

// @desc Record a payment against an invoice (ADM-15)
// @route PUT /api/invoices/:id/pay
const recordPayment = asyncHandler(async (req, res) => {
  if (req.user.role !== 'admin') {
    res.status(403);
    throw new Error('Only admin can record payments');
  }
  const invoice = await Invoice.findById(req.params.id);
  if (!invoice) {
    res.status(404);
    throw new Error('Invoice not found');
  }
  if (invoice.status === 'paid') {
    res.status(409);
    throw new Error('This invoice is already fully paid');
  }

  const { amount, method, receiptUrl } = req.body;
  const payment = Number(amount);
  // Previously unvalidated: a negative or oversized amount silently corrupted
  // the balance.
  if (!Number.isFinite(payment) || payment <= 0) {
    res.status(400);
    throw new Error('Payment amount must be greater than 0');
  }
  const remaining = Number((invoice.totalAmount - invoice.amountPaid).toFixed(2));
  if (payment > remaining + 0.01) {
    res.status(400);
    throw new Error(`Payment exceeds the outstanding balance of ${remaining.toFixed(2)} DA`);
  }
  if (method && !['cash', 'bank_transfer', 'check', 'cod'].includes(method)) {
    res.status(400);
    throw new Error('Invalid payment method');
  }

  invoice.amountPaid = Number((invoice.amountPaid + payment).toFixed(2));
  invoice.balanceDue = Number((invoice.totalAmount - invoice.amountPaid).toFixed(2));
  if (method) invoice.paymentMethod = method;
  invoice.paymentDate = new Date();
  if (receiptUrl) invoice.receiptUrl = receiptUrl;
  invoice.status = invoice.balanceDue <= 0.01 ? 'paid' : 'partially_paid';
  await invoice.save();

  if (invoice.status === 'paid') {
    const trip = await Trip.findById(invoice.tripId);
    if (trip && canTransition(trip.status, 'paid', true)) {
      trip.status = 'paid';
      trip.statusHistory.push({ status: 'paid', changedBy: req.user._id });
      await trip.save();
    }
  }

  await logAction({
    actorId: req.user._id,
    actorRole: 'admin',
    action: 'payment_recorded',
    tripId: invoice.tripId,
    targetType: 'Invoice',
    targetId: invoice._id,
    metadata: { amount: payment, status: invoice.status },
  });

  res.json(invoice);
});

// @route GET /api/invoices
const listInvoices = asyncHandler(async (req, res) => {
  const filter = {};
  if (req.user.role === 'shipper') filter.shipperId = req.user._id;
  else if (req.user.role === 'carrier') filter.carrierId = req.user._id;
  else if (req.user.role === 'driver') {
    // Drivers have no billing visibility.
    return res.json([]);
  }

  const { status } = req.query;
  if (status) filter.status = status;

  const invoices = await Invoice.find(filter)
    .populate('tripId', 'reference pickup dropoff')
    .sort({ createdAt: -1 })
    .limit(200);
  res.json(invoices);
});

// @route GET /api/invoices/:id
const getInvoice = asyncHandler(async (req, res) => {
  const invoice = await Invoice.findById(req.params.id)
    .populate('tripId', 'reference pickup dropoff status')
    .populate('shipperId', 'companyName fullName phone address taxId')
    .populate('carrierId', 'companyName fullName phone');
  if (!invoice) {
    res.status(404);
    throw new Error('Invoice not found');
  }

  const { role, _id: userId } = req.user;
  const owns =
    (role === 'shipper' && String(invoice.shipperId?._id ?? invoice.shipperId) === String(userId)) ||
    (role === 'carrier' && String(invoice.carrierId?._id ?? invoice.carrierId) === String(userId));
  if (role !== 'admin' && !owns) {
    res.status(403);
    throw new Error('Not authorized to view this invoice');
  }

  res.json(invoice);
});

// @desc Overdue / unpaid invoices with reminders (ADM-16)
// @route GET /api/invoices/overdue
const overdueInvoices = asyncHandler(async (req, res) => {
  const invoices = await Invoice.find({
    status: { $in: ['issued', 'partially_paid'] },
    dueDate: { $lt: new Date() },
  })
    .populate('shipperId', 'companyName phone')
    .populate('tripId', 'reference')
    .sort({ dueDate: 1 });
  res.json(invoices);
});

// @route PUT /api/invoices/:id/remind
const sendReminder = asyncHandler(async (req, res) => {
  const invoice = await Invoice.findById(req.params.id);
  if (!invoice) {
    res.status(404);
    throw new Error('Invoice not found');
  }
  if (invoice.status === 'paid') {
    res.status(400);
    throw new Error('This invoice is already paid');
  }

  invoice.reminderSentAt.push(new Date());
  await invoice.save();

  await notifyUser(invoice.shipperId, {
    type: 'payment_due',
    title: 'Rappel de paiement',
    body: `La facture ${invoice.number} reste due (${invoice.balanceDue.toFixed(2)} DA)`,
    tripId: invoice.tripId,
    isCritical: true,
  });

  res.json(invoice);
});

module.exports = {
  issueInvoice,
  recordPayment,
  listInvoices,
  getInvoice,
  overdueInvoices,
  sendReminder,
};
