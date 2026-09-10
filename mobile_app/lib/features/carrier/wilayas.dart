/// The carrier's operating-wilaya multi-select (section 5.2) must use exactly the
/// same wilaya strings as the trip pickup/dropoff dropdowns, because the
/// marketplace filter matches them directly:
///
///     { 'pickup.wilaya': { $in: user.operatingWilayas } }
///
/// This file used to hold a second, name-only list ('Oran'), while trips stored
/// the coded form ('31 - Oran'). Those never compared equal, so any carrier who
/// set their operating wilayas saw an empty marketplace and no return loads.
/// Re-exporting the canonical list keeps the two sides from drifting apart again.
export '../../core/constants/algeria_wilayas.dart' show algeriaWilayas;
