const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const { Schema } = mongoose;

const USER_ROLES = ['shipper', 'carrier', 'driver', 'admin'];
const ADMIN_SUBROLES = ['direction', 'exploitation', 'facturation', 'lecture'];

const userSchema = new Schema(
  {
    phone: { type: String, required: true, unique: true, trim: true },
    password: { type: String, select: false },
    role: { type: String, enum: USER_ROLES, required: true },
    adminSubRole: { type: String, enum: ADMIN_SUBROLES },

    fullName: { type: String, trim: true },
    email: { type: String, trim: true, lowercase: true },
    preferredLanguage: { type: String, enum: ['ar', 'fr', 'en'], default: 'fr' },

    // Company info (shipper & carrier)
    companyName: { type: String, trim: true },
    taxId: { type: String, trim: true }, // NIF
    statisticalId: { type: String, trim: true }, // NIS
    tradeRegister: { type: String, trim: true }, // RC
    address: { type: String, trim: true },
    wilaya: { type: String, trim: true },
    contactPerson: { type: String, trim: true },
    bankAccount: { type: String, trim: true },

    documents: [
      {
        type: { type: String }, // tradeRegister, taxCard, license, insurance...
        url: String,
        publicId: String,
        uploadedAt: { type: Date, default: Date.now },
        expiresAt: Date,
      },
    ],

    // Driver-specific
    licenseNumber: { type: String, trim: true },
    licenseCategory: { type: String, trim: true },
    licenseExpiresAt: Date,
    carrierId: { type: Schema.Types.ObjectId, ref: 'User' }, // driver belongs to a carrier

    // Carrier operating zones
    operatingWilayas: [String],
    operatingCorridors: [String],

    status: {
      type: String,
      enum: ['pending', 'active', 'blocked', 'rejected'],
      default: 'pending',
    },
    rating: { type: Number, default: 0 },
    ratingCount: { type: Number, default: 0 },

    lastKnownLocation: {
      lat: Number,
      lng: Number,
      updatedAt: Date,
    },

    fcmTokens: [String],
  },
  { timestamps: true }
);

userSchema.pre('save', async function hashPassword(next) {
  if (!this.isModified('password') || !this.password) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

userSchema.methods.comparePassword = function comparePassword(candidate) {
  return bcrypt.compare(candidate, this.password);
};

userSchema.methods.toSafeJSON = function toSafeJSON() {
  const obj = this.toObject();
  delete obj.password;
  return obj;
};

module.exports = mongoose.model('User', userSchema);
module.exports.USER_ROLES = USER_ROLES;
module.exports.ADMIN_SUBROLES = ADMIN_SUBROLES;
