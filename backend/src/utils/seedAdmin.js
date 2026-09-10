require('dotenv').config();
const mongoose = require('mongoose');
const connectDB = require('../config/db');
const User = require('../models/User');

// Safe, non-destructive: only creates/updates the admin account, touches nothing else.
// Override via env vars if you don't want the defaults: ADMIN_PHONE, ADMIN_PASSWORD, ADMIN_NAME.
async function run() {
  await connectDB();

  const phone = process.env.ADMIN_PHONE || '+213500000001';
  const password = process.env.ADMIN_PASSWORD || 'admin123';
  const fullName = process.env.ADMIN_NAME || 'Admin Prosim Planat';

  let admin = await User.findOne({ phone });

  if (admin) {
    admin.password = password;
    admin.role = 'admin';
    admin.adminSubRole = admin.adminSubRole || 'direction';
    admin.status = 'active';
    if (!admin.fullName) admin.fullName = fullName;
    await admin.save();
    console.log(`Admin account updated: ${phone}`);
  } else {
    admin = await User.create({
      phone,
      password,
      role: 'admin',
      adminSubRole: 'direction',
      fullName,
      status: 'active',
    });
    console.log(`Admin account created: ${phone}`);
  }

  console.log(`Login: ${phone} / ${password}`);

  await mongoose.connection.close();
  process.exit(0);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
