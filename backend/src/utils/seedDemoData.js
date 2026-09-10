require('dotenv').config();
const mongoose = require('mongoose');

const connectDB = require('../config/db');
const User = require('../models/User');
const Vehicle = require('../models/Vehicle');
const Trip = require('../models/Trip');
const Invoice = require('../models/Invoice');
const Dispute = require('../models/Dispute');
const Notification = require('../models/Notification');
const AuditLog = require('../models/AuditLog');
const Settings = require('../models/Settings');
const Counter = require('../models/Counter');
const { ALGERIA_WILAYAS } = require('../constants/wilayas');

/**
 * Fills the database with a realistic, fully-populated demo dataset: companies,
 * fleets, drivers, and trips spread across every stage of the section 6.1
 * lifecycle, plus the invoices, disputes, notifications and audit entries those
 * trips imply.
 *
 * Every record goes through the same rules the API enforces — real password
 * hashing, the app's wilaya strings, coherent status history, commission and VAT
 * arithmetic that adds up — so the screens show believable data rather than
 * placeholders.
 *
 *   npm run seed:demo             # wipe and regenerate
 *   npm run seed:demo -- --keep   # add to what is already there
 *
 * Tunable via env: DEMO_SHIPPERS, DEMO_CARRIERS, DEMO_TRIPS.
 */

// ---------------------------------------------------------------- utilities

