require('dotenv').config();
const mongoose = require('mongoose');
const connectDB = require('../config/db');
const User = require('../models/User');
const Vehicle = require('../models/Vehicle');
const Settings = require('../models/Settings');
const Trip = require('../models/Trip');

async function run() {
  await connectDB();

  await Promise.all([
    User.deleteMany({}),
    Vehicle.deleteMany({}),
    Settings.deleteMany({}),
    Trip.deleteMany({}),
  ]);

  await Settings.create({ key: 'global' });

  const admin = await User.create({
    phone: '+213500000001',
    password: 'admin123',
    role: 'admin',
    adminSubRole: 'direction',
    fullName: 'Admin Prosim Planat',
    status: 'active',
  });

  const shipper = await User.create({
    phone: '+213500000002',
    password: 'demo123',
    role: 'shipper',
    fullName: 'Sassi Karim',
    companyName: 'SARL Karim Matériaux',
    taxId: 'NIF-0001',
    tradeRegister: 'RC-0001',
    wilaya: 'Oran',
    address: 'Zone industrielle, Oran',
    status: 'active',
  });

  const carrier = await User.create({
    phone: '+213500000003',
    password: 'demo123',
    role: 'carrier',
    fullName: 'Boudiaf Transport',
    companyName: 'Boudiaf Transport SARL',
    taxId: 'NIF-0002',
    tradeRegister: 'RC-0002',
    wilaya: 'Tindouf',
    operatingWilayas: ['Oran', 'Tindouf', 'Bechar'],
    status: 'active',
  });

  const driver = await User.create({
    phone: '+213500000004',
    password: 'demo123',
    role: 'driver',
    fullName: 'Ahmed Chauffeur',
    carrierId: carrier._id,
    licenseNumber: 'PL-12345',
    licenseCategory: 'Poids lourd',
    licenseExpiresAt: new Date('2027-01-01'),
    status: 'active',
  });

  const vehicle = await Vehicle.create({
    carrierId: carrier._id,
    plateNumber: '12345-115-31',
    brand: 'Mercedes',
    model: 'Actros',
    type: 'tipper',
    payloadCapacityKg: 40000,
    yearOfManufacture: 2019,
    status: 'available',
    assignedDriverId: driver._id,
  });

  await Trip.create({
    reference: 'PP-2026-000001',
    shipperId: shipper._id,
    pickup: { address: 'Zone industrielle', wilaya: 'Oran', lat: 35.6971, lng: -0.6337 },
    dropoff: { address: 'Centre ville', wilaya: 'Tindouf', lat: 27.6742, lng: -8.1476 },
    goodsType: 'construction',
    weightKg: 40000,
    vehicleTypeRequired: 'tipper',
    pricingMode: 'bidding',
    status: 'published',
    statusHistory: [{ status: 'draft' }, { status: 'published' }],
  });

  console.log('Seed complete.');
  console.log('Admin login: +213500000001 / admin123');
  console.log('Shipper: +213500000002 / demo123');
  console.log('Carrier: +213500000003 / demo123');
  console.log('Driver:  +213500000004 / demo123');

  await mongoose.connection.close();
  process.exit(0);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
