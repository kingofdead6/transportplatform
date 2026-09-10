const asyncHandler = require('express-async-handler');
const Trip = require('../models/Trip');
const User = require('../models/User');
const Vehicle = require('../models/Vehicle');
const Settings = require('../models/Settings');
const Counter = require('../models/Counter');
const { canTransition } = require('../utils/tripStateMachine');
const { logAction } = require('../utils/audit');
const { findReturnLoadMatches, haversineKm } = require('../utils/returnLoad');
const { notifyUser } = require('./notificationController');

// Atomic per-year counter. countDocuments() raced under concurrent creation and
// produced duplicate references, which the unique index then rejected.
async function nextTripReference() {
  const year = new Date().getFullYear();
  const counter = await Counter.findOneAndUpdate(
    { key: `trip-${year}` },
    { $inc: { seq: 1 } },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );
  return `PP-${year}-${String(counter.seq).padStart(6, '0')}`;
}

function pushStatus(trip, status, userId, note) {
  trip.status = status;
  trip.statusHistory.push({ status, changedBy: userId, note });
}

const isSameId = (a, b) => a != null && b != null && String(a._id ?? a) === String(b._id ?? b);

// Shared commission computation so assignment and direct acceptance agree.
async function computeCommission({ mode, value, price }) {
  const settings = await Settings.findOne({ key: 'global' });
  const finalMode = mode || 'percent';
  const finalValue = value ?? settings?.defaultCommissionPercent ?? 10;
  let computedAmount = 0;
  if (finalMode === 'percent') computedAmount = (price * finalValue) / 100;
  else if (finalMode === 'fixed') computedAmount = finalValue;
  return { mode: finalMode, value: finalValue, computedAmount };
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
    const shipper = await User.findById(req.body.shipperId);
    if (!shipper || shipper.role !== 'shipper') {
      res.status(400);
      throw new Error('shipperId does not refer to a valid shipper');
    }
    shipperId = shipper._id;
  } else if (req.user.role !== 'shipper') {
    res.status(403);
    throw new Error('Only shippers or admin can create trips');
  }

  const { pricingMode, fixedPrice } = req.body;
  if (pricingMode === 'fixed' && !(Number(fixedPrice) > 0)) {
    res.status(400);
    throw new Error('A fixed-price trip requires a fixedPrice greater than 0');
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
    pricingMode,
    fixedPrice,
    specialInstructions: req.body.specialInstructions,
    status: 'draft',
    statusHistory: [{ status: 'draft', changedBy: req.user._id }],
  });

  await logAction({
    actorId: req.user._id,
    actorRole: req.user.role,
    action: 'trip_created',
    tripId: trip._id,
  });
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
  if (!isSameId(trip.shipperId, req.user._id) && req.user.role !== 'admin') {
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
  const page = Math.max(1, Number(req.query.page) || 1);
  const limit = Math.min(200, Math.max(1, Number(req.query.limit) || 100));

  const filter = {};
  // Collected separately so role scoping and query filters cannot clobber each
  // other's $or — they previously shared one key, silently widening visibility.
  const andClauses = [];

  if (req.user.role === 'shipper') {
    filter.shipperId = req.user._id;
    if (status) filter.status = status;
  } else if (req.user.role === 'carrier') {
    if (mine === 'true') {
      filter.assignedCarrierId = req.user._id;
      if (status) filter.status = status;
    } else {
      // Marketplace: only open loads, never another carrier's assigned work,
      // regardless of what ?status= asks for.
      filter.status = 'published';
      filter.assignedCarrierId = { $exists: false };
      if (req.user.operatingWilayas?.length) {
        andClauses.push({
          $or: [
            { 'pickup.wilaya': { $in: req.user.operatingWilayas } },
            { 'dropoff.wilaya': { $in: req.user.operatingWilayas } },
          ],
        });
      }
    }
  } else if (req.user.role === 'driver') {
    filter.assignedDriverId = req.user._id;
    if (status) filter.status = status;
  } else {
    // admin: no restriction (ADM-01)
    if (status) filter.status = status;
  }

  if (wilaya) {
    andClauses.push({ $or: [{ 'pickup.wilaya': wilaya }, { 'dropoff.wilaya': wilaya }] });
  }
  if (vehicleType) filter.vehicleTypeRequired = vehicleType;
  if (andClauses.length) filter.$and = andClauses;

  const trips = await Trip.find(filter)
    .populate('shipperId', 'companyName fullName phone rating')
    .populate('assignedCarrierId', 'companyName fullName phone rating')
    .populate('assignedDriverId', 'fullName phone')
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit);

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

  const { role, _id: userId } = req.user;
  const obj = trip.toObject();

  // A trip is only visible to the people involved in it (plus admin, plus any
  // carrier while it is still an open marketplace listing).
  if (role === 'shipper' && !isSameId(trip.shipperId, userId)) {
    res.status(403);
    throw new Error('Not authorized to view this trip');
  }
  if (role === 'driver' && !isSameId(trip.assignedDriverId, userId)) {
    res.status(403);
    throw new Error('Not authorized to view this trip');
  }
  if (role === 'carrier') {
    const isAssigned = isSameId(trip.assignedCarrierId, userId);
    const isOpenListing =
      ['published', 'offers_received'].includes(trip.status) && !trip.assignedCarrierId;
    if (!isAssigned && !isOpenListing) {
      res.status(403);
      throw new Error('Not authorized to view this trip');
    }
    // Carrier never sees competitor offers, only their own.
    obj.offers = (obj.offers || []).filter((o) => isSameId(o.carrierId, userId));
  }
  if (role === 'driver') {
    delete obj.offers;
    delete obj.commission;
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
  if (!['published', 'offers_received'].includes(trip.status) || trip.assignedCarrierId) {
    res.status(400);
    throw new Error('Trip is not open for offers');
  }
  if (req.user.status !== 'active') {
    res.status(403);
    throw new Error('Your account must be approved before bidding');
  }

  const price = Number(req.body.price);
  if (!(price > 0)) {
    res.status(400);
    throw new Error('A valid offer price is required');
  }
  if (trip.offers.some((o) => isSameId(o.carrierId, req.user._id) && o.status === 'pending')) {
    res.status(409);
    throw new Error('You already have a pending offer on this trip');
  }

  trip.offers.push({
    carrierId: req.user._id,
    price,
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

  // Echo back only this carrier's own offers.
  const obj = trip.toObject();
  obj.offers = obj.offers.filter((o) => isSameId(o.carrierId, req.user._id));
  res.status(201).json(obj);
});

// @desc Carrier takes a fixed-price load directly, without a bidding round (TRA-09).
// @route PUT /api/trips/:id/accept
const acceptFixedPrice = asyncHandler(async (req, res) => {
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }
  if (trip.pricingMode !== 'fixed') {
    res.status(400);
    throw new Error('This trip is open to bidding, submit an offer instead');
  }
  if (!['published', 'offers_received'].includes(trip.status) || trip.assignedCarrierId) {
    res.status(409);
    throw new Error('This load is no longer available');
  }
  if (req.user.status !== 'active') {
    res.status(403);
    throw new Error('Your account must be approved before taking loads');
  }

  const commission = await computeCommission({ price: trip.fixedPrice });

  // Conditional update: only applies while the trip is still unassigned, so two
  // carriers accepting at the same moment cannot both win the load.
  const claimed = await Trip.findOneAndUpdate(
    {
      _id: trip._id,
      assignedCarrierId: { $exists: false },
      status: { $in: ['published', 'offers_received'] },
    },
    {
      $set: {
        assignedCarrierId: req.user._id,
        agreedPrice: trip.fixedPrice,
        commission,
        status: 'assigned',
      },
      $push: {
        statusHistory: {
          status: 'assigned',
          changedBy: req.user._id,
          note: 'Fixed-price load accepted by carrier',
        },
      },
    },
    { new: true }
  );

  if (!claimed) {
    res.status(409);
    throw new Error('This load has already been taken');
  }

  await notifyUser(claimed.shipperId, {
    type: 'trip_assigned',
    title: 'Trajet attribué',
    body: `${req.user.companyName || req.user.fullName || 'Un transporteur'} a accepté le trajet ${claimed.reference}`,
    tripId: claimed._id,
  });

  await logAction({
    actorId: req.user._id,
    actorRole: 'carrier',
    action: 'trip_accepted_fixed_price',
    tripId: claimed._id,
    metadata: { price: claimed.agreedPrice },
  });

  res.json(claimed);
});

