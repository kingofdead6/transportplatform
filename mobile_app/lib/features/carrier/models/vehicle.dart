/// Mirrors backend Vehicle model (no dedicated core model exists yet, so this
/// lives under the carrier feature — only carrier screens use it).
class VehicleDoc {
  VehicleDoc({required this.type, this.expiresAt, this.url});

  final String type; // registration | insurance | technical_inspection
  final DateTime? expiresAt;
  final String? url;

  factory VehicleDoc.fromJson(Map<String, dynamic> json) => VehicleDoc(
        type: json['type'] ?? '',
        expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt']) : null,
        url: json['url'],
      );
}

class Vehicle {
  Vehicle({
    required this.id,
    required this.plateNumber,
    this.brand,
    this.model,
    required this.type,
    this.payloadCapacityKg,
    this.yearOfManufacture,
    this.status = 'available',
    this.documents = const [],
  });

  final String id;
  final String plateNumber;
  final String? brand;
  final String? model;
  final String type;
  final double? payloadCapacityKg;
  final int? yearOfManufacture;
  final String status; // available | on_mission | broken_down | maintenance
  final List<VehicleDoc> documents;

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['_id'] ?? json['id'] ?? '',
        plateNumber: json['plateNumber'] ?? '',
        brand: json['brand'],
        model: json['model'],
        type: json['type'] ?? 'flatbed',
        payloadCapacityKg: (json['payloadCapacityKg'] as num?)?.toDouble(),
        yearOfManufacture: json['yearOfManufacture'] is int
            ? json['yearOfManufacture']
            : int.tryParse('${json['yearOfManufacture'] ?? ''}'),
        status: json['status'] ?? 'available',
        documents: (json['documents'] as List? ?? []).map((d) => VehicleDoc.fromJson(d)).toList(),
      );

  /// Nearest document expiry across all uploaded docs, if any.
  DateTime? get nearestExpiry {
    final dates = documents.map((d) => d.expiresAt).whereType<DateTime>().toList();
    if (dates.isEmpty) return null;
    dates.sort();
    return dates.first;
  }
}

/// Mirrors backend Driver (a user with role=driver, created/owned by a carrier).
class CarrierDriver {
  CarrierDriver({
    required this.id,
    this.fullName,
    required this.phone,
    this.licenseNumber,
    this.licenseCategory,
    this.licenseExpiresAt,
    this.status = 'pending',
  });

  final String id;
  final String? fullName;
  final String phone;
  final String? licenseNumber;
  final String? licenseCategory;
  final DateTime? licenseExpiresAt;
  final String status;

  factory CarrierDriver.fromJson(Map<String, dynamic> json) => CarrierDriver(
        id: json['_id'] ?? json['id'] ?? '',
        fullName: json['fullName'],
        phone: json['phone'] ?? '',
        licenseNumber: json['licenseNumber'],
        licenseCategory: json['licenseCategory'],
        licenseExpiresAt:
            json['licenseExpiresAt'] != null ? DateTime.tryParse(json['licenseExpiresAt']) : null,
        status: json['status'] ?? 'pending',
      );
}

/// True when [date] is within [days] days from now (or already past).
bool isExpiringSoon(DateTime? date, {int days = 30}) {
  if (date == null) return false;
  final diff = date.difference(DateTime.now()).inDays;
  return diff <= days;
}

bool isExpired(DateTime? date) {
  if (date == null) return false;
  return date.isBefore(DateTime.now());
}
