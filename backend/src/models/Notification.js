const mongoose = require('mongoose');
const { Schema } = mongoose;

const NOTIFICATION_TYPES = [
  'new_offer',
  'trip_assigned',
  'loaded',
  'delivered',
  'delay',
  'document_expiring',
  'payment_due',
  'return_load_available',
  'dispute_update',
  'account_status',
  'message',
];

const notificationSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    type: { type: String, enum: NOTIFICATION_TYPES, required: true },
    title: String,
    body: String,
    tripId: { type: Schema.Types.ObjectId, ref: 'Trip' },
    isCritical: { type: Boolean, default: false }, // critical notifications cannot be muted
    read: { type: Boolean, default: false },
    createdAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Notification', notificationSchema);
module.exports.NOTIFICATION_TYPES = NOTIFICATION_TYPES;
