const mongoose = require('mongoose');
const { Schema } = mongoose;

const VEHICLE_TYPES = [
  'flatbed', // مسطحة
  'tipper', // قلابة
  'semi_trailer', // نصف مقطورة
  'car_carrier', // حاملة آليات
  'refrigerated', // مبردة
  'tanker', // صهريج
  'closed', // مغلقة
];

const vehicleSchema = new Schema(
  {
    carrierId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    plateNumber: { type: String, required: true, trim: true },
    brand: String,
    model: String,
    type: { type: String, enum: VEHICLE_TYPES, required: true },
    payloadCapacityKg: Number,
    yearOfManufacture: Number,
    photos: [{ url: String, publicId: String }],

    documents: [
      {
        type: { type: String, enum: ['registration', 'insurance', 'technical_inspection'] },
        url: String,
        publicId: String,
        expiresAt: Date,
        uploadedAt: { type: Date, default: Date.now },
      },
    ],

    status: {
      type: String,
      enum: ['available', 'on_mission', 'broken_down', 'maintenance'],
      default: 'available',
    },

    assignedDriverId: { type: Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Vehicle', vehicleSchema);
module.exports.VEHICLE_TYPES = VEHICLE_TYPES;
