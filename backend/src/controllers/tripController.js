const asyncHandler = require('express-async-handler');
const Trip = require('../models/Trip');
const User = require('../models/User');
const Settings = require('../models/Settings');
const { canTransition } = require('../utils/tripStateMachine');
const { logAction } = require('../utils/audit');
const { findReturnLoadMatches } = require('../utils/returnLoad');
const { notifyUser } = require('./notificationController');

async function nextTripReference() {
  const year = new Date().getFullYear();
  const count = await Trip.countDocuments({ createdAt: { $gte: new Date(`${year}-01-01`) } });
  return `PP-${year}-${String(count + 1).padStart(6, '0')}`;
}

function pushStatus(trip, status, userId, note) {
  trip.status = status;
  trip.statusHistory.push({ status, changedBy: userId, note });
}

// @desc Create a trip request (EXP-05..14). Shipper or Admin (ADM-02 phone intake).
// @route POST /api/trips
const createTrip = asyncHandler(async (req, res) => {
  const isAdminCreating = req.user.role === 'admin';
  let shipperId = req.user._id;

  if (isAdminCreating) {
    if (!req.body.shipperId) {
      res.status(400);
      throw new Error('shipperId required when admin creates a trip');
    }
    shipperId = req.body.shipperId;
  } else if (req.user.role !== 'shipper') {
    res.status(403);
    throw new Error('Only shippers or admin can create trips');
  }

  const reference = await nextTripReference();

  const trip = await Trip.create({
    reference,
    shipperId,
    createdByAdmin: isAdminCreating,
    createdBy: req.user._id,
    pickup: req.body.pickup,
    dropoff: req.body.dropoff,
    goodsType: req.body.goodsType,
    weightKg: req.body.weightKg,
    volumeM3: req.body.volumeM3,
    packageCount: req.body.packageCount,
    exceptionalDimensions: req.body.exceptionalDimensions,
    vehicleTypeRequired: req.body.vehicleTypeRequired,
    pickupWindowStart: req.body.pickupWindowStart,
    pickupWindowEnd: req.body.pickupWindowEnd,
    requestedDeliveryDate: req.body.requestedDeliveryDate,
    pricingMode: req.body.pricingMode,
    fixedPrice: req.body.fixedPrice,
    specialInstructions: req.body.specialInstructions,
    status: 'draft',
    statusHistory: [{ status: 'draft', changedBy: req.user._id }],
  });

  await logAction({ actorId: req.user._id, actorRole: req.user.role, action: 'trip_created', tripId: trip._id });
  res.status(201).json(trip);
});

// @desc Publish a draft trip so carriers can see/bid on it (EXP-15, TRA-07)
// @route PUT /api/trips/:id/publish
const publishTrip = asyncHandler(async (req, res) => {
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }
  if (String(trip.shipperId) !== String(req.user._id) && req.user.role !== 'admin') {
    res.status(403);
    throw new Error('Not your trip');
  }
  if (!canTransition(trip.status, 'published', req.user.role === 'admin')) {
    res.status(400);
    throw new Error(`Cannot publish from status ${trip.status}`);
  }
  pushStatus(trip, 'published', req.user._id);
  await trip.save();
  res.json(trip);
});

// @desc List trips visible to the current user, filtered by role & query params
// @route GET /api/trips
const listTrips = asyncHandler(async (req, res) => {
  const { status, wilaya, vehicleType, mine } = req.query;
  const filter = {};

  if (req.user.role === 'shipper') {
    filter.shipperId = req.user._id;
  } else if (req.user.role === 'carrier') {
    if (mine === 'true') {
      filter.assignedCarrierId = req.user._id;
    } else {
      filter.status = 'published';
      if (req.user.operatingWilayas?.length) {
        filter.$or = [
          { 'pickup.wilaya': { $in: req.user.operatingWilayas } },
          { 'dropoff.wilaya': { $in: req.user.operatingWilayas } },
        ];
      }
    }
  } else if (req.user.role === 'driver') {
    filter.assignedDriverId = req.user._id;
  }
  // admin: no restriction (ADM-01)

  if (status) filter.status = status;
  if (wilaya) {
    filter.$or = [{ 'pickup.wilaya': wilaya }, { 'dropoff.wilaya': wilaya }];
  }
  if (vehicleType) filter.vehicleTypeRequired = vehicleType;

  const trips = await Trip.find(filter).sort({ createdAt: -1 }).limit(500);
  res.json(trips);
});

