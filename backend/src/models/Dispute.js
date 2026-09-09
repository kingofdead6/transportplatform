const mongoose = require('mongoose');
const { Schema } = mongoose;

const disputeSchema = new Schema(
  {
    tripId: { type: Schema.Types.ObjectId, ref: 'Trip', required: true },
    raisedBy: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    reason: String,
    status: { type: String, enum: ['open', 'in_review', 'resolved', 'closed'], default: 'open' },
    messages: [
      {
        senderId: { type: Schema.Types.ObjectId, ref: 'User' },
        text: String,
        attachments: [{ url: String, publicId: String }],
        sentAt: { type: Date, default: Date.now },
      },
    ],
    resolution: String,
    resolvedBy: { type: Schema.Types.ObjectId, ref: 'User' },
    resolvedAt: Date,
  },
  { timestamps: true }
);

module.exports = mongoose.model('Dispute', disputeSchema);
