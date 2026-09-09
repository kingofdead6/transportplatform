const Settings = require('../models/Settings');

async function nextInvoiceNumber() {
  const settings = await Settings.findOneAndUpdate(
    { key: 'global' },
    { $inc: { lastInvoiceSeq: 1 } },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );
  const year = new Date().getFullYear();
  const seq = String(settings.lastInvoiceSeq).padStart(6, '0');
  return `${settings.invoicePrefix}-${year}-${seq}`;
}

module.exports = { nextInvoiceNumber };
