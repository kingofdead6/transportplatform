const mongoose = require('mongoose');
const { Schema } = mongoose;

// ADM-21: single-document platform settings
const settingsSchema = new Schema(
  {
    key: { type: String, default: 'global', unique: true },
    defaultCommissionPercent: { type: Number, default: 10 },
    returnLoadRadiusKm: { type: Number, default: 100 },
    returnLoadWindowDays: { type: Number, default: 3 },
    vatPercent: { type: Number, default: 19 },
    invoicePrefix: { type: String, default: 'PP' },
    lastInvoiceSeq: { type: Number, default: 0 },
    referencePrices: [
      {
        fromWilaya: String,
        toWilaya: String,
        vehicleType: String,
        pricePerTrip: Number,
      },
    ],
  },
  { timestamps: true }
);

module.exports = mongoose.model('Settings', settingsSchema);
