const Trip = require('../models/Trip');
const Settings = require('../models/Settings');
const { notifyUser } = require('../controllers/notificationController');

const toRad = (deg) => (deg * Math.PI) / 180;

function haversineKm(a, b) {
  if (!a || !b || a.lat == null || b.lat == null || a.lng == null || b.lng == null) return Infinity;
  const R = 6371;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.asin(Math.sqrt(h));
}

// Section 6.2 — when a trip nears delivery, find published trips whose pickup point
// falls within radiusKm of the dropoff, departing within the next windowDays.
async function findReturnLoadMatches(trip) {
  if (!trip.assignedCarrierId) return [];

  const settings = await Settings.findOne({ key: 'global' });
  const radiusKm = settings?.returnLoadRadiusKm || 100;
  const windowDays = settings?.returnLoadWindowDays || 3;

  // The window runs from now (the truck is about to be free) forward. It
  // previously started at requestedDeliveryDate — often already in the past —
  // and required pickupWindowStart to be set at all, so almost nothing matched.
  const windowStart = new Date();
  const windowEnd = new Date(windowStart.getTime() + windowDays * 24 * 60 * 60 * 1000);

  const candidates = await Trip.find({
    _id: { $ne: trip._id },
    status: 'published',
    assignedCarrierId: { $exists: false },
    shipperId: { $ne: trip.assignedCarrierId },
    $or: [
      { pickupWindowStart: { $gte: windowStart, $lte: windowEnd } },
      // Trips with no stated pickup window are still valid return candidates.
      { pickupWindowStart: { $exists: false } },
      { pickupWindowStart: null },
    ],
  }).limit(200);

  const matches = candidates.filter((c) => {
    if (trip.dropoff?.lat != null && c.pickup?.lat != null) {
      return haversineKm(trip.dropoff, c.pickup) <= radiusKm;
    }
    // Fall back to wilaya matching when either side lacks coordinates.
    return (
      trip.dropoff?.wilaya != null &&
      c.pickup?.wilaya != null &&
      trip.dropoff.wilaya === c.pickup.wilaya
    );
  });

  if (matches.length) {
    await notifyUser(trip.assignedCarrierId, {
      type: 'return_load_available',
      title: 'Chargement retour disponible',
      body: `${matches.length} trajet(s) disponible(s) près de ${trip.dropoff?.wilaya ?? 'votre destination'}`,
      tripId: matches[0]._id,
    });
  }

  return matches;
}

module.exports = { findReturnLoadMatches, haversineKm };
