const asyncHandler = require('express-async-handler');
const Invoice = require('../models/Invoice');
const Trip = require('../models/Trip');
const User = require('../models/User');
const Settings = require('../models/Settings');
const { nextInvoiceNumber } = require('../utils/invoiceNumber');
const { generateInvoicePdf } = require('../utils/pdfGenerator');
const { canTransition } = require('../utils/tripStateMachine');
const { logAction } = require('../utils/audit');

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
  if (!canTransition(trip.status, 'invoiced', true)) {
    res.status(400);
    throw new Error(`Cannot invoice from status ${trip.status}`);
  }

  const settings = await Settings.findOne({ key: 'global' });
  const vatPercent = req.body.vatPercent ?? settings?.vatPercent ?? 19;
  const agreedAmount = trip.agreedPrice;
  const commissionAmount = trip.commission?.computedAmount || 0;
  const vatAmount = (agreedAmount * vatPercent) / 100;
  const totalAmount = agreedAmount + vatAmount;

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
  const pdfResult = await generateInvoicePdf(invoice, trip, shipper, carrier);
  invoice.pdfUrl = pdfResult.secure_url;
  invoice.pdfPublicId = pdfResult.public_id;
  await invoice.save();

  trip.invoiceId = invoice._id;
  trip.status = 'invoiced';
  trip.statusHistory.push({ status: 'invoiced', changedBy: req.user._id });
  await trip.save();

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
  const { amount, method, receiptUrl } = req.body;
  invoice.amountPaid += amount;
  invoice.balanceDue = invoice.totalAmount - invoice.amountPaid;
  invoice.paymentMethod = method;
  invoice.paymentDate = new Date();
  invoice.receiptUrl = receiptUrl;
  invoice.status = invoice.balanceDue <= 0 ? 'paid' : 'partially_paid';
  await invoice.save();

  if (invoice.status === 'paid') {
    const trip = await Trip.findById(invoice.tripId);
    if (trip && canTransition(trip.status, 'paid', true)) {
      trip.status = 'paid';
      trip.statusHistory.push({ status: 'paid', changedBy: req.user._id });
      await trip.save();
    }
  }

  res.json(invoice);
});

// @route GET /api/invoices
const listInvoices = asyncHandler(async (req, res) => {
  const filter = {};
  if (req.user.role === 'shipper') filter.shipperId = req.user._id;
  else if (req.user.role === 'carrier') filter.carrierId = req.user._id;

  const { status } = req.query;
  if (status) filter.status = status;

  const invoices = await Invoice.find(filter).sort({ createdAt: -1 });
  res.json(invoices);
});

// @desc Overdue / unpaid invoices with reminders (ADM-16)
// @route GET /api/invoices/overdue
const overdueInvoices = asyncHandler(async (req, res) => {
  const invoices = await Invoice.find({
    status: { $in: ['issued', 'partially_paid'] },
    dueDate: { $lt: new Date() },
  }).populate('shipperId', 'companyName phone');
  res.json(invoices);
});

// @route PUT /api/invoices/:id/remind
const sendReminder = asyncHandler(async (req, res) => {
  const invoice = await Invoice.findById(req.params.id);
  if (!invoice) {
    res.status(404);
    throw new Error('Invoice not found');
  }
  invoice.reminderSentAt.push(new Date());
  await invoice.save();
  res.json(invoice);
});

module.exports = { issueInvoice, recordPayment, listInvoices, overdueInvoices, sendReminder };
