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

  // Only the token verification belongs in the try: wrapping the checks below in it
  // rewrote every downstream failure (including the 403s) as "token failed".
  let decoded;
  try {
    decoded = jwt.verify(token, process.env.JWT_SECRET);
  } catch (err) {
    res.status(401);
    throw new Error('Not authorized, token failed');
  }

  const user = await User.findById(decoded.id);
  if (!user) {
    res.status(401);
    throw new Error('User not found');
  }
  if (user.status === 'blocked') {
    res.status(403);
    throw new Error('Account is blocked');
  }
  if (user.status === 'rejected') {
    res.status(403);
    throw new Error('Account was rejected');
  }

  req.user = user;
  next();
});

function allowRoles(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      res.status(403);
      return next(new Error('Forbidden: insufficient role'));
    }
    next();
  };
}

function allowAdminSubRoles(...subRoles) {
  return (req, res, next) => {
    if (!req.user || req.user.role !== 'admin') {
      res.status(403);
      return next(new Error('Forbidden'));
    }
    if (req.user.adminSubRole === 'direction') return next(); // direction sees all
    if (!subRoles.includes(req.user.adminSubRole)) {
      res.status(403);
      return next(new Error('Forbidden: insufficient admin sub-role'));
    }
    next();
  };
}

/// Blocks write actions for the read-only ("lecture") admin sub-role.
function denyReadOnlyAdmin(req, res, next) {
  if (req.user?.role === 'admin' && req.user.adminSubRole === 'lecture') {
    res.status(403);
    return next(new Error('Read-only administrator cannot perform this action'));
  }
  next();
}

module.exports = { protect, allowRoles, allowAdminSubRoles, denyReadOnlyAdmin };