// @desc Get a single trip. Offers hidden from other carriers (EXP-15 note / TRA note).
// @route GET /api/trips/:id
const getTrip = asyncHandler(async (req, res) => {
  const trip = await Trip.findById(req.params.id)
    .populate('shipperId', 'companyName fullName phone rating')
    .populate('assignedCarrierId', 'companyName fullName phone rating')
    .populate('assignedDriverId', 'fullName phone')
    .populate('assignedVehicleId');

  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }

  const obj = trip.toObject();

  // Carrier never sees competitor offers, only their own; shipper sees carrier price but not commission breakdown misuse
  if (req.user.role === 'carrier') {
    obj.offers = obj.offers.filter((o) => String(o.carrierId) === String(req.user._id));
  }
  if (req.user.role === 'driver') {
    delete obj.offers;
  }

  res.json(obj);
});

// @desc Carrier submits a price offer (TRA-08)
// @route POST /api/trips/:id/offers
const submitOffer = asyncHandler(async (req, res) => {
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }
  if (trip.pricingMode !== 'bidding') {
    res.status(400);
    throw new Error('This trip uses fixed pricing, not bidding');
  }
  if (!['published', 'offers_received'].includes(trip.status)) {
    res.status(400);
    throw new Error('Trip is not open for offers');
  }

  trip.offers.push({
    carrierId: req.user._id,
    price: req.body.price,
    validUntil: req.body.validUntil,
    vehicleTypeProposed: req.body.vehicleTypeProposed,
    note: req.body.note,
  });
  if (trip.status === 'published') pushStatus(trip, 'offers_received', req.user._id);
  await trip.save();

  await notifyUser(trip.shipperId, {
    type: 'new_offer',
    title: 'Nouvelle offre reçue',
    body: `Nouvelle offre pour le trajet ${trip.reference}`,
    tripId: trip._id,
  });

  res.status(201).json(trip);
});

// @desc Shipper or Admin selects the winning offer / assigns a carrier directly (ADM-05)
// @route PUT /api/trips/:id/assign
const assignCarrier = asyncHandler(async (req, res) => {
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }

  const isOwner = String(trip.shipperId) === String(req.user._id);
  const isAdmin = req.user.role === 'admin';
  if (!isOwner && !isAdmin) {
    res.status(403);
    throw new Error('Not authorized');
  }

  const { offerId, carrierId, agreedPrice, commissionMode, commissionValue } = req.body;

  let finalCarrierId = carrierId;
  let finalPrice = agreedPrice;

  if (offerId) {
    const offer = trip.offers.id(offerId);
    if (!offer) {
      res.status(404);
      throw new Error('Offer not found');
    }
    offer.status = 'accepted';
    trip.offers.forEach((o) => {
      if (String(o._id) !== String(offerId)) o.status = 'rejected';
    });
    finalCarrierId = offer.carrierId;
    finalPrice = offer.price;
    trip.acceptedOfferId = offer._id;
  }

  trip.assignedCarrierId = finalCarrierId;
  trip.agreedPrice = finalPrice;

  const settings = await Settings.findOne({ key: 'global' });
  const mode = commissionMode || 'percent';
  const value = commissionValue ?? settings?.defaultCommissionPercent ?? 10;
  let computedAmount = 0;
  if (mode === 'percent') computedAmount = (finalPrice * value) / 100;
  else if (mode === 'fixed') computedAmount = value;
  trip.commission = { mode, value, computedAmount };

  pushStatus(trip, 'assigned', req.user._id);
  await trip.save();

  await notifyUser(finalCarrierId, {
    type: 'trip_assigned',
    title: 'Trajet attribué',
    body: `Le trajet ${trip.reference} vous a été attribué`,
    tripId: trip._id,
  });

  await logAction({
    actorId: req.user._id,
    actorRole: req.user.role,
    action: 'trip_assigned',
    tripId: trip._id,
    metadata: { carrierId: finalCarrierId, price: finalPrice },
  });

  res.json(trip);
});

