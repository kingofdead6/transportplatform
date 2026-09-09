const asyncHandler = require('express-async-handler');
const Dispute = require('../models/Dispute');
const Trip = require('../models/Trip');

// @route POST /api/trips/:id/disputes
const openDispute = asyncHandler(async (req, res) => {
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }
  const dispute = await Dispute.create({
    tripId: trip._id,
    raisedBy: req.user._id,
    reason: req.body.reason,
    messages: req.body.message
      ? [{ senderId: req.user._id, text: req.body.message }]
      : [],
  });
  trip.disputeId = dispute._id;
  trip.status = 'disputed';
  trip.statusHistory.push({ status: 'disputed', changedBy: req.user._id, note: req.body.reason });
  await trip.save();
  res.status(201).json(dispute);
});

// @route POST /api/disputes/:id/messages
const addMessage = asyncHandler(async (req, res) => {
  const dispute = await Dispute.findById(req.params.id);
  if (!dispute) {
    res.status(404);
    throw new Error('Dispute not found');
  }
  dispute.messages.push({
    senderId: req.user._id,
    text: req.body.text,
    attachments: req.body.attachments || [],
  });
  if (dispute.status === 'open') dispute.status = 'in_review';
  await dispute.save();
  res.status(201).json(dispute);
});

// @route PUT /api/disputes/:id/resolve
const resolveDispute = asyncHandler(async (req, res) => {
  if (req.user.role !== 'admin') {
    res.status(403);
    throw new Error('Admin only');
  }
  const dispute = await Dispute.findById(req.params.id);
  if (!dispute) {
    res.status(404);
    throw new Error('Dispute not found');
  }
  dispute.status = 'resolved';
  dispute.resolution = req.body.resolution;
  dispute.resolvedBy = req.user._id;
  dispute.resolvedAt = new Date();
  await dispute.save();

  if (req.body.newTripStatus) {
    const trip = await Trip.findById(dispute.tripId);
    trip.status = req.body.newTripStatus;
    trip.statusHistory.push({
      status: req.body.newTripStatus,
      changedBy: req.user._id,
      note: 'Dispute resolved',
    });
    await trip.save();
  }

  res.json(dispute);
});

// @route GET /api/disputes
const listDisputes = asyncHandler(async (req, res) => {
  const filter = {};
  if (req.user.role !== 'admin') filter.raisedBy = req.user._id;
  if (req.query.status) filter.status = req.query.status;
  const disputes = await Dispute.find(filter).sort({ createdAt: -1 });
  res.json(disputes);
});

module.exports = { openDispute, addMessage, resolveDispute, listDisputes };
