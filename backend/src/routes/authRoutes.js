const express = require('express');
const { requestOtp, verifyOtp, login, getMe } = require('../controllers/authController');
const { protect } = require('../middleware/authMiddleware');

const router = express.Router();

router.post('/request-otp', requestOtp);
router.post('/verify-otp', verifyOtp);
router.post('/login', login);
router.get('/me', protect, getMe);

module.exports = router;
