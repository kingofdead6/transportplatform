// Section 6.1 — allowed forward transitions in the trip lifecycle.
// Backward transitions from a "closed"/finalized stage require admin intervention (handled in controller).
const TRANSITIONS = {
  draft: ['published', 'cancelled'],
  published: ['offers_received', 'assigned', 'cancelled'],
  offers_received: ['assigned', 'cancelled'],
  assigned: ['driver_assigned', 'cancelled', 'disputed'],
  driver_assigned: ['en_route_pickup', 'cancelled', 'disputed'],
  en_route_pickup: ['loaded', 'disputed', 'suspended'],
  loaded: ['en_route_delivery', 'disputed', 'suspended'],
  en_route_delivery: ['arrived_delivery', 'disputed', 'suspended'],
  arrived_delivery: ['delivered', 'disputed'],
  delivered: ['pod_confirmed', 'disputed'],
  pod_confirmed: ['invoiced'],
  invoiced: ['paid'],
  paid: ['closed'],
  closed: [],
  cancelled: [],
  disputed: ['assigned', 'en_route_pickup', 'loaded', 'en_route_delivery', 'delivered', 'cancelled'], // admin resolves back into flow
  suspended: ['en_route_pickup', 'loaded', 'en_route_delivery', 'cancelled'],
};

function canTransition(from, to, isAdmin = false) {
  if (isAdmin) return true; // ADM can force any transition (rollback rule: "only admin can intervene")
  return (TRANSITIONS[from] || []).includes(to);
}

module.exports = { TRANSITIONS, canTransition };
