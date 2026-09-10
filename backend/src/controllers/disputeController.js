const asyncHandler = require('express-async-handler');
const Dispute = require('../models/Dispute');
const Trip = require('../models/Trip');
const { TRIP_STATUSES } = require('../models/Trip');
const { logAction } = require('../utils/audit');
const { notifyUser } = require('./notificationController');

const sameId = (a, b) => a != null && b != null && String(a) === String(b);

/// Everyone attached to a trip may see and take part in its dispute.
function participantsOf(trip) {
  return [trip.shipperId, trip.assignedCarrierId, trip.assignedDriverId].filter(Boolean);
}

function isParticipant(trip, user) {
  if (user.role === 'admin') return true;
  return participantsOf(trip).some((id) => sameId(id, user._id));
}

// @route POST /api/trips/:id/disputes
const openDispute = asyncHandler(async (req, res) => {
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }
  // Was unauthenticated in practice: any user could open a dispute on any trip.
  if (!isParticipant(trip, req.user)) {
    res.status(403);
    throw new Error('Not authorized to open a dispute on this trip');
  }
  if (trip.disputeId) {
    res.status(409);
    throw new Error('A dispute is already open on this trip');
  }
  if (!req.body.reason) {
    res.status(400);
    throw new Error('A reason is required to open a dispute');
  }

  const dispute = await Dispute.create({
    tripId: trip._id,
    raisedBy: req.user._id,
    reason: req.body.reason,
    messages: req.body.message ? [{ senderId: req.user._id, text: req.body.message }] : [],
  });

  trip.disputeId = dispute._id;
  trip.status = 'disputed';
  trip.statusHistory.push({
    status: 'disputed',
    changedBy: req.user._id,
    note: req.body.reason,
  });
  await trip.save();

  for (const participant of participantsOf(trip)) {
    if (!sameId(participant, req.user._id)) {
      await notifyUser(participant, {
        type: 'dispute_update',
        title: 'Litige ouvert',
        body: `Un litige a été ouvert sur le trajet ${trip.reference}`,
        tripId: trip._id,
        isCritical: true,
      });
    }
  }

  await logAction({
    actorId: req.user._id,
    actorRole: req.user.role,
    action: 'dispute_opened',
    tripId: trip._id,
    targetType: 'Dispute',
    targetId: dispute._id,
  });

  res.status(201).json(dispute);
});

// @route GET /api/disputes/:id
const getDispute = asyncHandler(async (req, res) => {
  const dispute = await Dispute.findById(req.params.id)
    .populate('raisedBy', 'companyName fullName phone role')
    .populate('messages.senderId', 'companyName fullName role')
    .populate('tripId', 'reference status pickup dropoff');
  if (!dispute) {
    res.status(404);
    throw new Error('Dispute not found');
  }

  const trip = await Trip.findById(dispute.tripId?._id ?? dispute.tripId);
  if (!trip || !isParticipant(trip, req.user)) {
    res.status(403);
    throw new Error('Not authorized to view this dispute');
  }

  res.json(dispute);
});

// @route POST /api/disputes/:id/messages
const addMessage = asyncHandler(async (req, res) => {
  const dispute = await Dispute.findById(req.params.id);
  if (!dispute) {
    res.status(404);
    throw new Error('Dispute not found');
  }
  if (!req.body.text?.trim()) {
    res.status(400);
    throw new Error('Message text is required');
  }

  const trip = await Trip.findById(dispute.tripId);
  if (!trip || !isParticipant(trip, req.user)) {
    res.status(403);
    throw new Error('Not authorized to post in this dispute');
  }
  if (['resolved', 'closed'].includes(dispute.status)) {
    res.status(400);
    throw new Error('This dispute is closed');
  }

  dispute.messages.push({
    senderId: req.user._id,
    text: req.body.text.trim(),
    attachments: req.body.attachments || [],
  });
  if (dispute.status === 'open') dispute.status = 'in_review';
  await dispute.save();

  for (const participant of participantsOf(trip)) {
    if (!sameId(participant, req.user._id)) {
      await notifyUser(participant, {
        type: 'dispute_update',
        title: 'Nouveau message de litige',
        body: `Nouveau message sur le litige du trajet ${trip.reference}`,
        tripId: trip._id,
      });
    }
  }

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
  if (dispute.status === 'resolved') {
    res.status(409);
    throw new Error('This dispute is already resolved');
  }
  if (!req.body.resolution) {
    res.status(400);
    throw new Error('A resolution is required');
  }

  dispute.status = 'resolved';
  dispute.resolution = req.body.resolution;
  dispute.resolvedBy = req.user._id;
  dispute.resolvedAt = new Date();
  await dispute.save();

  const trip = await Trip.findById(dispute.tripId);
  if (trip) {
    if (req.body.newTripStatus) {
      if (!TRIP_STATUSES.includes(req.body.newTripStatus)) {
        res.status(400);
        throw new Error('Invalid trip status');
      }
      trip.status = req.body.newTripStatus;
      trip.statusHistory.push({
        status: req.body.newTripStatus,
        changedBy: req.user._id,
        note: 'Dispute resolved',
      });
      await trip.save();
    }

    for (const participant of participantsOf(trip)) {
      await notifyUser(participant, {
        type: 'dispute_update',
        title: 'Litige résolu',
        body: `Le litige du trajet ${trip.reference} a été résolu`,
        tripId: trip._id,
        isCritical: true,
      });
    }
  }

  await logAction({
    actorId: req.user._id,
    actorRole: 'admin',
    action: 'dispute_resolved',
    tripId: dispute.tripId,
    targetType: 'Dispute',
    targetId: dispute._id,
    metadata: { resolution: req.body.resolution },
  });

  res.json(dispute);
});

// @route GET /api/disputes
const listDisputes = asyncHandler(async (req, res) => {
  const filter = {};

  if (req.user.role !== 'admin') {
    // A participant sees every dispute on their trips, not only the ones they
    // raised themselves (the previous `raisedBy` filter hid the other side's).
    const trips = await Trip.find({
      $or: [
        { shipperId: req.user._id },
        { assignedCarrierId: req.user._id },
        { assignedDriverId: req.user._id },
      ],
    }).select('_id');
    filter.tripId = { $in: trips.map((t) => t._id) };
  }
  if (req.query.status) filter.status = req.query.status;

  const disputes = await Dispute.find(filter)
    .populate('tripId', 'reference status')
    .populate('raisedBy', 'companyName fullName role')
    .sort({ createdAt: -1 })
    .limit(200);
  res.json(disputes);
});

module.exports = { openDispute, getDispute, addMessage, resolveDispute, listDisputes };
