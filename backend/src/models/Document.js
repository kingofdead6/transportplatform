const mongoose = require('mongoose');
const { Schema } = mongoose;

// Section 6.3 table
const DOCUMENT_TYPES = [
  'bon_transport', // وصل النقل - system, at assignment
  'bon_livraison', // وصل التسليم - system
  'bon_reception', // وصل الاستلام - signed at dropoff
  'pod', // إثبات التسليم - driver photos + signature
  'facture', // الفاتورة - admin, numbered
  'vehicle_doc', // وثائق الشاحنة
  'driver_doc', // وثائق السائق
  'goods_photo', // صور البضاعة
];

const documentSchema = new Schema(
  {
    tripId: { type: Schema.Types.ObjectId, ref: 'Trip', required: true },
    type: { type: String, enum: DOCUMENT_TYPES, required: true },
    url: { type: String, required: true },
    publicId: String,
    format: { type: String, default: 'pdf' },
    generatedBy: { type: Schema.Types.ObjectId, ref: 'User' },
    signature: {
      signedByName: String,
      signatureImageUrl: String,
      signedAt: Date,
    },
    number: String, // sequential number for factures
    createdAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Document', documentSchema);
module.exports.DOCUMENT_TYPES = DOCUMENT_TYPES;
