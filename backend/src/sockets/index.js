const jwt = require('jsonwebtoken');
const { Server } = require('socket.io');
const { attachIo } = require('../controllers/notificationController');

function initSockets(httpServer) {
  const io = new Server(httpServer, {
    cors: { origin: '*' },
  });

  io.use((socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      if (!token) return next(new Error('No token'));
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId = decoded.id;
      socket.userRole = decoded.role;
      next();
    } catch (err) {
      next(new Error('Auth failed'));
    }
  });

  io.on('connection', (socket) => {
    socket.join(`user:${socket.userId}`);

    // Driver broadcasts location; anyone watching the trip room receives it (EXP-16 / ADM-07)
    socket.on('trip:track', (tripId) => {
      socket.join(`trip:${tripId}`);
    });

    socket.on('trip:location', ({ tripId, lat, lng }) => {
      io.to(`trip:${tripId}`).emit('trip:location', { tripId, lat, lng, at: Date.now() });
    });

    socket.on('trip:leave', (tripId) => {
      socket.leave(`trip:${tripId}`);
    });

    socket.on('disconnect', () => {});
  });

  attachIo(io);
  return io;
}

module.exports = initSockets;
