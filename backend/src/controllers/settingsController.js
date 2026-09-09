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
  const settings = await Settings.findOneAndUpdate({ key: 'global' }, req.body, {
    new: true,
    upsert: true,
  });
  res.json(settings);
});

module.exports = { getSettings, updateSettings };
