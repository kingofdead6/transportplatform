const asyncHandler = require('express-async-handler');
const User = require('../models/User');
const Vehicle = require('../models/Vehicle');
const { logAction } = require('../utils/audit');

// @desc Update own profile (EXP-02, TRA-01)
// @route PUT /api/users/me
const updateProfile = asyncHandler(async (req, res) => {
  const allowedFields = [
    'fullName',
    'email',
    'preferredLanguage',
    'companyName',
    'taxId',
    'statisticalId',
    'tradeRegister',
    'address',
    'wilaya',
    'contactPerson',
    'bankAccount',
    'operatingWilayas',
    'operatingCorridors',
    'licenseNumber',
    'licenseCategory',
    'licenseExpiresAt',
  ];
  allowedFields.forEach((field) => {
    if (req.body[field] !== undefined) req.user[field] = req.body[field];
  });
  await req.user.save();
  res.json(req.user.toSafeJSON());
});

// @desc Upload a KYC/company document (EXP-03)
// @route POST /api/users/me/documents
const uploadDocument = asyncHandler(async (req, res) => {
  if (!req.file) {
    res.status(400);
    throw new Error('File required');
  }
  const { type, expiresAt } = req.body;
  req.user.documents.push({
    type,
    url: req.file.path,
    publicId: req.file.filename,
    expiresAt: expiresAt || undefined,
  });
  await req.user.save();
  res.status(201).json(req.user.toSafeJSON());
});

// @desc Carrier adds a driver (TRA-04)
// @route POST /api/users/drivers
const addDriver = asyncHandler(async (req, res) => {
  if (req.user.role !== 'carrier') {
    res.status(403);
    throw new Error('Only carriers can add drivers');
  }
  const { phone, fullName, licenseNumber, licenseCategory, licenseExpiresAt } = req.body;
  const driver = await User.create({
    phone,
    fullName,
    role: 'driver',
    carrierId: req.user._id,
    licenseNumber,
    licenseCategory,
    licenseExpiresAt,
    status: 'active',
  });
  res.status(201).json(driver.toSafeJSON());
});

// @desc List drivers belonging to the logged-in carrier
// @route GET /api/users/drivers
const listMyDrivers = asyncHandler(async (req, res) => {
  const drivers = await User.find({ carrierId: req.user._id, role: 'driver' });
  res.json(drivers);
});

// @desc Admin: list users with filters (ADM-09 directory)
// @route GET /api/users
const listUsers = asyncHandler(async (req, res) => {
  const { role, status, search } = req.query;
  const filter = {};
  if (role) filter.role = role;
  if (status) filter.status = status;
  if (search) {
    filter.$or = [
      { fullName: new RegExp(search, 'i') },
      { companyName: new RegExp(search, 'i') },
      { phone: new RegExp(search, 'i') },
    ];
  }
  const users = await User.find(filter).sort({ createdAt: -1 });
  res.json(users);
});

// @desc Admin: get one user with vehicles if carrier
// @route GET /api/users/:id
const getUser = asyncHandler(async (req, res) => {
  const user = await User.findById(req.params.id);
  if (!user) {
    res.status(404);
    throw new Error('User not found');
  }
  let vehicles = [];
  if (user.role === 'carrier') {
    vehicles = await Vehicle.find({ carrierId: user._id });
  }
  res.json({ user, vehicles });
});

// @desc Admin: approve/reject a pending account (EXP-04, ADM-10)
// @route PUT /api/users/:id/status
const setUserStatus = asyncHandler(async (req, res) => {
  const { status } = req.body; // active | rejected | blocked
  const user = await User.findById(req.params.id);
  if (!user) {
    res.status(404);
    throw new Error('User not found');
  }
  const previous = user.status;
  user.status = status;
  await user.save();
  await logAction({
    actorId: req.user._id,
    actorRole: req.user.role,
    action: `user_status_${status}`,
    targetType: 'User',
    targetId: user._id,
    metadata: { previous, next: status },
  });
  res.json(user.toSafeJSON());
});

// @desc Documents expiring soon across users/vehicles (ADM-12)
// @route GET /api/users/alerts/documents
const documentExpiryAlerts = asyncHandler(async (req, res) => {
  const days = Number(req.query.days) || 30;
  const threshold = new Date(Date.now() + days * 24 * 60 * 60 * 1000);

  const users = await User.find({ 'documents.expiresAt': { $lte: threshold } }).select(
    'fullName companyName phone role documents'
  );
  const vehicles = await Vehicle.find({ 'documents.expiresAt': { $lte: threshold } }).select(
    'plateNumber carrierId documents'
  );

  res.json({ users, vehicles });
});

module.exports = {
  updateProfile,
  uploadDocument,
  addDriver,
  listMyDrivers,
  listUsers,
  getUser,
  setUserStatus,
  documentExpiryAlerts,
};
