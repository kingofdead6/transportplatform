const cloudinary = require('cloudinary').v2;
const multer = require('multer');

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// Minimal custom multer storage engine that streams directly to Cloudinary,
// avoiding the unmaintained multer-storage-cloudinary package (pinned to Cloudinary v1).
class CloudinaryStorageEngine {
  constructor({ folder, resourceType = 'auto' }) {
    this.folder = folder;
    this.resourceType = resourceType;
  }

  _handleFile(req, file, cb) {
    const uploadStream = cloudinary.uploader.upload_stream(
      { folder: `prosim-planat/${this.folder}`, resource_type: this.resourceType },
      (err, result) => {
        if (err) return cb(err);
        cb(null, {
          path: result.secure_url,
          filename: result.public_id,
          size: result.bytes,
          mimetype: file.mimetype,
        });
      }
    );
    file.stream.pipe(uploadStream);
  }

  _removeFile(req, file, cb) {
    cloudinary.uploader.destroy(file.filename, { resource_type: this.resourceType }).then(
      () => cb(null),
      (err) => cb(err)
    );
  }
}

function makeUploader(folder, resourceType = 'auto') {
  const storage = new CloudinaryStorageEngine({ folder, resourceType });
  return multer({ storage, limits: { fileSize: 15 * 1024 * 1024 } });
}

module.exports = { cloudinary, makeUploader };
