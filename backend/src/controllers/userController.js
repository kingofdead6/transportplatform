const asyncHandler = require('express-async-handler');
const User = require('../models/User');
const Vehicle = require('../models/Vehicle');
const { logAction } = require('../utils/audit');
const { notifyUser } = require('./notificationController');

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

// @desc Change own password
// @route PUT /api/users/me/password
const changePassword = asyncHandler(async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  if (!newPassword || newPassword.length < 6) {
    res.status(400);
    throw new Error('New password must be at least 6 characters');
  }

  const user = await User.findById(req.user._id).select('+password');
  // Accounts created by a carrier have no password yet, so the first time they
  // set one there is nothing to verify against.
  if (user.password) {
    if (!currentPassword || !(await user.comparePassword(currentPassword))) {
      res.status(401);
      throw new Error('Current password is incorrect');
    }
  }

  user.password = newPassword;
  await user.save();
  res.json({ message: 'Password updated' });
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
  const { phone, password, fullName, licenseNumber, licenseCategory, licenseExpiresAt } = req.body;

  if (!phone) {
    res.status(400);
    throw new Error('Phone number is required');
  }
  // Drivers log in with phone + password like everyone else. Without one the
  // account was created but could never actually sign in.
  if (!password || password.length < 6) {
    res.status(400);
    throw new Error('A password of at least 6 characters is required so the driver can log in');
  }

  const existing = await User.findOne({ phone });
  if (existing) {
    res.status(409);
    throw new Error('An account with this phone number already exists');
  }

  const driver = await User.create({
    phone,
    password,
    fullName,
    role: 'driver',
    carrierId: req.user._id,
    licenseNumber,
    licenseCategory,
    licenseExpiresAt,
    status: 'active',
  });

  await logAction({
    actorId: req.user._id,
    actorRole: 'carrier',
    action: 'driver_created',
    targetType: 'User',
    targetId: driver._id,
  });

  res.status(201).json(driver.toSafeJSON());
});

// @desc Carrier updates one of their drivers (TRA-04)
// @route PUT /api/users/drivers/:id
const updateDriver = asyncHandler(async (req, res) => {
  const driver = await User.findOne({
    _id: req.params.id,
    role: 'driver',
    carrierId: req.user._id,
  });
  if (!driver) {
    res.status(404);
    throw new Error('Driver not found');
  }

  ['fullName', 'licenseNumber', 'licenseCategory', 'licenseExpiresAt'].forEach((field) => {
    if (req.body[field] !== undefined) driver[field] = req.body[field];
  });
  if (req.body.password) {
    if (req.body.password.length < 6) {
      res.status(400);
      throw new Error('Password must be at least 6 characters');
    }
    driver.password = req.body.password;
  }
  if (req.body.status && ['active', 'blocked'].includes(req.body.status)) {
    driver.status = req.body.status;
  }

  await driver.save();
  res.json(driver.toSafeJSON());
});

// @desc List drivers belonging to the logged-in carrier
// @route GET /api/users/drivers
const listMyDrivers = asyncHandler(async (req, res) => {
  const drivers = await User.find({ carrierId: req.user._id, role: 'driver' }).sort({
    createdAt: -1,
  });
  res.json(drivers);
});

// @desc Lookup of active carriers, for admin assignment pickers (ADM-05/08).
// @route GET /api/users/carriers
const listCarriers = asyncHandler(async (req, res) => {
  const filter = { role: 'carrier', status: 'active' };
  if (req.query.search) {
    filter.$or = [
      { companyName: new RegExp(req.query.search, 'i') },
      { fullName: new RegExp(req.query.search, 'i') },
      { phone: new RegExp(req.query.search, 'i') },
    ];
  }
  const carriers = await User.find(filter)
    .select('companyName fullName phone wilaya rating ratingCount operatingWilayas')
    .sort({ companyName: 1 })
    .limit(200);
  res.json(carriers);
});

// @desc Drivers of a given carrier, for admin reassignment pickers (ADM-08).
// @route GET /api/users/carriers/:id/drivers
const listCarrierDrivers = asyncHandler(async (req, res) => {
  const drivers = await User.find({ role: 'driver', carrierId: req.params.id })
    .select('fullName phone licenseCategory licenseExpiresAt status')
    .sort({ fullName: 1 });
  res.json(drivers);
});

// @desc Admin: list users with filters (ADM-09 directory)
// @route GET /api/users
const listUsers = asyncHandler(async (req, res) => {
  const { role, status, search } = req.query;
  const page = Math.max(1, Number(req.query.page) || 1);
  const limit = Math.min(200, Math.max(1, Number(req.query.limit) || 100));

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
  const users = await User.find(filter)
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit);
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
  let drivers = [];
  if (user.role === 'carrier') {
    vehicles = await Vehicle.find({ carrierId: user._id });
    drivers = await User.find({ carrierId: user._id, role: 'driver' }).select(
      'fullName phone licenseCategory licenseExpiresAt status'
    );
  }
  res.json({ user, vehicles, drivers });
});

// @desc Admin: approve/reject a pending account (EXP-04, ADM-10)
// @route PUT /api/users/:id/status
const setUserStatus = asyncHandler(async (req, res) => {
  const { status } = req.body; // active | rejected | blocked
  if (!['pending', 'active', 'rejected', 'blocked'].includes(status)) {
    res.status(400);
    throw new Error('Invalid status');
  }

  const user = await User.findById(req.params.id);
  if (!user) {
    res.status(404);
    throw new Error('User not found');
  }
  if (String(user._id) === String(req.user._id)) {
    res.status(400);
    throw new Error('You cannot change your own account status');
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

  // Tell the account holder — an approval or a block is meaningless if silent.
  if (previous !== status) {
    const titles = {
      active: 'Compte approuvé',
      rejected: 'Compte refusé',
      blocked: 'Compte bloqué',
      pending: 'Compte en attente',
    };
    await notifyUser(user._id, {
      type: 'account_status',
      title: titles[status],
      body: `Le statut de votre compte est maintenant "${status}"`,
      isCritical: true,
    });
  }

  res.json(user.toSafeJSON());
});

// @desc Documents expiring soon across users/vehicles (ADM-12)
// @route GET /api/users/alerts/documents
const documentExpiryAlerts = asyncHandler(async (req, res) => {
  const days = Number(req.query.days) || 30;
  const threshold = new Date(Date.now() + days * 24 * 60 * 60 * 1000);

  const users = await User.find({
    $or: [
      { 'documents.expiresAt': { $lte: threshold } },
      { licenseExpiresAt: { $lte: threshold } },
    ],
  }).select('fullName companyName phone role documents licenseExpiresAt licenseNumber');

  const vehicles = await Vehicle.find({ 'documents.expiresAt': { $lte: threshold } })
    .select('plateNumber carrierId documents')
    .populate('carrierId', 'companyName fullName phone');

  res.json({ users, vehicles, thresholdDays: days });
});

module.exports = {
  updateProfile,
  changePassword,
  uploadDocument,
  addDriver,
  updateDriver,
  listMyDrivers,
  listCarriers,
  listCarrierDrivers,
  listUsers,
  getUser,
  setUserStatus,
  documentExpiryAlerts,
};