// @desc Carrier assigns a driver + vehicle to an assigned trip (TRA-10)
// @route PUT /api/trips/:id/assign-driver
const assignDriver = asyncHandler(async (req, res) => {
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }
  if (String(trip.assignedCarrierId) !== String(req.user._id) && req.user.role !== 'admin') {
    res.status(403);
    throw new Error('Not authorized');
  }
  const { driverId, vehicleId } = req.body;
  trip.assignedDriverId = driverId;
  trip.assignedVehicleId = vehicleId;
  trip.liveTrackingEnabled = false;
  pushStatus(trip, 'driver_assigned', req.user._id);
  await trip.save();

  await notifyUser(driverId, {
    type: 'trip_assigned',
    title: 'Nouvelle mission',
    body: `Mission ${trip.reference}: ${trip.pickup?.wilaya} -> ${trip.dropoff?.wilaya}`,
    tripId: trip._id,
  });

  res.json(trip);
});

const DRIVER_STATUS_MAP = {
  en_route_pickup: 'en_route_pickup',
  loaded: 'loaded',
  en_route_delivery: 'en_route_delivery',
  arrived_delivery: 'arrived_delivery',
  delivered: 'delivered',
};

// @desc Driver updates trip status through the mission screen (CHA-03..08)
// @route PUT /api/trips/:id/status
const updateTripStatus = asyncHandler(async (req, res) => {
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }

  const isDriver = String(trip.assignedDriverId) === String(req.user._id);
  const isAdmin = req.user.role === 'admin';
  const isCarrier = String(trip.assignedCarrierId) === String(req.user._id);
  if (!isDriver && !isAdmin && !isCarrier) {
    res.status(403);
    throw new Error('Not authorized');
  }

  const { status, lat, lng, note } = req.body;
  if (!canTransition(trip.status, status, isAdmin)) {
    res.status(400);
    throw new Error(`Invalid transition from ${trip.status} to ${status}`);
  }

  pushStatus(trip, status, req.user._id, note);
  if (lat && lng) {
    trip.lastKnownLocation = { lat, lng, updatedAt: new Date() };
    trip.statusHistory[trip.statusHistory.length - 1].location = { lat, lng };
  }
  if (status === 'en_route_pickup') trip.liveTrackingEnabled = true;
  if (status === 'delivered') trip.liveTrackingEnabled = false;

  await trip.save();

  await notifyUser(trip.shipperId, {
    type: status === 'delivered' ? 'delivered' : 'trip_assigned',
    title: `Statut mis à jour: ${status}`,
    body: `Trajet ${trip.reference} est maintenant "${status}"`,
    tripId: trip._id,
  });

  // Trigger return-load matching once loaded/delivered near a hub
  if (status === 'en_route_delivery' || status === 'delivered') {
    await findReturnLoadMatches(trip);
  }

  res.json(trip);
});

// @desc Live GPS ping while en route (EXP-16 / ADM-07)
// @route POST /api/trips/:id/ping
const pingLocation = asyncHandler(async (req, res) => {
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }
  const { lat, lng } = req.body;
  trip.lastKnownLocation = { lat, lng, updatedAt: new Date() };
  trip.trackingPings.push({ lat, lng });
  if (trip.trackingPings.length > 500) trip.trackingPings.shift();
  await trip.save();
  res.json({ ok: true });
});

