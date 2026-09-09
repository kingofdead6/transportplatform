const Trip = require('../models/Trip');
const Settings = require('../models/Settings');
const { notifyUser } = require('../controllers/notificationController');

const toRad = (deg) => (deg * Math.PI) / 180;

function haversineKm(a, b) {
  if (!a || !b || a.lat == null || b.lat == null) return Infinity;
  const R = 6371;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.asin(Math.sqrt(h));
}

// Section 6.2 — when a trip nears delivery, find published trips whose pickup point
// falls within radiusKm of the dropoff, in a window between delivery and +windowDays.
async function findReturnLoadMatches(trip) {
  if (!trip.dropoff?.lat || !trip.assignedCarrierId) return [];

  const settings = await Settings.findOne({ key: 'global' });
  const radiusKm = settings?.returnLoadRadiusKm || 100;
  const windowDays = settings?.returnLoadWindowDays || 3;

  const windowStart = trip.requestedDeliveryDate || new Date();
  const windowEnd = new Date(new Date(windowStart).getTime() + windowDays * 24 * 60 * 60 * 1000);

  const candidates = await Trip.find({
    status: 'published',
    'pickup.lat': { $exists: true },
    pickupWindowStart: { $gte: windowStart, $lte: windowEnd },
  }).limit(100);

  const matches = candidates.filter(
    (c) => haversineKm(trip.dropoff, c.pickup) <= radiusKm
  );

  if (matches.length) {
    await notifyUser(trip.assignedCarrierId, {
      type: 'return_load_available',
      title: 'Chargement retour disponible',
      body: `${matches.length} trajet(s) disponible(s) près de ${trip.dropoff?.wilaya}`,
      tripId: matches[0]._id,
    });
  }

  return matches;
}

module.exports = { findReturnLoadMatches, haversineKm };