// @desc Shipper or Admin selects the winning offer / assigns a carrier directly (ADM-05)
// @route PUT /api/trips/:id/assign
const assignCarrier = asyncHandler(async (req, res) => {
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }

  const isOwner = isSameId(trip.shipperId, req.user._id);
  const isAdmin = req.user.role === 'admin';
  if (!isOwner && !isAdmin) {
    res.status(403);
    throw new Error('Not authorized');
  }
  if (!canTransition(trip.status, 'assigned', isAdmin)) {
    res.status(400);
    throw new Error(`Cannot assign a trip in status ${trip.status}`);
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
      if (!isSameId(o._id, offerId)) o.status = 'rejected';
    });
    finalCarrierId = offer.carrierId;
    finalPrice = offer.price;
    trip.acceptedOfferId = offer._id;
  } else {
    if (!finalCarrierId) {
      res.status(400);
      throw new Error('Either offerId or carrierId is required');
    }
    if (!(Number(finalPrice) > 0)) {
      res.status(400);
      throw new Error('A valid agreedPrice is required for a direct assignment');
    }
  }

  const carrier = await User.findById(finalCarrierId);
  if (!carrier || carrier.role !== 'carrier') {
    res.status(400);
    throw new Error('Assigned user is not a carrier');
  }
  if (carrier.status !== 'active') {
    res.status(400);
    throw new Error('Cannot assign a trip to an unapproved or blocked carrier');
  }

  trip.assignedCarrierId = finalCarrierId;
  trip.agreedPrice = finalPrice;
  trip.commission = await computeCommission({
    mode: commissionMode,
    value: commissionValue,
    price: finalPrice,
  });

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
  const isAdmin = req.user.role === 'admin';
  if (!isSameId(trip.assignedCarrierId, req.user._id) && !isAdmin) {
    res.status(403);
    throw new Error('Not authorized');
  }
  if (!canTransition(trip.status, 'driver_assigned', isAdmin)) {
    res.status(400);
    throw new Error(`Cannot assign a driver from status ${trip.status}`);
  }

  const { driverId, vehicleId } = req.body;
  if (!driverId) {
    res.status(400);
    throw new Error('driverId is required');
  }

  // The driver and vehicle must belong to the carrier running this trip —
  // otherwise a carrier could assign another company's staff and vehicles.
  const ownerId = trip.assignedCarrierId;
  const driver = await User.findById(driverId);
  if (!driver || driver.role !== 'driver') {
    res.status(400);
    throw new Error('Selected user is not a driver');
  }
  if (!isSameId(driver.carrierId, ownerId)) {
    res.status(403);
    throw new Error('This driver does not belong to the assigned carrier');
  }
  if (driver.status !== 'active') {
    res.status(400);
    throw new Error('This driver account is not active');
  }

  if (vehicleId) {
    const vehicle = await Vehicle.findById(vehicleId);
    if (!vehicle) {
      res.status(404);
      throw new Error('Vehicle not found');
    }
    if (!isSameId(vehicle.carrierId, ownerId)) {
      res.status(403);
      throw new Error('This vehicle does not belong to the assigned carrier');
    }
    trip.assignedVehicleId = vehicleId;
    vehicle.status = 'on_mission';
    vehicle.assignedDriverId = driverId;
    await vehicle.save();
  }

  trip.assignedDriverId = driverId;
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

