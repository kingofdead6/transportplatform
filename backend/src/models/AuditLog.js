const mongoose = require('mongoose');
const { Schema } = mongoose;

// ADM-20: sejjel tadqiq — who did what, when, on which trip
const auditLogSchema = new Schema(
  {
    actorId: { type: Schema.Types.ObjectId, ref: 'User' },
    actorRole: String,
    action: { type: String, required: true },
    tripId: { type: Schema.Types.ObjectId, ref: 'Trip' },
    targetType: String,
    targetId: Schema.Types.ObjectId,
    metadata: Schema.Types.Mixed,
    createdAt: { type: Date, default: Date.now },
  },
  { timestamps: false }
);

auditLogSchema.index({ tripId: 1 });
auditLogSchema.index({ createdAt: -1 });

module.exports = mongoose.model('AuditLog', auditLogSchema);
