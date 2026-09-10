const mongoose = require('mongoose');
const { Schema } = mongoose;

// Section 6.1 — dourat hayat al-rihla (trip lifecycle)
const TRIP_STATUSES = [
  'draft', // مسودة
  'published', // منشورة
  'offers_received', // عروض مستلمة
  'assigned', // مسندة
  'driver_assigned', // تعيين السائق
  'en_route_pickup', // في الطريق إلى التحميل
  'loaded', // تم التحميل
  'en_route_delivery', // في الطريق
  'arrived_delivery', // وصلت إلى التفريغ
  'delivered', // تم التسليم
  'pod_confirmed', // وصل التسليم مصادق عليه
  'invoiced', // مفوترة
  'paid', // مدفوعة
  'closed', // مقفلة
  // exceptions
  'cancelled',
  'disputed',
  'suspended',
];

const GOODS_TYPES = [
  'bulk',
  'palletized',
  'construction',
  'food',
  'hazardous',
  'machinery',
  'other',
];

const statusHistorySchema = new Schema(
  {
    status: { type: String, enum: TRIP_STATUSES, required: true },
    changedBy: { type: Schema.Types.ObjectId, ref: 'User' },
    changedAt: { type: Date, default: Date.now },
    note: String,
    location: { lat: Number, lng: Number },
  },
  { _id: false }
);

const offerSchema = new Schema(
  {
    carrierId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    price: { type: Number, required: true },
    validUntil: Date,
    vehicleTypeProposed: String,
    note: String,
    status: {
      type: String,
      enum: ['pending', 'accepted', 'rejected', 'expired'],
      default: 'pending',
    },
    createdAt: { type: Date, default: Date.now },
  },
  { _id: true }
);

const tripSchema = new Schema(
  {
    reference: { type: String, unique: true, required: true }, // e.g. PP-2026-000123

    shipperId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    createdByAdmin: { type: Boolean, default: false }, // ADM-02 phone-in creation
    createdBy: { type: Schema.Types.ObjectId, ref: 'User' },

    pickup: {
      address: String,
      wilaya: String,
      lat: Number,
      lng: Number,
    },
    dropoff: {
      address: String,
      wilaya: String,
      lat: Number,
      lng: Number,
    },

    goodsType: { type: String, enum: GOODS_TYPES, required: true },
    weightKg: Number,
    volumeM3: Number,
    packageCount: Number,
    exceptionalDimensions: String,

    vehicleTypeRequired: {
      type: String,
      enum: [
        'flatbed',
        'tipper',
        'semi_trailer',
        'car_carrier',
        'refrigerated',
        'tanker',
        'closed',
      ],
      required: true,
    },

    pickupWindowStart: Date,
    pickupWindowEnd: Date,
    requestedDeliveryDate: Date,

    pricingMode: { type: String, enum: ['fixed', 'bidding'], required: true },
    fixedPrice: Number,

    photos: [{ url: String, publicId: String }],
    attachedDocs: [{ url: String, publicId: String, label: String }],
    specialInstructions: String,

    status: { type: String, enum: TRIP_STATUSES, default: 'draft' },
    statusHistory: [statusHistorySchema],

    offers: [offerSchema],
    acceptedOfferId: Schema.Types.ObjectId,

    assignedCarrierId: { type: Schema.Types.ObjectId, ref: 'User' },
    assignedDriverId: { type: Schema.Types.ObjectId, ref: 'User' },
    assignedVehicleId: { type: Schema.Types.ObjectId, ref: 'Vehicle' },

    agreedPrice: Number,
    commission: {
      mode: { type: String, enum: ['fixed', 'percent', 'margin'], default: 'percent' },
      value: Number, // amount or percent
      computedAmount: Number,
    },

    isReturnLoadMatch: { type: Boolean, default: false },
    returnLoadForTripId: { type: Schema.Types.ObjectId, ref: 'Trip' },

    liveTrackingEnabled: { type: Boolean, default: false },
    lastKnownLocation: { lat: Number, lng: Number, updatedAt: Date },
    trackingPings: [{ lat: Number, lng: Number, timestamp: { type: Date, default: Date.now } }],

    documentsIds: [{ type: Schema.Types.ObjectId, ref: 'Document' }],
    invoiceId: { type: Schema.Types.ObjectId, ref: 'Invoice' },

    review: {
      rating: Number,
      punctuality: Number,
      goodsCondition: Number,
      behavior: Number,
      comment: String,
      createdAt: Date,
    },

    disputeId: { type: Schema.Types.ObjectId, ref: 'Dispute' },

    incidentReports: [
      {
        type: {
          type: String,
          enum: ['breakdown', 'accident', 'road_blocked', 'goods_refused', 'excessive_wait'],
        },
        note: String,
        photos: [String],
        reportedAt: { type: Date, default: Date.now },
        reportedBy: { type: Schema.Types.ObjectId, ref: 'User' },
      },
    ],
  },
  { timestamps: true }
);

tripSchema.index({ status: 1 });
tripSchema.index({ shipperId: 1 });
tripSchema.index({ assignedCarrierId: 1 });
tripSchema.index({ 'pickup.wilaya': 1, 'dropoff.wilaya': 1 });
tripSchema.index({ assignedDriverId: 1 });
tripSchema.index({ assignedVehicleId: 1 });
tripSchema.index({ createdAt: -1 });

module.exports = mongoose.model('Trip', tripSchema);
module.exports.TRIP_STATUSES = TRIP_STATUSES;
module.exports.GOODS_TYPES = GOODS_TYPES;
