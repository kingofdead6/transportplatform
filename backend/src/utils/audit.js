const AuditLog = require('../models/AuditLog');

async function logAction({ actorId, actorRole, action, tripId, targetType, targetId, metadata }) {
  try {
    await AuditLog.create({ actorId, actorRole, action, tripId, targetType, targetId, metadata });
  } catch (err) {
    console.error('[audit] failed to log action:', err.message);
  }
}

module.exports = { logAction };