// @desc Driver updates trip status through the mission screen (CHA-03..08)
// @route PUT /api/trips/:id/status
const updateTripStatus = asyncHandler(async (req, res) => {
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }

  const isDriver = isSameId(trip.assignedDriverId, req.user._id);
  const isAdmin = req.user.role === 'admin';
  const isCarrier = isSameId(trip.assignedCarrierId, req.user._id);
  if (!isDriver && !isAdmin && !isCarrier) {
    res.status(403);
    throw new Error('Not authorized');
  }

  const { status, lat, lng, note } = req.body;
  if (!status) {
    res.status(400);
    throw new Error('status is required');
  }
  if (!canTransition(trip.status, status, isAdmin)) {
    res.status(400);
    throw new Error(`Invalid transition from ${trip.status} to ${status}`);
  }

  pushStatus(trip, status, req.user._id, note);
  if (Number.isFinite(Number(lat)) && Number.isFinite(Number(lng))) {
    trip.lastKnownLocation = { lat: Number(lat), lng: Number(lng), updatedAt: new Date() };
    trip.statusHistory[trip.statusHistory.length - 1].location = {
      lat: Number(lat),
      lng: Number(lng),
    };
  }
  if (status === 'en_route_pickup') trip.liveTrackingEnabled = true;
  if (status === 'delivered') trip.liveTrackingEnabled = false;

  // Free the vehicle again once the mission ends.
  if (['delivered', 'cancelled'].includes(status) && trip.assignedVehicleId) {
    await Vehicle.findByIdAndUpdate(trip.assignedVehicleId, {
      status: 'available',
      $unset: { assignedDriverId: '' },
    });
  }

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
  const trip = await Trip.findById(req.params.id).select('assignedDriverId');
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }
  // Previously unchecked: any driver could report a position for any trip.
  if (!isSameId(trip.assignedDriverId, req.user._id)) {
    res.status(403);
    throw new Error('Not authorized to report a position for this trip');
  }

  const lat = Number(req.body.lat);
  const lng = Number(req.body.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    res.status(400);
    throw new Error('Valid lat and lng are required');
  }

  await Trip.updateOne(
    { _id: trip._id },
    {
      $set: { lastKnownLocation: { lat, lng, updatedAt: new Date() } },
      // Keeps only the 500 most recent pings without loading the array.
      $push: { trackingPings: { $each: [{ lat, lng }], $slice: -500 } },
    }
  );

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
  if (!isSameId(trip.shipperId, req.user._id) && req.user.role !== 'admin') {
    res.status(403);
    throw new Error('Not authorized');
  }
  if (!canTransition(trip.status, 'pod_confirmed', req.user.role === 'admin')) {
    res.status(400);
    throw new Error(`Cannot confirm POD from status ${trip.status}`);
  }
  pushStatus(trip, 'pod_confirmed', req.user._id);
  await trip.save();

  if (trip.assignedCarrierId) {
    await notifyUser(trip.assignedCarrierId, {
      type: 'delivered',
      title: 'Réception confirmée',
      body: `Le chargeur a confirmé la réception du trajet ${trip.reference}`,
      tripId: trip._id,
    });
  }

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
  if (!isSameId(trip.shipperId, req.user._id)) {
    res.status(403);
    throw new Error('Not authorized');
  }
  // A carrier can only be rated once the goods actually arrived, and only once.
  // Both were previously unchecked, which let ratings be inflated at will.
  if (!['delivered', 'pod_confirmed', 'invoiced', 'paid', 'closed'].includes(trip.status)) {
    res.status(400);
    throw new Error('You can only rate a carrier once the trip has been delivered');
  }
  if (trip.review?.createdAt) {
    res.status(409);
    throw new Error('This trip has already been reviewed');
  }

  const { rating, punctuality, goodsCondition, behavior, comment } = req.body;
  const score = Number(rating);
  if (!Number.isFinite(score) || score < 1 || score > 5) {
    res.status(400);
    throw new Error('rating must be between 1 and 5');
  }

  trip.review = {
    rating: score,
    punctuality,
    goodsCondition,
    behavior,
    comment,
    createdAt: new Date(),
  };
  await trip.save();

  if (trip.assignedCarrierId) {
    const carrier = await User.findById(trip.assignedCarrierId);
    if (carrier) {
      const total = carrier.rating * carrier.ratingCount + score;
      carrier.ratingCount += 1;
      carrier.rating = Number((total / carrier.ratingCount).toFixed(2));
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
  // Was completely unauthorized: any driver or carrier could file against any trip.
  const involved =
    isSameId(trip.assignedDriverId, req.user._id) ||
    isSameId(trip.assignedCarrierId, req.user._id) ||
    req.user.role === 'admin';
  if (!involved) {
    res.status(403);
    throw new Error('Not authorized to report an incident on this trip');
  }
  if (!req.body.type) {
    res.status(400);
    throw new Error('Incident type is required');
  }

  trip.incidentReports.push({
    type: req.body.type,
    note: req.body.note,
    photos: req.body.photos || [],
    reportedBy: req.user._id,
  });
  await trip.save();

  const recipients = [trip.shipperId];
  if (trip.assignedCarrierId && !isSameId(trip.assignedCarrierId, req.user._id)) {
    recipients.push(trip.assignedCarrierId);
  }
  for (const recipient of recipients) {
    await notifyUser(recipient, {
      type: 'delay',
      title: 'Incident signalé',
      body: `Incident sur le trajet ${trip.reference}: ${req.body.type}`,
      tripId: trip._id,
      isCritical: true,
    });
  }

  await logAction({
    actorId: req.user._id,
    actorRole: req.user.role,
    action: 'incident_reported',
    tripId: trip._id,
    metadata: { type: req.body.type },
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
  if (!carrierId && !driverId && !vehicleId) {
    res.status(400);
    throw new Error('Provide at least one of carrierId, driverId or vehicleId');
  }

  if (carrierId) {
    const carrier = await User.findById(carrierId);
    if (!carrier || carrier.role !== 'carrier') {
      res.status(400);
      throw new Error('carrierId does not refer to a carrier');
    }
    trip.assignedCarrierId = carrierId;
    // A new carrier invalidates the previous crew unless one is supplied now.
    if (!driverId) trip.assignedDriverId = undefined;
    if (!vehicleId) trip.assignedVehicleId = undefined;
  }
  if (driverId) {
    const driver = await User.findById(driverId);
    if (!driver || driver.role !== 'driver') {
      res.status(400);
      throw new Error('driverId does not refer to a driver');
    }
    trip.assignedDriverId = driverId;
  }
  if (vehicleId) trip.assignedVehicleId = vehicleId;

  pushStatus(
    trip,
    trip.assignedDriverId ? 'driver_assigned' : 'assigned',
    req.user._id,
    'Reassigned by admin'
  );
  await trip.save();

  for (const target of [trip.assignedCarrierId, trip.assignedDriverId]) {
    if (target) {
      await notifyUser(target, {
        type: 'trip_assigned',
        title: 'Trajet réattribué',
        body: `Le trajet ${trip.reference} vous a été réattribué`,
        tripId: trip._id,
        isCritical: true,
      });
    }
  }

  await logAction({
    actorId: req.user._id,
    actorRole: 'admin',
    action: 'trip_reassigned',
    tripId: trip._id,
  });
  res.json(trip);
});

// @desc Cancel a trip (shipper before assignment, admin at any point).
// @route PUT /api/trips/:id/cancel
const cancelTrip = asyncHandler(async (req, res) => {
  const trip = await Trip.findById(req.params.id);
  if (!trip) {
    res.status(404);
    throw new Error('Trip not found');
  }
  const isAdmin = req.user.role === 'admin';
  if (!isSameId(trip.shipperId, req.user._id) && !isAdmin) {
    res.status(403);
    throw new Error('Not authorized');
  }
  if (!canTransition(trip.status, 'cancelled', isAdmin)) {
    res.status(400);
    throw new Error(`Cannot cancel a trip in status ${trip.status}`);
  }

  pushStatus(trip, 'cancelled', req.user._id, req.body.reason);
  if (trip.assignedVehicleId) {
    await Vehicle.findByIdAndUpdate(trip.assignedVehicleId, {
      status: 'available',
      $unset: { assignedDriverId: '' },
    });
  }
  await trip.save();

  for (const target of [trip.assignedCarrierId, trip.assignedDriverId]) {
    if (target) {
      await notifyUser(target, {
        type: 'account_status',
        title: 'Trajet annulé',
        body: `Le trajet ${trip.reference} a été annulé`,
        tripId: trip._id,
        isCritical: true,
      });
    }
  }

  await logAction({
    actorId: req.user._id,
    actorRole: req.user.role,
    action: 'trip_cancelled',
    tripId: trip._id,
    metadata: { reason: req.body.reason },
  });

  res.json(trip);
});

// @desc Return load suggestions for a carrier (TRA-13)
// @route GET /api/trips/return-loads
const getReturnLoads = asyncHandler(async (req, res) => {
  const settings = await Settings.findOne({ key: 'global' });
  const radiusKm = settings?.returnLoadRadiusKm || 100;
  const windowDays = settings?.returnLoadWindowDays || 3;

  // Anchor on where this carrier's active trips actually end, so suggestions are
  // genuinely "on the way back" rather than any load in the operating wilayas.
  const activeTrips = await Trip.find({
    assignedCarrierId: req.user._id,
    status: {
      $in: ['en_route_pickup', 'loaded', 'en_route_delivery', 'arrived_delivery', 'delivered'],
    },
  })
    .select('dropoff requestedDeliveryDate reference')
    .sort({ updatedAt: -1 })
    .limit(5);

  const candidates = await Trip.find({
    status: 'published',
    assignedCarrierId: { $exists: false },
    shipperId: { $ne: req.user._id },
  })
    .populate('shipperId', 'companyName fullName')
    .limit(200);

  const seen = new Set();
  const matches = [];

  for (const anchor of activeTrips) {
    for (const c of candidates) {
      if (seen.has(String(c._id))) continue;
      let near = false;
      if (anchor.dropoff?.lat != null && c.pickup?.lat != null) {
        near = haversineKm(anchor.dropoff, c.pickup) <= radiusKm;
      } else if (anchor.dropoff?.wilaya && c.pickup?.wilaya) {
        // No coordinates on one side — fall back to same-wilaya matching.
        near = anchor.dropoff.wilaya === c.pickup.wilaya;
      }
      if (near) {
        seen.add(String(c._id));
        matches.push(c);
      }
    }
  }

  // No active trip to return from: fall back to the carrier's operating wilayas.
  if (!activeTrips.length && req.user.operatingWilayas?.length) {
    for (const c of candidates) {
      if (seen.has(String(c._id))) continue;
      if (req.user.operatingWilayas.includes(c.pickup?.wilaya)) {
        seen.add(String(c._id));
        matches.push(c);
      }
    }
  }

  res.json({ radiusKm, windowDays, matches: matches.slice(0, 50) });
});

module.exports = {
  createTrip,
  publishTrip,
  listTrips,
  getTrip,
  submitOffer,
  acceptFixedPrice,
  assignCarrier,
  assignDriver,
  updateTripStatus,
  pingLocation,
  confirmPod,
  reviewTrip,
  reportIncident,
  reassignTrip,
  cancelTrip,
  getReturnLoads,
};
