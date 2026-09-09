const jwt = require('jsonwebtoken');
const asyncHandler = require('express-async-handler');
const User = require('../models/User');

const protect = asyncHandler(async (req, res, next) => {
  let token;
  const authHeader = req.headers.authorization;

  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.split(' ')[1];
  }

  if (!token) {
    res.status(401);
    throw new Error('Not authorized, no token');
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = await User.findById(decoded.id);
    if (!req.user) {
      res.status(401);
      throw new Error('User not found');
    }
    if (req.user.status === 'blocked') {
      res.status(403);
      throw new Error('Account is blocked');
    }
    next();
  } catch (err) {
    res.status(401);
    throw new Error('Not authorized, token failed');
  }
});

function allowRoles(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      res.status(403);
      throw new Error('Forbidden: insufficient role');
    }
    next();
  };
}

function allowAdminSubRoles(...subRoles) {
  return (req, res, next) => {
    if (req.user.role !== 'admin') {
      res.status(403);
      throw new Error('Forbidden');
    }
    if (req.user.adminSubRole === 'direction') return next(); // direction sees all
    if (!subRoles.includes(req.user.adminSubRole)) {
      res.status(403);
      throw new Error('Forbidden: insufficient admin sub-role');
    }
    next();
  };
}

module.exports = { protect, allowRoles, allowAdminSubRoles };
