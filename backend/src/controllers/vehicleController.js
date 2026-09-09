const asyncHandler = require('express-async-handler');
const Vehicle = require('../models/Vehicle');

// @route POST /api/vehicles (TRA-02)
const createVehicle = asyncHandler(async (req, res) => {
  const vehicle = await Vehicle.create({ ...req.body, carrierId: req.user._id });
  res.status(201).json(vehicle);
});

// @route GET /api/vehicles/mine
const listMyVehicles = asyncHandler(async (req, res) => {
  const vehicles = await Vehicle.find({ carrierId: req.user._id });
  res.json(vehicles);
});

// @route PUT /api/vehicles/:id
const updateVehicle = asyncHandler(async (req, res) => {
  const vehicle = await Vehicle.findOne({ _id: req.params.id, carrierId: req.user._id });
  if (!vehicle) {
    res.status(404);
    throw new Error('Vehicle not found');
  }
  Object.assign(vehicle, req.body);
  await vehicle.save();
  res.json(vehicle);
});

// @route PUT /api/vehicles/:id/status (TRA-06)
const setVehicleStatus = asyncHandler(async (req, res) => {
  const vehicle = await Vehicle.findOne({ _id: req.params.id, carrierId: req.user._id });
  if (!vehicle) {
    res.status(404);
    throw new Error('Vehicle not found');
  }
  vehicle.status = req.body.status;
  await vehicle.save();
  res.json(vehicle);
});

// @route POST /api/vehicles/:id/documents (TRA-03)
const addVehicleDocument = asyncHandler(async (req, res) => {
  const vehicle = await Vehicle.findOne({ _id: req.params.id, carrierId: req.user._id });
  if (!vehicle) {
    res.status(404);
    throw new Error('Vehicle not found');
  }
  if (!req.file) {
    res.status(400);
    throw new Error('File required');
  }
  vehicle.documents.push({
    type: req.body.type,
    url: req.file.path,
    publicId: req.file.filename,
    expiresAt: req.body.expiresAt,
  });
  await vehicle.save();
  res.status(201).json(vehicle);
});

module.exports = { createVehicle, listMyVehicles, updateVehicle, setVehicleStatus, addVehicleDocument };
