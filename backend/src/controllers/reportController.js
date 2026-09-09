const asyncHandler = require('express-async-handler');
const Trip = require('../models/Trip');
const Invoice = require('../models/Invoice');

// @desc Profit margin per trip/client/carrier/corridor (ADM-17)
// @route GET /api/reports/margins
const marginReport = asyncHandler(async (req, res) => {
  if (req.user.role !== 'admin') {
    res.status(403);
    throw new Error('Admin only');
  }
  const { from, to } = req.query;
  const match = { status: { $in: ['invoiced', 'paid', 'closed'] } };
  if (from || to) {
    match.createdAt = {};
    if (from) match.createdAt.$gte = new Date(from);
    if (to) match.createdAt.$lte = new Date(to);
  }

  const trips = await Trip.find(match)
    .populate('shipperId', 'companyName')
    .populate('assignedCarrierId', 'companyName');

  const rows = trips.map((t) => ({
    tripId: t._id,
    reference: t.reference,
    shipper: t.shipperId?.companyName,
    carrier: t.assignedCarrierId?.companyName,
    corridor: `${t.pickup?.wilaya} -> ${t.dropoff?.wilaya}`,
    agreedPrice: t.agreedPrice,
    commission: t.commission?.computedAmount || 0,
    date: t.createdAt,
  }));

  const totals = rows.reduce(
    (acc, r) => {
      acc.totalRevenue += r.agreedPrice || 0;
      acc.totalCommission += r.commission || 0;
      return acc;
    },
    { totalRevenue: 0, totalCommission: 0 }
  );

  res.json({ rows, totals });
});

// @desc Daily/weekly/monthly report exportable to Excel/PDF (ADM-18)
// @route GET /api/reports/summary
const summaryReport = asyncHandler(async (req, res) => {
  if (req.user.role !== 'admin') {
    res.status(403);
    throw new Error('Admin only');
  }
  const { period = 'month' } = req.query;
  const now = new Date();
  let start;
  if (period === 'day') start = new Date(now.setHours(0, 0, 0, 0));
  else if (period === 'week') start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  else start = new Date(now.getFullYear(), now.getMonth(), 1);

  const trips = await Trip.find({ createdAt: { $gte: start } });
  const invoices = await Invoice.find({ createdAt: { $gte: start } });

  const byStatus = {};
  trips.forEach((t) => {
    byStatus[t.status] = (byStatus[t.status] || 0) + 1;
  });

  res.json({
    period,
    since: start,
    totalTrips: trips.length,
    byStatus,
    totalInvoiced: invoices.reduce((s, i) => s + i.totalAmount, 0),
    totalCollected: invoices.reduce((s, i) => s + i.amountPaid, 0),
    totalCommission: trips.reduce((s, t) => s + (t.commission?.computedAmount || 0), 0),
    returnLoadRate:
      trips.length > 0
        ? (trips.filter((t) => t.isReturnLoadMatch).length / trips.length) * 100
        : 0,
  });
});

module.exports = { marginReport, summaryReport };
