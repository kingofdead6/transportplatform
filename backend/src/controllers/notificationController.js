const asyncHandler = require('express-async-handler');
const Notification = require('../models/Notification');

let io = null;
function attachIo(ioInstance) {
  io = ioInstance;
}

async function notifyUser(userId, { type, title, body, tripId, isCritical = false }) {
  const notif = await Notification.create({ userId, type, title, body, tripId, isCritical });
  if (io) {
    io.to(`user:${userId}`).emit('notification', notif);
  }
  return notif;
}

// @route GET /api/notifications
const listMyNotifications = asyncHandler(async (req, res) => {
  const notifications = await Notification.find({ userId: req.user._id })
    .sort({ createdAt: -1 })
    .limit(100);
  res.json(notifications);
});

// @route PUT /api/notifications/:id/read
const markRead = asyncHandler(async (req, res) => {
  const notif = await Notification.findOneAndUpdate(
    { _id: req.params.id, userId: req.user._id },
    { read: true },
    { new: true }
  );
  res.json(notif);
});

// @route PUT /api/notifications/read-all
const markAllRead = asyncHandler(async (req, res) => {
  await Notification.updateMany({ userId: req.user._id, read: false }, { read: true });
  res.json({ ok: true });
});

module.exports = { attachIo, notifyUser, listMyNotifications, markRead, markAllRead };