// @desc Shipper confirms receipt of goods (EXP-19)
// @route PUT /api/trips/:id/confirm-pod
const confirmPod = asyncHandler(async (req, res) => {
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }
  if (String(trip.shipperId) !== String(req.user._id) && req.user.role !== 'admin') {
    res.status(403);
    throw new Error('Not authorized');
  }
  if (!canTransition(trip.status, 'pod_confirmed', req.user.role === 'admin')) {
    res.status(400);
    throw new Error(`Cannot confirm POD from status ${trip.status}`);
  }
  pushStatus(trip, 'pod_confirmed', req.user._id);
  await trip.save();
  res.json(trip);
});

// @desc Shipper rates the carrier at end of trip (EXP-20)
// @route POST /api/trips/:id/review
const reviewTrip = asyncHandler(async (req, res) => {
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }
  if (String(trip.shipperId) !== String(req.user._id)) {
    res.status(403);
    throw new Error('Not authorized');
  }
  const { rating, punctuality, goodsCondition, behavior, comment } = req.body;
  trip.review = { rating, punctuality, goodsCondition, behavior, comment, createdAt: new Date() };
  await trip.save();

  if (trip.assignedCarrierId) {
    const carrier = await User.findById(trip.assignedCarrierId);
    if (carrier) {
      const total = carrier.rating * carrier.ratingCount + rating;
      carrier.ratingCount += 1;
      carrier.rating = total / carrier.ratingCount;
      await carrier.save();
    }
  }

  res.json(trip);
});

// @desc Report an incident (CHA-10)
// @route POST /api/trips/:id/incidents
const reportIncident = asyncHandler(async (req, res) => {
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }
  trip.incidentReports.push({
    type: req.body.type,
    note: req.body.note,
    photos: req.body.photos || [],
    reportedBy: req.user._id,
  });
  await trip.save();

  await notifyUser(trip.shipperId, {
    type: 'delay',
    title: 'Incident signalé',
    body: `Incident sur le trajet ${trip.reference}: ${req.body.type}`,
    tripId: trip._id,
    isCritical: true,
  });

  res.status(201).json(trip);
});

// @desc Admin reassigns trip after breakdown/failure (ADM-08)
// @route PUT /api/trips/:id/reassign
const reassignTrip = asyncHandler(async (req, res) => {
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }
  if (req.user.role !== 'admin') {
    res.status(403);
    throw new Error('Only admin can force reassignment');
  }
  const { carrierId, driverId, vehicleId } = req.body;
  if (carrierId) trip.assignedCarrierId = carrierId;
  if (driverId) trip.assignedDriverId = driverId;
  if (vehicleId) trip.assignedVehicleId = vehicleId;
  pushStatus(trip, 'assigned', req.user._id, 'Reassigned by admin');
  await trip.save();
  await logAction({ actorId: req.user._id, actorRole: 'admin', action: 'trip_reassigned', tripId: trip._id });
  res.json(trip);
});

// @desc Return load suggestions for a carrier (TRA-13)
// @route GET /api/trips/return-loads
const getReturnLoads = asyncHandler(async (req, res) => {
  const settings = await Settings.findOne({ key: 'global' });
  const radiusKm = settings?.returnLoadRadiusKm || 100;
  const windowDays = settings?.returnLoadWindowDays || 3;

  const trips = await Trip.find({
    status: 'published',
    'pickup.wilaya': { $in: req.user.operatingWilayas || [] },
  }).limit(50);

  res.json({ radiusKm, windowDays, matches: trips });
});

module.exports = {
  createTrip,
  publishTrip,
  listTrips,
  getTrip,
  submitOffer,
  assignCarrier,
  assignDriver,
  updateTripStatus,
  pingLocation,
  confirmPod,
  reviewTrip,
  reportIncident,
  reassignTrip,
  getReturnLoads,
};
