const mongoose = require('mongoose');
const { Schema } = mongoose;

// Atomic sequence generator. Trip references were derived from countDocuments(),
// which races under concurrent creation and produces duplicate references that
// the unique index then rejects.
const counterSchema = new Schema({
  key: { type: String, required: true, unique: true },
  seq: { type: Number, default: 0 },
});

module.exports = mongoose.model('Counter', counterSchema);
