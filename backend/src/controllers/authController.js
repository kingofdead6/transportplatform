const asyncHandler = require('express-async-handler');
const crypto = require('crypto');
const User = require('../models/User');
const generateToken = require('../utils/generateToken');
const { logAction } = require('../utils/audit');

// In-memory OTP store (demo). Replace with Redis/SMS gateway in production.
const otpStore = new Map(); // phone -> { code, expiresAt }

function generateOtp() {
  return String(crypto.randomInt(100000, 999999));
}

// @desc Request an OTP code for phone-based login (EXP-01 / CHA-01)
// @route POST /api/auth/request-otp
const requestOtp = asyncHandler(async (req, res) => {
  const { phone } = req.body;
  if (!phone) {
    res.status(400);
    throw new Error('Phone number required');
  }
  const code = generateOtp();
  otpStore.set(phone, { code, expiresAt: Date.now() + 5 * 60 * 1000 });

  // In production, send via SMS gateway. For dev, we return it directly.
  console.log(`[otp] ${phone} -> ${code}`);
  res.json({ message: 'OTP sent', devCode: process.env.NODE_ENV !== 'production' ? code : undefined });
});

// @desc Verify OTP and log in or create account
// @route POST /api/auth/verify-otp
const verifyOtp = asyncHandler(async (req, res) => {
  const { phone, code, role } = req.body;
  const entry = otpStore.get(phone);

  if (!entry || entry.code !== code || entry.expiresAt < Date.now()) {
    res.status(400);
    throw new Error('Invalid or expired code');
  }
  otpStore.delete(phone);

  let user = await User.findOne({ phone });
  if (!user) {
    if (!role) {
      res.status(400);
      throw new Error('Role required for new account');
    }
    user = await User.create({
      phone,
      role,
      status: role === 'driver' || role === 'admin' ? 'active' : 'pending', // shipper/carrier need admin approval (EXP-04)
    });
    await logAction({ actorId: user._id, actorRole: role, action: 'account_created' });
  }

  if (user.status === 'blocked') {
    res.status(403);
    throw new Error('Account is blocked');
  }

  res.json({
    token: generateToken(user._id, user.role),
    user: user.toSafeJSON(),
  });
});

// @desc Admin/staff login with password
// @route POST /api/auth/login
const login = asyncHandler(async (req, res) => {
  const { phone, password } = req.body;
  const user = await User.findOne({ phone }).select('+password');
  if (!user || !user.password || !(await user.comparePassword(password))) {
    res.status(401);
    throw new Error('Invalid credentials');
  }
  if (user.status === 'blocked') {
    res.status(403);
    throw new Error('Account is blocked');
  }
  res.json({ token: generateToken(user._id, user.role), user: user.toSafeJSON() });
});

// @desc Get current user profile
// @route GET /api/auth/me
const getMe = asyncHandler(async (req, res) => {
  res.json(req.user.toSafeJSON());
});

module.exports = { requestOtp, verifyOtp, login, getMe };
