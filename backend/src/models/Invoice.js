const mongoose = require('mongoose');
const { Schema } = mongoose;

const invoiceSchema = new Schema(
  {
    number: { type: String, unique: true, required: true }, // sequential, matches numbering scheme
    tripId: { type: Schema.Types.ObjectId, ref: 'Trip', required: true },
    shipperId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    carrierId: { type: Schema.Types.ObjectId, ref: 'User' },

    agreedAmount: { type: Number, required: true },
    deposit: { type: Number, default: 0 },
    amountPaid: { type: Number, default: 0 },
    balanceDue: { type: Number, default: 0 },

    commissionAmount: { type: Number, required: true },
    vatPercent: { type: Number, default: 19 },
    vatAmount: { type: Number, default: 0 },
    totalAmount: { type: Number, required: true },

    paymentMethod: { type: String, enum: ['cash', 'bank_transfer', 'check', 'cod'] },
    paymentDate: Date,
    receiptUrl: String,

    status: {
      type: String,
      enum: ['draft', 'issued', 'partially_paid', 'paid', 'overdue'],
      default: 'issued',
    },

    pdfUrl: String,
    pdfPublicId: String,

    dueDate: Date,
    reminderSentAt: [Date],
  },
  { timestamps: true }
);

module.exports = mongoose.model('Invoice', invoiceSchema);
