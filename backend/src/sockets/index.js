const jwt = require('jsonwebtoken');
const { Server } = require('socket.io');
const Trip = require('../models/Trip');
const User = require('../models/User');
const { attachIo } = require('../controllers/notificationController');

const sameId = (a, b) => a != null && b != null && String(a) === String(b);

/// Who is allowed to watch a trip room: the shipper, the assigned carrier, the
/// assigned driver, or an admin. Without this any authenticated user could
/// subscribe to any trip's live position feed.
async function canWatchTrip(userId, userRole, tripId) {
  if (userRole === 'admin') return true;
  const trip = await Trip.findById(tripId).select('shipperId assignedCarrierId assignedDriverId');
  if (!trip) return false;
  return (
    sameId(trip.shipperId, userId) ||
    sameId(trip.assignedCarrierId, userId) ||
    sameId(trip.assignedDriverId, userId)
  );
}

function initSockets(httpServer) {
  const io = new Server(httpServer, {
    cors: { origin: process.env.SOCKET_CORS_ORIGIN || '*' },
  });

  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      if (!token) return next(new Error('No token'));
      const decoded = jwt.verify(token, process.env.JWT_SECRET);

      // A token alone is not enough: the account may have been blocked since it
      // was issued.
      const user = await User.findById(decoded.id).select('role status');
      if (!user) return next(new Error('Auth failed'));
      if (user.status === 'blocked' || user.status === 'rejected') {
        return next(new Error('Account is not active'));
      }

      socket.userId = String(user._id);
      socket.userRole = user.role;
      next();
    } catch (err) {
      next(new Error('Auth failed'));
    }
  });

  io.on('connection', (socket) => {
    socket.join(`user:${socket.userId}`);

    // Driver broadcasts location; anyone watching the trip room receives it (EXP-16 / ADM-07)
    socket.on('trip:track', async (tripId) => {
      if (!tripId) return;
      if (await canWatchTrip(socket.userId, socket.userRole, tripId)) {
        socket.join(`trip:${tripId}`);
      }
    });

    socket.on('trip:location', async ({ tripId, lat, lng } = {}) => {
      if (!tripId || !Number.isFinite(Number(lat)) || !Number.isFinite(Number(lng))) return;
      // Only the assigned driver may report a position, so positions cannot be spoofed.
      const trip = await Trip.findById(tripId).select('assignedDriverId');
      if (!trip || !sameId(trip.assignedDriverId, socket.userId)) return;

      io.to(`trip:${tripId}`).emit('trip:location', {
        tripId,
        lat: Number(lat),
        lng: Number(lng),
        at: Date.now(),
      });
    });

    socket.on('trip:leave', (tripId) => {
      if (tripId) socket.leave(`trip:${tripId}`);
    });

    socket.on('disconnect', () => {});
  });

  attachIo(io);
  return io;
}

module.exports = initSockets;
