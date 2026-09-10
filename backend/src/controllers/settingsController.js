const asyncHandler = require('express-async-handler');
const Settings = require('../models/Settings');

// @route GET /api/settings
const getSettings = asyncHandler(async (req, res) => {
  let settings = await Settings.findOne({ key: 'global' });
  if (!settings) settings = await Settings.create({ key: 'global' });
  res.json(settings);
});

// @route PUT /api/settings
const updateSettings = asyncHandler(async (req, res) => {
  if (req.user.role !== 'admin') {
    res.status(403);
    throw new Error('Admin only');
  }

  // Whitelisted: spreading req.body let a request overwrite `key` or rewind
  // `lastInvoiceSeq`, which would corrupt invoice numbering.
  const editable = [
    'defaultCommissionPercent',
    'returnLoadRadiusKm',
    'returnLoadWindowDays',
    'vatPercent',
    'invoicePrefix',
    'referencePrices',
  ];
  const update = {};
  for (const field of editable) {
    if (req.body[field] !== undefined) update[field] = req.body[field];
  }

  const percentFields = ['defaultCommissionPercent', 'vatPercent'];
  for (const field of percentFields) {
    if (update[field] !== undefined) {
      const value = Number(update[field]);
      if (!Number.isFinite(value) || value < 0 || value > 100) {
        res.status(400);
        throw new Error(`${field} must be between 0 and 100`);
      }
      update[field] = value;
    }
  }
  if (update.returnLoadRadiusKm !== undefined && !(Number(update.returnLoadRadiusKm) > 0)) {
    res.status(400);
    throw new Error('returnLoadRadiusKm must be greater than 0');
  }
  if (update.returnLoadWindowDays !== undefined && !(Number(update.returnLoadWindowDays) > 0)) {
    res.status(400);
    throw new Error('returnLoadWindowDays must be greater than 0');
  }

  const settings = await Settings.findOneAndUpdate({ key: 'global' }, update, {
    new: true,
    upsert: true,
    setDefaultsOnInsert: true,
  });
  res.json(settings);
});

module.exports = { getSettings, updateSettings };
