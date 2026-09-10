const asyncHandler = require('express-async-handler');
const Vehicle = require('../models/Vehicle');
const Trip = require('../models/Trip');

const VEHICLE_STATUSES = ['available', 'on_mission', 'broken_down', 'maintenance'];

// Admins act on any vehicle; a carrier only ever on their own.
function scopeFor(req, id) {
  const filter = { _id: id };
  if (req.user.role !== 'admin') filter.carrierId = req.user._id;
  return filter;
}

// @route POST /api/vehicles (TRA-02)
const createVehicle = asyncHandler(async (req, res) => {
  const { plateNumber, type } = req.body;
  if (!plateNumber?.trim()) {
    res.status(400);
    throw new Error('Plate number is required');
  }
  if (!type) {
    res.status(400);
    throw new Error('Vehicle type is required');
  }

  const carrierId = req.user.role === 'admin' && req.body.carrierId ? req.body.carrierId : req.user._id;

  // Plates are unique per carrier — duplicates made the fleet list ambiguous.
  const existing = await Vehicle.findOne({
    carrierId,
    plateNumber: new RegExp(`^${plateNumber.trim()}$`, 'i'),
  });
  if (existing) {
    res.status(409);
    throw new Error('A vehicle with this plate number already exists in your fleet');
  }

  const vehicle = await Vehicle.create({
    ...req.body,
    plateNumber: plateNumber.trim(),
    carrierId,
  });
  res.status(201).json(vehicle);
});

// @route GET /api/vehicles/mine
const listMyVehicles = asyncHandler(async (req, res) => {
  const filter = req.user.role === 'admin' && req.query.carrierId
    ? { carrierId: req.query.carrierId }
    : { carrierId: req.user._id };
  const vehicles = await Vehicle.find(filter)
    .populate('assignedDriverId', 'fullName phone')
    .sort({ createdAt: -1 });
  res.json(vehicles);
});

// @route GET /api/vehicles/:id
const getVehicle = asyncHandler(async (req, res) => {
  const vehicle = await Vehicle.findOne(scopeFor(req, req.params.id)).populate(
    'assignedDriverId',
    'fullName phone'
  );
  if (!vehicle) {
    res.status(404);
    throw new Error('Vehicle not found');
  }
  res.json(vehicle);
});

// @route PUT /api/vehicles/:id
const updateVehicle = asyncHandler(async (req, res) => {
  const vehicle = await Vehicle.findOne(scopeFor(req, req.params.id));
  if (!vehicle) {
    res.status(404);
    throw new Error('Vehicle not found');
  }

  // carrierId and documents are managed through their own dedicated routes;
  // a blanket Object.assign let a request reassign the vehicle to another fleet.
  const editable = [
    'plateNumber',
    'brand',
    'model',
    'type',
    'payloadCapacityKg',
    'yearOfManufacture',
    'assignedDriverId',
  ];
  editable.forEach((field) => {
    if (req.body[field] !== undefined) vehicle[field] = req.body[field];
  });

  await vehicle.save();
  res.json(vehicle);
});

// @route PUT /api/vehicles/:id/status (TRA-06)
const setVehicleStatus = asyncHandler(async (req, res) => {
  const { status } = req.body;
  if (!VEHICLE_STATUSES.includes(status)) {
    res.status(400);
    throw new Error(`Status must be one of: ${VEHICLE_STATUSES.join(', ')}`);
  }

  const vehicle = await Vehicle.findOne(scopeFor(req, req.params.id));
  if (!vehicle) {
    res.status(404);
    throw new Error('Vehicle not found');
  }

  // A vehicle mid-mission cannot simply be marked available again — the trip
  // has to end first, otherwise the fleet view contradicts the trip board.
  if (vehicle.status === 'on_mission' && status === 'available') {
    const activeTrip = await Trip.findOne({
      assignedVehicleId: vehicle._id,
      status: {
        $in: ['driver_assigned', 'en_route_pickup', 'loaded', 'en_route_delivery', 'arrived_delivery'],
      },
    }).select('reference');
    if (activeTrip) {
      res.status(409);
      throw new Error(`This vehicle is still running trip ${activeTrip.reference}`);
    }
  }

  vehicle.status = status;
  if (status !== 'on_mission') vehicle.assignedDriverId = undefined;
  await vehicle.save();
  res.json(vehicle);
});

// @route POST /api/vehicles/:id/documents (TRA-03)
const addVehicleDocument = asyncHandler(async (req, res) => {
  const vehicle = await Vehicle.findOne(scopeFor(req, req.params.id));
  if (!vehicle) {
    res.status(404);
    throw new Error('Vehicle not found');
  }
  if (!req.file) {
    res.status(400);
    throw new Error('File required');
  }
  if (!['registration', 'insurance', 'technical_inspection'].includes(req.body.type)) {
    res.status(400);
    throw new Error('Document type must be registration, insurance or technical_inspection');
  }

  vehicle.documents.push({
    type: req.body.type,
    url: req.file.path,
    publicId: req.file.filename,
    expiresAt: req.body.expiresAt || undefined,
  });
  await vehicle.save();
  res.status(201).json(vehicle);
});

// @route DELETE /api/vehicles/:id
const deleteVehicle = asyncHandler(async (req, res) => {
  const vehicle = await Vehicle.findOne(scopeFor(req, req.params.id));
  if (!vehicle) {
    res.status(404);
    throw new Error('Vehicle not found');
  }

  const activeTrip = await Trip.findOne({
    assignedVehicleId: vehicle._id,
    status: {
      $in: ['driver_assigned', 'en_route_pickup', 'loaded', 'en_route_delivery', 'arrived_delivery'],
    },
  }).select('reference');
  if (activeTrip) {
    res.status(409);
    throw new Error(`This vehicle is still running trip ${activeTrip.reference}`);
  }

  await vehicle.deleteOne();
  res.json({ message: 'Vehicle removed' });
});

module.exports = {
  createVehicle,
  listMyVehicles,
  getVehicle,
  updateVehicle,
  setVehicleStatus,
  addVehicleDocument,
  deleteVehicle,
};