// Deterministic PRNG (mulberry32) so a given seed always produces the same
// dataset — useful when comparing screenshots or reproducing a bug.
function makeRandom(seed) {
  let a = seed;
  return function random() {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const rand = makeRandom(Number(process.env.DEMO_SEED) || 20260910);

const pick = (arr) => arr[Math.floor(rand() * arr.length)];
const pickMany = (arr, n) => {
  const pool = [...arr];
  const out = [];
  while (out.length < n && pool.length) {
    out.push(pool.splice(Math.floor(rand() * pool.length), 1)[0]);
  }
  return out;
};
const intBetween = (min, max) => Math.floor(rand() * (max - min + 1)) + min;
const roundTo = (value, step) => Math.round(value / step) * step;
const daysFromNow = (d) => new Date(Date.now() + d * 24 * 60 * 60 * 1000);
const hoursFromNow = (h) => new Date(Date.now() + h * 60 * 60 * 1000);

// ------------------------------------------------------------ reference data

// Wilayas that carry most real freight, with coordinates so the tracking map and
// the return-load radius search have something meaningful to work with.
const HUBS = [
  { wilaya: '16 - Alger', lat: 36.7538, lng: 3.0588, city: 'Alger' },
  { wilaya: '31 - Oran', lat: 35.6971, lng: -0.6337, city: 'Oran' },
  { wilaya: '25 - Constantine', lat: 36.365, lng: 6.6147, city: 'Constantine' },
  { wilaya: '19 - Sétif', lat: 36.1898, lng: 5.4108, city: 'Sétif' },
  { wilaya: '23 - Annaba', lat: 36.9, lng: 7.7667, city: 'Annaba' },
  { wilaya: '05 - Batna', lat: 35.5559, lng: 6.1741, city: 'Batna' },
  { wilaya: '09 - Blida', lat: 36.4703, lng: 2.8277, city: 'Blida' },
  { wilaya: '30 - Ouargla', lat: 31.9493, lng: 5.3255, city: 'Ouargla' },
  { wilaya: '47 - Ghardaïa', lat: 32.4909, lng: 3.6735, city: 'Ghardaïa' },
  { wilaya: '13 - Tlemcen', lat: 34.8828, lng: -1.3167, city: 'Tlemcen' },
  { wilaya: '06 - Béjaïa', lat: 36.7509, lng: 5.0567, city: 'Béjaïa' },
  { wilaya: '39 - El Oued', lat: 33.3568, lng: 6.8676, city: 'El Oued' },
];

const SHIPPER_COMPANIES = [
  ['SARL Karim Matériaux', 'Sassi Karim', 'construction'],
  ['ETS Belkacem Import', 'Belkacem Nadir', 'palletized'],
  ['SPA Cevital Agro', 'Merabet Yacine', 'food'],
  ['SARL Métal Ouest', 'Benali Sofiane', 'machinery'],
  ['EURL Ciment Chlef', 'Haddad Rachid', 'bulk'],
  ['SARL Froid Express', 'Zerrouki Amine', 'food'],
  ['SPA Pétrochimie Sud', 'Larbi Mustapha', 'hazardous'],
  ['SARL Meubles Kabylie', 'Ait Ouali Karim', 'palletized'],
  ['ETS Grains Hauts Plateaux', 'Benyoucef Omar', 'bulk'],
  ['SARL Auto Pièces DZ', 'Cherif Bilal', 'machinery'],
];

const CARRIER_COMPANIES = [
  ['Boudiaf Transport SARL', 'Boudiaf Slimane'],
  ['SARL Logistique Atlas', 'Meziane Farid'],
  ['ETS Transport Sahara', 'Ould Ali Brahim'],
  ['SPA TransMaghreb', 'Kaci Djamel'],
  ['SARL Rapid Fret', 'Benhamou Toufik'],
  ['EURL Nord-Sud Logistics', 'Saidi Mourad'],
];

const DRIVER_NAMES = [
  'Ahmed Bencheikh', 'Youcef Mammeri', 'Karim Belhadj', 'Rachid Toumi',
  'Samir Ouali', 'Nabil Hamdi', 'Farid Kaddour', 'Djamel Bouzid',
  'Hakim Sadi', 'Mourad Lounis', 'Omar Ferhat', 'Lyes Bouchama',
  'Tarek Mansouri', 'Sofiane Gharbi', 'Riad Benali', 'Walid Khelifi',
];

const TRUCKS = [
  ['Mercedes', 'Actros', 'tipper', 40000],
  ['Renault', 'Premium', 'flatbed', 25000],
  ['Volvo', 'FH16', 'semi_trailer', 44000],
  ['Scania', 'R450', 'semi_trailer', 40000],
  ['MAN', 'TGX', 'closed', 26000],
  ['Iveco', 'Stralis', 'refrigerated', 22000],
  ['DAF', 'XF105', 'tanker', 30000],
  ['Hyundai', 'HD270', 'car_carrier', 18000],
  ['Sinotruk', 'Howo', 'tipper', 35000],
  ['Foton', 'Auman', 'flatbed', 20000],
];

const GOODS_BY_TYPE = {
  bulk: ['Sable de carrière', 'Gravier concassé', 'Blé tendre en vrac', 'Ciment vrac'],
  palletized: ['Palettes de carrelage', 'Cartons électroménager', 'Palettes de boissons'],
  construction: ['Rond à béton', 'Parpaings', 'Charpente métallique', 'Sacs de ciment'],
  food: ['Produits laitiers réfrigérés', 'Huile alimentaire', 'Conserves', 'Fruits et légumes'],
  hazardous: ['Bitume liquide', 'Produits chimiques ADR', 'Bouteilles de gaz'],
  machinery: ['Groupe électrogène', 'Pièces détachées auto', 'Compresseur industriel'],
  other: ['Marchandises diverses', 'Matériel de bureau'],
};

const VEHICLE_FOR_GOODS = {
  bulk: ['tipper', 'semi_trailer'],
  palletized: ['closed', 'semi_trailer', 'flatbed'],
  construction: ['flatbed', 'tipper', 'semi_trailer'],
  food: ['refrigerated', 'closed'],
  hazardous: ['tanker'],
  machinery: ['flatbed', 'car_carrier', 'semi_trailer'],
  other: ['closed', 'flatbed'],
};

const INSTRUCTIONS = [
  'Livraison avant 14h, contacter le magasinier à l\'arrivée.',
  'Chargement par nos soins, prévoir 2h sur site.',
  'Accès poids lourd par la porte nord uniquement.',
  'Bâchage obligatoire.',
  'Marchandise fragile — manutention avec précaution.',
  '',
  '',
];

const INCIDENT_TYPES = ['breakdown', 'accident', 'road_blocked', 'goods_refused', 'excessive_wait'];

const INCIDENT_NOTES = {
  breakdown: 'Panne turbo, immobilisé sur la RN1, dépanneuse en route.',
  accident: 'Accrochage léger sans blessé, constat établi.',
  road_blocked: 'Route coupée pour travaux, déviation par la RN5.',
  goods_refused: 'Le client refuse 3 palettes non conformes au bon de commande.',
  excessive_wait: 'Attente de plus de 4h au quai de déchargement.',
};

// Section 6.1 lifecycle in order, so status history can be replayed coherently.
const LIFECYCLE = [
  'draft', 'published', 'offers_received', 'assigned', 'driver_assigned',
  'en_route_pickup', 'loaded', 'en_route_delivery', 'arrived_delivery',
  'delivered', 'pod_confirmed', 'invoiced', 'paid', 'closed',
];

// How many trips to place in each stage. Weighted towards live and recently
// finished work so every screen has something to show.
const TRIP_MIX = [
  ['published', 18],
  ['offers_received', 8],
  ['assigned', 3],
  ['driver_assigned', 3],
  ['en_route_pickup', 2],
  ['loaded', 2],
  ['en_route_delivery', 3],
  ['arrived_delivery', 2],
  ['delivered', 4],
  ['pod_confirmed', 4],
  ['invoiced', 4],
  ['paid', 5],
  ['closed', 8],
  ['cancelled', 2],
  ['disputed', 2],
  ['draft', 2],
];

// ------------------------------------------------------------------ helpers

/// Fails fast if a hub's wilaya string drifts from the app's canonical list.
/// Trip locations and carrier operating zones are compared by exact string, so a
/// typo here would silently produce an empty marketplace rather than an error.
function assertWilayasAreCanonical() {
  const unknown = HUBS.map((h) => h.wilaya).filter((w) => !ALGERIA_WILAYAS.includes(w));
  if (unknown.length) {
    throw new Error(
      `Hub wilayas not found in the canonical list: ${unknown.join(', ')}
` +
        'They must match mobile_app/lib/core/constants/algeria_wilayas.dart exactly.'
    );
  }
}

const toRad = (d) => (d * Math.PI) / 180;
function distanceKm(a, b) {
  const R = 6371;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.asin(Math.sqrt(h));
}

/// Price roughly by distance and load, then rounded to a negotiable-looking
/// figure, so margin reports show plausible numbers.
function priceFor(pickup, dropoff, weightKg) {
  const km = Math.max(50, distanceKm(pickup, dropoff));
  const base = km * intBetween(90, 130);
  const weightFactor = 1 + (weightKg / 40000) * 0.35;
  return roundTo(base * weightFactor, 500);
}

/// A point along the route, used for the last known position of a moving truck.
function interpolate(a, b, ratio) {
  return {
    lat: Number((a.lat + (b.lat - a.lat) * ratio).toFixed(5)),
    lng: Number((a.lng + (b.lng - a.lng) * ratio).toFixed(5)),
  };
}

function plateFor(wilayaLabel) {
  const code = wilayaLabel.slice(0, 2);
  return `${intBetween(10000, 99999)}-${intBetween(100, 999)}-${code}`;
}

/// Builds the status history up to `target`, back-dated so the timeline reads
/// like a trip that actually progressed over time.
function buildHistory(target, actors, startedHoursAgo) {
  const endIndex = LIFECYCLE.indexOf(target);
  const stages = endIndex >= 0 ? LIFECYCLE.slice(0, endIndex + 1) : ['draft', 'published'];
  const step = startedHoursAgo / Math.max(stages.length, 1);

  const history = stages.map((status, i) => ({
    status,
    changedBy: actors[status] || actors.default,
    changedAt: hoursFromNow(-(startedHoursAgo - step * i)),
  }));

  // Exception states are appended after the normal run.
  if (target === 'cancelled' || target === 'disputed') {
    history.push({
      status: target,
      changedBy: actors.default,
      changedAt: hoursFromNow(-step / 2),
      note: target === 'cancelled' ? 'Annulé par le chargeur' : 'Litige ouvert',
    });
  }
  return history;
}

const reached = (status, stage) => {
  const a = LIFECYCLE.indexOf(status);
  const b = LIFECYCLE.indexOf(stage);
  return a >= 0 && b >= 0 && a >= b;
};

// --------------------------------------------------------------------- main

async function run() {
  const keep = process.argv.includes('--keep');

  assertWilayasAreCanonical();

  await connectDB();

  if (!keep) {
    console.log('Clearing existing data...');
    await Promise.all([
      User.deleteMany({}),
      Vehicle.deleteMany({}),
      Trip.deleteMany({}),
      Invoice.deleteMany({}),
      Dispute.deleteMany({}),
      Notification.deleteMany({}),
      AuditLog.deleteMany({}),
      Counter.deleteMany({}),
      Settings.deleteMany({}),
    ]);
  }

  const settings =
    (await Settings.findOne({ key: 'global' })) ||
    (await Settings.create({
      key: 'global',
      defaultCommissionPercent: 10,
      vatPercent: 19,
      returnLoadRadiusKm: 100,
      returnLoadWindowDays: 3,
      invoicePrefix: 'PP',
      referencePrices: [
        { fromWilaya: '16 - Alger', toWilaya: '31 - Oran', vehicleType: 'semi_trailer', pricePerTrip: 65000 },
        { fromWilaya: '16 - Alger', toWilaya: '25 - Constantine', vehicleType: 'flatbed', pricePerTrip: 58000 },
        { fromWilaya: '31 - Oran', toWilaya: '30 - Ouargla', vehicleType: 'tipper', pricePerTrip: 120000 },
        { fromWilaya: '16 - Alger', toWilaya: '19 - Sétif', vehicleType: 'closed', pricePerTrip: 42000 },
      ],
    }));

  // Phone numbers are allocated from one counter so they never collide. In
  // --keep mode, start past the highest generated number already stored,
  // otherwise a second run would clash with the first run's accounts.
  let phoneSeq = 0;
  if (keep) {
    const existing = await User.find({ phone: /^\+2135/ }).select('phone').lean();
    for (const u of existing) {
      const n = Number(u.phone.replace('+2135', ''));
      if (Number.isFinite(n) && n >= 10000000) phoneSeq = Math.max(phoneSeq, n - 10000000 + 1);
    }
  }
  const nextPhone = () => `+2135${String(10000000 + phoneSeq++).slice(-8)}`;

  // The fixed demo logins must survive a --keep run: reuse the existing account
  // rather than trying to insert a duplicate phone.
  async function upsertUser(fixedPhone, doc) {
    if (fixedPhone) {
      const existing = await User.findOne({ phone: fixedPhone });
      if (existing) return existing;
    }
    return User.create({ ...doc, phone: fixedPhone || doc.phone });
  }

  // ---------------------------------------------------------------- staff
  console.log('Creating admin team...');
  const admins = [];
  const adminSpec = [
    ['+213500000001', 'admin123', 'direction', 'Admin Prosim Planat'],
    ['+213500000010', 'demo123', 'exploitation', 'Nassim Exploitation'],
    ['+213500000011', 'demo123', 'facturation', 'Leila Facturation'],
    ['+213500000012', 'demo123', 'lecture', 'Consultation Lecture Seule'],
  ];
  for (const [phone, password, subRole, fullName] of adminSpec) {
    admins.push(
      await upsertUser(phone, {
        password,
        role: 'admin',
        adminSubRole: subRole,
        fullName,
        email: `${subRole}@prosimplanat.dz`,
        status: 'active',
        preferredLanguage: 'fr',
      })
    );
  }
  const admin = admins[0];

  // -------------------------------------------------------------- shippers
  const shipperCount = Number(process.env.DEMO_SHIPPERS) || SHIPPER_COMPANIES.length;
  console.log(`Creating ${shipperCount} shippers...`);

  const shippers = [];
  for (let i = 0; i < shipperCount; i++) {
    const [companyName, fullName, mainGoods] = SHIPPER_COMPANIES[i % SHIPPER_COMPANIES.length];
    const hub = HUBS[i % HUBS.length];
    // The first shipper keeps the well-known demo number/password.
    const isPrimary = i === 0;

    shippers.push(
      await upsertUser(isPrimary ? '+213500000002' : null, {
        phone: nextPhone(),
        password: 'demo123',
        role: 'shipper',
        fullName,
        companyName,
        email: `contact${i + 1}@${companyName.split(' ').pop().toLowerCase()}.dz`,
        taxId: `NIF-${String(1000 + i)}`,
        statisticalId: `NIS-${String(2000 + i)}`,
        tradeRegister: `RC-${String(3000 + i)}`,
        address: `Zone industrielle, ${hub.city}`,
        wilaya: hub.wilaya,
        contactPerson: fullName,
        bankAccount: `00${intBetween(100, 999)} ${intBetween(10000, 99999)} ${intBetween(10000, 99999)}`,
        preferredLanguage: pick(['fr', 'fr', 'ar', 'en']),
        // Two accounts stay pending so the admin approval queue is not empty.
        status: i === shipperCount - 1 ? 'pending' : 'active',
        rating: 0,
        ratingCount: 0,
        mainGoods,
      })
    );
  }

  // -------------------------------------------------------------- carriers
  const carrierCount = Number(process.env.DEMO_CARRIERS) || CARRIER_COMPANIES.length;
  console.log(`Creating ${carrierCount} carriers with fleets and drivers...`);

  const carriers = [];
  const vehiclesByCarrier = new Map();
  const driversByCarrier = new Map();
  let driverNameIndex = 0;

  for (let i = 0; i < carrierCount; i++) {
    const [companyName, fullName] = CARRIER_COMPANIES[i % CARRIER_COMPANIES.length];
    const base = HUBS[(i * 2) % HUBS.length];
    const isPrimary = i === 0;

    // Operating zones use the same wilaya strings as trips, which is what the
    // marketplace filter compares against.
    const operating = [
      base.wilaya,
      ...pickMany(HUBS.filter((h) => h !== base), 6).map((h) => h.wilaya),
    ];

    const carrier = await upsertUser(isPrimary ? '+213500000003' : null, {
      phone: nextPhone(),
      password: 'demo123',
      role: 'carrier',
      fullName,
      companyName,
      email: `contact@${companyName.split(' ')[0].toLowerCase()}.dz`,
      taxId: `NIF-${String(5000 + i)}`,
      statisticalId: `NIS-${String(6000 + i)}`,
      tradeRegister: `RC-${String(7000 + i)}`,
      address: `Route nationale, ${base.city}`,
      wilaya: base.wilaya,
      contactPerson: fullName,
      bankAccount: `00${intBetween(100, 999)} ${intBetween(10000, 99999)} ${intBetween(10000, 99999)}`,
      operatingWilayas: operating,
      operatingCorridors: [`${base.city} — ${pick(HUBS).city}`],
      preferredLanguage: pick(['fr', 'fr', 'ar']),
      status: i === carrierCount - 1 ? 'pending' : 'active',
      documents: [
        {
          type: 'tradeRegister',
          url: 'https://res.cloudinary.com/demo/image/upload/sample.pdf',
          // One carrier's paperwork expires soon, so the ADM-12 alert has content.
          expiresAt: i === 1 ? daysFromNow(18) : daysFromNow(intBetween(200, 900)),
        },
        {
          type: 'insurance',
          url: 'https://res.cloudinary.com/demo/image/upload/sample.pdf',
          expiresAt: i === 2 ? daysFromNow(9) : daysFromNow(intBetween(120, 700)),
        },
      ],
    });
    carriers.push(carrier);

    // Fleet
    const fleetSize = intBetween(2, 4);
    const fleet = [];
    for (let v = 0; v < fleetSize; v++) {
      const [brand, model, type, payload] = TRUCKS[(i * 3 + v) % TRUCKS.length];
      fleet.push(
        await Vehicle.create({
          carrierId: carrier._id,
          plateNumber: plateFor(base.wilaya),
          brand,
          model,
          type,
          payloadCapacityKg: payload,
          yearOfManufacture: intBetween(2012, 2024),
          status: 'available',
          documents: [
            {
              type: 'registration',
              url: 'https://res.cloudinary.com/demo/image/upload/sample.pdf',
              expiresAt: daysFromNow(intBetween(150, 800)),
            },
            {
              type: 'technical_inspection',
              url: 'https://res.cloudinary.com/demo/image/upload/sample.pdf',
              // A few inspections come due inside the 30-day alert window.
              expiresAt: v === 0 && i < 3 ? daysFromNow(intBetween(5, 25)) : daysFromNow(intBetween(90, 500)),
            },
          ],
        })
      );
    }
    vehiclesByCarrier.set(String(carrier._id), fleet);

    // Drivers
    const driverCount = Math.max(2, fleetSize - 1);
    const drivers = [];
    for (let d = 0; d < driverCount; d++) {
      const name = DRIVER_NAMES[driverNameIndex++ % DRIVER_NAMES.length];
      const isPrimaryDriver = isPrimary && d === 0;
      drivers.push(
        await upsertUser(isPrimaryDriver ? '+213500000004' : null, {
          // Drivers need a password of their own — an account without one can
          // never sign in.
          phone: nextPhone(),
          password: 'demo123',
          role: 'driver',
          fullName: name,
          carrierId: carrier._id,
          licenseNumber: `PL-${intBetween(10000, 99999)}`,
          licenseCategory: pick(['C', 'C+E', 'D']),
          // One licence per carrier expires soon for the document alerts.
          licenseExpiresAt: d === 0 ? daysFromNow(intBetween(10, 28)) : daysFromNow(intBetween(200, 1200)),
          preferredLanguage: pick(['ar', 'fr']),
          status: 'active',
        })
      );
    }
    driversByCarrier.set(String(carrier._id), drivers);
  }

  const activeShippers = shippers.filter((s) => s.status === 'active');
  const activeCarriers = carriers.filter((c) => c.status === 'active');

  // ----------------------------------------------------------------- trips
  const requestedTrips = Number(process.env.DEMO_TRIPS) || 0;
  const plan = [];
  for (const [status, count] of TRIP_MIX) {
    for (let i = 0; i < count; i++) plan.push(status);
  }
  // Interleave the stages so the mix stays representative even when DEMO_TRIPS
  // asks for fewer trips than the plan holds — taking a raw prefix of a grouped
  // plan would yield 12 'published' trips and nothing else.
  const interleaved = [];
  const buckets = TRIP_MIX.map(([status, count]) => ({ status, left: count }));
  while (buckets.some((b) => b.left > 0)) {
    for (const b of buckets) {
      if (b.left > 0) {
        interleaved.push(b.status);
        b.left -= 1;
      }
    }
  }
  const targets = requestedTrips
    ? Array.from({ length: requestedTrips }, (_, i) => interleaved[i % interleaved.length])
    : interleaved;

  console.log(`Creating ${targets.length} trips across the lifecycle...`);

  const year = new Date().getFullYear();
  // In --keep mode continue the existing numbering: `reference` and invoice
  // `number` are unique indexes, so restarting at 1 would collide.
  let tripSeq = keep ? await Trip.countDocuments({ reference: new RegExp(`^PP-${year}-`) }) : 0;
  const invoiceStart = keep
    ? await Invoice.countDocuments({ number: new RegExp(`-${year}-`) })
    : 0;
  const created = { trips: 0, invoices: 0, disputes: 0, notifications: 0 };
  const carrierRatings = new Map();

  for (const target of targets) {
    const shipper = pick(activeShippers);
    const [from, to] = pickMany(HUBS, 2);
    const goodsType = pick(Object.keys(GOODS_BY_TYPE));
    const vehicleTypeRequired = pick(VEHICLE_FOR_GOODS[goodsType]);
    const weightKg = roundTo(intBetween(3000, 38000), 500);
    const pricingMode = rand() < 0.45 ? 'fixed' : 'bidding';
    const startedHoursAgo = intBetween(6, 30 * 24);

    // Carrier is only involved once the trip has been awarded.
    const needsCarrier = reached(target, 'assigned') || target === 'disputed';
    const carrier = needsCarrier ? pick(activeCarriers) : null;
    const fleet = carrier ? vehiclesByCarrier.get(String(carrier._id)) : [];
    const crew = carrier ? driversByCarrier.get(String(carrier._id)) : [];
    const needsDriver = reached(target, 'driver_assigned') || target === 'disputed';
    const driver = needsDriver && crew.length ? pick(crew) : null;
    const vehicle = needsDriver && fleet.length
      ? pick(fleet.filter((v) => v.type === vehicleTypeRequired)) || pick(fleet)
      : null;

    const price = priceFor(from, to, weightKg);
    const agreedPrice = needsCarrier ? price : undefined;
    const commissionPercent = settings.defaultCommissionPercent;

    const actors = {
      default: shipper._id,
      draft: shipper._id,
      published: shipper._id,
      offers_received: carrier ? carrier._id : shipper._id,
      assigned: shipper._id,
      driver_assigned: carrier ? carrier._id : shipper._id,
      en_route_pickup: driver ? driver._id : shipper._id,
      loaded: driver ? driver._id : shipper._id,
      en_route_delivery: driver ? driver._id : shipper._id,
      arrived_delivery: driver ? driver._id : shipper._id,
      delivered: driver ? driver._id : shipper._id,
      pod_confirmed: shipper._id,
      invoiced: admin._id,
      paid: admin._id,
      closed: admin._id,
    };

    const reference = `PP-${year}-${String(++tripSeq).padStart(6, '0')}`;
    const statusHistory = buildHistory(target, actors, startedHoursAgo);

    // Offers: only for bidding trips that got far enough to attract them.
    const offers = [];
    if (pricingMode === 'bidding' && (target === 'offers_received' || reached(target, 'assigned'))) {
      const bidders = pickMany(activeCarriers, intBetween(2, Math.min(4, activeCarriers.length)));
      // The awarded carrier must be among the bidders.
      if (carrier && !bidders.some((b) => String(b._id) === String(carrier._id))) {
        bidders[0] = carrier;
      }
      for (const bidder of bidders) {
        const isWinner = carrier && String(bidder._id) === String(carrier._id);
        offers.push({
          carrierId: bidder._id,
          price: isWinner ? price : roundTo(price * (1 + (rand() * 0.3 - 0.1)), 500),
          validUntil: daysFromNow(intBetween(2, 10)),
          vehicleTypeProposed: vehicleTypeRequired,
          note: pick(['Disponible immédiatement', 'Camion bâché disponible', '', '']),
          status: reached(target, 'assigned')
            ? (isWinner ? 'accepted' : 'rejected')
            : 'pending',
          createdAt: hoursFromNow(-startedHoursAgo + 2),
        });
      }
    }

    // Live position for trucks that are actually moving.
    let lastKnownLocation;
    let trackingPings = [];
    if (['en_route_pickup', 'en_route_delivery', 'arrived_delivery'].includes(target)) {
      const ratio = target === 'en_route_pickup' ? 0.15 : target === 'arrived_delivery' ? 0.99 : 0.55;
      const here = interpolate(from, to, ratio);
      lastKnownLocation = { ...here, updatedAt: hoursFromNow(-intBetween(0, 2)) };
      trackingPings = Array.from({ length: 8 }, (_, i) => ({
        ...interpolate(from, to, (ratio * (i + 1)) / 8),
        timestamp: hoursFromNow(-(8 - i) * 2),
      }));
    } else if (reached(target, 'delivered') && target !== 'cancelled') {
      lastKnownLocation = { lat: to.lat, lng: to.lng, updatedAt: hoursFromNow(-intBetween(2, 40)) };
    }

    // Incidents on a slice of the in-flight and disputed trips.
    const incidentReports = [];
    if ((target === 'disputed' || rand() < 0.18) && driver && reached(target, 'en_route_pickup')) {
      const type = target === 'disputed' ? pick(['goods_refused', 'excessive_wait']) : pick(INCIDENT_TYPES);
      incidentReports.push({
        type,
        note: INCIDENT_NOTES[type],
        photos: [],
        reportedAt: hoursFromNow(-intBetween(1, 20)),
        reportedBy: driver._id,
      });
    }

    // Review once the goods arrived, on most (not all) finished trips.
    let review;
    if (reached(target, 'pod_confirmed') && rand() < 0.75) {
      const punctuality = intBetween(3, 5);
      const goodsCondition = intBetween(3, 5);
      const behavior = intBetween(4, 5);
      const rating = Math.round((punctuality + goodsCondition + behavior) / 3);
      review = {
        rating,
        punctuality,
        goodsCondition,
        behavior,
        comment: pick([
          'Livraison conforme, chauffeur professionnel.',
          'Bon service, léger retard au chargement.',
          'Marchandise en parfait état.',
          'Très bonne communication tout au long du trajet.',
          '',
        ]),
        createdAt: hoursFromNow(-intBetween(1, 48)),
      };
      if (carrier) {
        const acc = carrierRatings.get(String(carrier._id)) || { total: 0, count: 0 };
        acc.total += rating;
        acc.count += 1;
        carrierRatings.set(String(carrier._id), acc);
      }
    }

    const trip = await Trip.create({
      reference,
      shipperId: shipper._id,
      createdByAdmin: rand() < 0.12,
      createdBy: shipper._id,
      pickup: {
        address: `${pick(['Zone industrielle', 'Dépôt central', 'Entrepôt', 'Port sec'])}, ${from.city}`,
        wilaya: from.wilaya,
        lat: from.lat,
        lng: from.lng,
      },
      dropoff: {
        address: `${pick(['Chantier', 'Magasin central', 'Plateforme', 'Usine'])}, ${to.city}`,
        wilaya: to.wilaya,
        lat: to.lat,
        lng: to.lng,
      },
      goodsType,
      weightKg,
      volumeM3: roundTo(weightKg / intBetween(200, 400), 1),
      packageCount: intBetween(1, 33),
      specialInstructions: pick(INSTRUCTIONS),
      vehicleTypeRequired,
      pickupWindowStart: hoursFromNow(-startedHoursAgo + 12),
      pickupWindowEnd: hoursFromNow(-startedHoursAgo + 36),
      requestedDeliveryDate: hoursFromNow(-startedHoursAgo + intBetween(48, 120)),
      pricingMode,
      fixedPrice: pricingMode === 'fixed' ? price : undefined,
      status: target,
      statusHistory,
      offers,
      acceptedOfferId: undefined,
      assignedCarrierId: carrier ? carrier._id : undefined,
      assignedDriverId: driver ? driver._id : undefined,
      assignedVehicleId: vehicle ? vehicle._id : undefined,
      agreedPrice,
      commission: needsCarrier
        ? {
            mode: 'percent',
            value: commissionPercent,
            computedAmount: roundTo((agreedPrice * commissionPercent) / 100, 1),
          }
        : undefined,
      liveTrackingEnabled: ['en_route_pickup', 'en_route_delivery'].includes(target),
      lastKnownLocation,
      trackingPings,
      incidentReports,
      review,
      isReturnLoadMatch: rand() < 0.2,
    });

    // Link the accepted offer now that the subdocument has an _id.
    const winning = trip.offers.find((o) => o.status === 'accepted');
    if (winning) {
      trip.acceptedOfferId = winning._id;
      await trip.save();
    }

    // Vehicles on an active mission are not available.
    if (vehicle && ['driver_assigned', 'en_route_pickup', 'loaded', 'en_route_delivery', 'arrived_delivery'].includes(target)) {
      vehicle.status = 'on_mission';
      vehicle.assignedDriverId = driver._id;
      await vehicle.save();
    }

    created.trips += 1;

    // ------------------------------------------------------------ invoices
    if (reached(target, 'invoiced')) {
      const vatPercent = settings.vatPercent;
      const vatAmount = Number(((agreedPrice * vatPercent) / 100).toFixed(2));
      const totalAmount = Number((agreedPrice + vatAmount).toFixed(2));

      // Fully paid once the trip reached 'paid'; otherwise alternate between a
      // part payment and an untouched invoice, so the finance screen always
      // shows all three states rather than leaving it to chance.
      const settled = reached(target, 'paid');
      const partial = !settled && created.invoices % 2 === 0;
      const amountPaid = settled ? totalAmount : partial ? roundTo(totalAmount * 0.4, 100) : 0;

      const invoice = await Invoice.create({
        number: `${settings.invoicePrefix}-${year}-${String(invoiceStart + created.invoices + 1).padStart(6, '0')}`,
        tripId: trip._id,
        shipperId: shipper._id,
        carrierId: carrier._id,
        agreedAmount: agreedPrice,
        commissionAmount: trip.commission.computedAmount,
        vatPercent,
        vatAmount,
        totalAmount,
        amountPaid,
        balanceDue: Number((totalAmount - amountPaid).toFixed(2)),
        status: settled ? 'paid' : partial ? 'partially_paid' : 'issued',
        paymentMethod: amountPaid > 0 ? pick(['cash', 'bank_transfer', 'check']) : undefined,
        paymentDate: amountPaid > 0 ? hoursFromNow(-intBetween(1, 72)) : undefined,
        // Some open invoices are already overdue, so the reminders list fills up.
        dueDate: settled ? daysFromNow(-intBetween(1, 20)) : daysFromNow(pick([-12, -5, 4, 15])),
      });

      trip.invoiceId = invoice._id;
      await trip.save();
      created.invoices += 1;
    }

    // ------------------------------------------------------------ disputes
    if (target === 'disputed') {
      const reason = pick([
        'Marchandise partiellement refusée à la livraison',
        'Retard de livraison de plus de 48h',
        'Écart entre le poids annoncé et le poids constaté',
      ]);
      const dispute = await Dispute.create({
        tripId: trip._id,
        raisedBy: shipper._id,
        reason,
        status: pick(['open', 'in_review']),
        messages: [
          { senderId: shipper._id, text: reason, sentAt: hoursFromNow(-20) },
          {
            senderId: carrier._id,
            text: 'Nous vérifions avec le chauffeur et revenons vers vous.',
            sentAt: hoursFromNow(-14),
          },
        ],
      });
      trip.disputeId = dispute._id;
      await trip.save();
      created.disputes += 1;
    }

    // ------------------------------------------------------------- audit
    await AuditLog.create({
      actorId: shipper._id,
      actorRole: 'shipper',
      action: 'trip_created',
      tripId: trip._id,
      createdAt: statusHistory[0].changedAt,
    });
    if (needsCarrier) {
      await AuditLog.create({
        actorId: shipper._id,
        actorRole: 'shipper',
        action: 'trip_assigned',
        tripId: trip._id,
        metadata: { carrierId: carrier._id, price: agreedPrice },
        createdAt: hoursFromNow(-startedHoursAgo + 6),
      });
    }
  }

  // Apply the accumulated ratings to each carrier.
  for (const [carrierId, acc] of carrierRatings) {
    await User.updateOne(
      { _id: carrierId },
      { rating: Number((acc.total / acc.count).toFixed(2)), ratingCount: acc.count }
    );
  }

  // Keep the trip counter ahead of the seeded references, so the next trip
  // created through the API does not collide with one of these.
  await Counter.findOneAndUpdate(
    { key: `trip-${year}` },
    { $set: { seq: tripSeq } },
    { upsert: true }
  );
  await Settings.updateOne(
    { key: 'global' },
    { lastInvoiceSeq: invoiceStart + created.invoices }
  );

  // ------------------------------------------------------- notifications
  console.log('Creating notifications...');
  const recentTrips = await Trip.find().sort({ createdAt: -1 }).limit(25);
  for (const trip of recentTrips) {
    const targetsForTrip = [];
    if (trip.status === 'offers_received') {
      targetsForTrip.push([trip.shipperId, 'new_offer', 'Nouvelle offre reçue', `Nouvelle offre pour le trajet ${trip.reference}`, false]);
    }
    if (trip.assignedCarrierId && reached(trip.status, 'assigned')) {
      targetsForTrip.push([trip.assignedCarrierId, 'trip_assigned', 'Trajet attribué', `Le trajet ${trip.reference} vous a été attribué`, false]);
    }
    if (trip.assignedDriverId && reached(trip.status, 'driver_assigned')) {
      targetsForTrip.push([trip.assignedDriverId, 'trip_assigned', 'Nouvelle mission', `Mission ${trip.reference}: ${trip.pickup.wilaya} → ${trip.dropoff.wilaya}`, false]);
    }
    if (reached(trip.status, 'delivered')) {
      targetsForTrip.push([trip.shipperId, 'delivered', 'Livraison effectuée', `Le trajet ${trip.reference} a été livré`, false]);
    }
    if (trip.incidentReports?.length) {
      targetsForTrip.push([trip.shipperId, 'delay', 'Incident signalé', `Incident sur le trajet ${trip.reference}`, true]);
    }
    if (trip.status === 'invoiced') {
      targetsForTrip.push([trip.shipperId, 'payment_due', 'Facture émise', `Une facture est disponible pour ${trip.reference}`, true]);
    }

    for (const [userId, type, title, body, isCritical] of targetsForTrip) {
      await Notification.create({
        userId,
        type,
        title,
        body,
        tripId: trip._id,
        isCritical,
        // Leave a realistic slice unread so the bell shows a badge.
        read: rand() < 0.45,
        createdAt: hoursFromNow(-intBetween(1, 120)),
      });
      created.notifications += 1;
    }
  }

  // Account-status notifications for the pending accounts.
  for (const user of [...shippers, ...carriers].filter((u) => u.status === 'pending')) {
    await Notification.create({
      userId: user._id,
      type: 'account_status',
      title: 'Compte en attente',
      body: 'Votre compte est en cours de validation par l\'administration.',
      isCritical: true,
      read: false,
      createdAt: hoursFromNow(-intBetween(2, 48)),
    });
    created.notifications += 1;
  }

  // ------------------------------------------------------------- summary
  const counts = {
    users: await User.countDocuments(),
    shippers: await User.countDocuments({ role: 'shipper' }),
    carriers: await User.countDocuments({ role: 'carrier' }),
    drivers: await User.countDocuments({ role: 'driver' }),
    admins: await User.countDocuments({ role: 'admin' }),
    vehicles: await Vehicle.countDocuments(),
    trips: await Trip.countDocuments(),
    invoices: await Invoice.countDocuments(),
    disputes: await Dispute.countDocuments(),
    notifications: await Notification.countDocuments(),
    auditLogs: await AuditLog.countDocuments(),
  };

  const byStatus = await Trip.aggregate([
    { $group: { _id: '$status', n: { $sum: 1 } } },
    { $sort: { n: -1 } },
  ]);

  console.log('\n' + '='.repeat(56));
  console.log('  Demo data ready');
  console.log('='.repeat(56));
  console.log(`  Users .......... ${counts.users}  (${counts.admins} admin, ${counts.shippers} shippers, ${counts.carriers} carriers, ${counts.drivers} drivers)`);
  console.log(`  Vehicles ....... ${counts.vehicles}`);
  console.log(`  Trips .......... ${counts.trips}`);
  console.log(`  Invoices ....... ${counts.invoices}`);
  console.log(`  Disputes ....... ${counts.disputes}`);
  console.log(`  Notifications .. ${counts.notifications}`);
  console.log(`  Audit entries .. ${counts.auditLogs}`);
  console.log('\n  Trips by status:');
  for (const row of byStatus) {
    console.log(`    ${String(row._id).padEnd(18)} ${row.n}`);
  }
  console.log('\n  Logins (all passwords below):');
  console.log('    Admin (direction) .. +213500000001 / admin123');
  console.log('    Admin (exploitation) +213500000010 / demo123');
  console.log('    Admin (facturation)  +213500000011 / demo123');
  console.log('    Admin (read-only) .. +213500000012 / demo123');
  console.log('    Shipper ............ +213500000002 / demo123');
  console.log('    Carrier ............ +213500000003 / demo123');
  console.log('    Driver ............. +213500000004 / demo123');
  console.log('\n  Every other generated account also uses demo123.');
  console.log('='.repeat(56) + '\n');

  await mongoose.connection.close();
  process.exit(0);
}

run().catch(async (err) => {
  console.error('Seed failed:', err);
  try {
    await mongoose.connection.close();
  } catch (_) {
    // already closed
  }
  process.exit(1);
});
