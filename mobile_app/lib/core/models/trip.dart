/// Mirrors backend Trip model / section 6.1 lifecycle.
class TripLocation {
  TripLocation({this.address, this.wilaya, this.lat, this.lng});

  final String? address;
  final String? wilaya;
  final double? lat;
  final double? lng;

  factory TripLocation.fromJson(Map<String, dynamic>? json) {
    if (json == null) return TripLocation();
    return TripLocation(
      address: json['address'],
      wilaya: json['wilaya'],
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'address': address, 'wilaya': wilaya, 'lat': lat, 'lng': lng};
}

class TripOffer {
  TripOffer({
    required this.id,
    required this.carrierId,
    required this.price,
    this.validUntil,
    this.vehicleTypeProposed,
    this.note,
    this.status = 'pending',
  });

  final String id;
  final String carrierId;
  final double price;
  final DateTime? validUntil;
  final String? vehicleTypeProposed;
  final String? note;
  final String status;

  factory TripOffer.fromJson(Map<String, dynamic> json) => TripOffer(
        id: json['_id'] ?? '',
        carrierId: json['carrierId'] is Map ? json['carrierId']['_id'] : json['carrierId'],
        price: (json['price'] as num).toDouble(),
        validUntil: json['validUntil'] != null ? DateTime.tryParse(json['validUntil']) : null,
        vehicleTypeProposed: json['vehicleTypeProposed'],
        note: json['note'],
        status: json['status'] ?? 'pending',
      );
}

/// An incident filed by the driver or carrier during a mission (CHA-10).
/// The backend field is `incidentReports`; reading `incidents` returned nothing.
class TripIncident {
  TripIncident({required this.type, this.note, this.reportedAt, this.photos = const []});

  final String type;
  final String? note;
  final DateTime? reportedAt;
  final List<String> photos;

  factory TripIncident.fromJson(Map<String, dynamic> json) => TripIncident(
        type: json['type'] ?? '',
        note: json['note'],
        reportedAt: json['reportedAt'] != null ? DateTime.tryParse(json['reportedAt']) : null,
        photos: (json['photos'] as List? ?? []).map((e) => e.toString()).toList(),
      );
}

class Trip {
  Trip({
    required this.id,
    required this.reference,
    required this.status,
    required this.pickup,
    required this.dropoff,
    this.goodsType,
    this.weightKg,
    this.vehicleTypeRequired,
    this.pricingMode = 'fixed',
    this.fixedPrice,
    this.agreedPrice,
    this.offers = const [],
    this.assignedCarrierId,
    this.assignedDriverId,
    this.assignedVehicleId,
    this.shipperName,
    this.carrierName,
    this.driverName,
    this.createdAt,
    this.pickupWindowStart,
    this.requestedDeliveryDate,
    this.lastKnownLocation,
    this.specialInstructions,
    this.commissionAmount,
    this.shipperPhone,
    this.carrierPhone,
    this.driverPhone,
    this.hasReview = false,
    this.incidents = const [],
    this.invoiceId,
    this.disputeId,
  });

  final String id;
  final String reference;
  final String status;
  final TripLocation pickup;
  final TripLocation dropoff;
  final String? goodsType;
  final double? weightKg;
  final String? vehicleTypeRequired;
  final String pricingMode;
  final double? fixedPrice;
  final double? agreedPrice;
  final List<TripOffer> offers;
  final String? assignedCarrierId;
  final String? assignedDriverId;
  final String? assignedVehicleId;
  final String? shipperName;
  final String? carrierName;
  final String? driverName;
  final DateTime? createdAt;
  final DateTime? pickupWindowStart;
  final DateTime? requestedDeliveryDate;
  final TripLocation? lastKnownLocation;
  final String? specialInstructions;
  final double? commissionAmount;

  /// Contact numbers come from the populated shipper/carrier/driver documents.
  /// Without these the driver's "call shipper" action had no number to dial.
  final String? shipperPhone;
  final String? carrierPhone;
  final String? driverPhone;

  final bool hasReview;
  final List<TripIncident> incidents;
  final String? invoiceId;
  final String? disputeId;

  factory Trip.fromJson(Map<String, dynamic> json) {
    String? popName(dynamic v) {
      if (v is Map) return v['companyName'] ?? v['fullName'];
      return null;
    }

    String? popId(dynamic v) {
      if (v is Map) return v['_id'] as String?;
      return v as String?;
    }

    String? popPhone(dynamic v) {
      if (v is Map) return v['phone'] as String?;
      return null;
    }

    // A missing/empty location object must stay null so callers can tell
    // "no position reported yet" from a real coordinate.
    TripLocation? optionalLocation(dynamic v) {
      if (v is! Map) return null;
      if (v['lat'] == null || v['lng'] == null) return null;
      return TripLocation.fromJson(Map<String, dynamic>.from(v));
    }

    return Trip(
      id: json['_id'] ?? '',
      reference: json['reference'] ?? '',
      status: json['status'] ?? 'draft',
      pickup: TripLocation.fromJson(json['pickup']),
      dropoff: TripLocation.fromJson(json['dropoff']),
      goodsType: json['goodsType'],
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      vehicleTypeRequired: json['vehicleTypeRequired'],
      pricingMode: json['pricingMode'] ?? 'fixed',
      fixedPrice: (json['fixedPrice'] as num?)?.toDouble(),
      agreedPrice: (json['agreedPrice'] as num?)?.toDouble(),
      offers: (json['offers'] as List? ?? []).map((o) => TripOffer.fromJson(o)).toList(),
      assignedCarrierId: popId(json['assignedCarrierId']),
      assignedDriverId: popId(json['assignedDriverId']),
      assignedVehicleId: popId(json['assignedVehicleId']),
      shipperName: popName(json['shipperId']),
      carrierName: popName(json['assignedCarrierId']),
      driverName: json['assignedDriverId'] is Map ? json['assignedDriverId']['fullName'] : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      pickupWindowStart:
          json['pickupWindowStart'] != null ? DateTime.tryParse(json['pickupWindowStart']) : null,
      requestedDeliveryDate: json['requestedDeliveryDate'] != null
          ? DateTime.tryParse(json['requestedDeliveryDate'])
          : null,
      lastKnownLocation: optionalLocation(json['lastKnownLocation']),
      specialInstructions: json['specialInstructions'],
      commissionAmount: (json['commission']?['computedAmount'] as num?)?.toDouble(),
      shipperPhone: popPhone(json['shipperId']),
      carrierPhone: popPhone(json['assignedCarrierId']),
      driverPhone: popPhone(json['assignedDriverId']),
      hasReview: json['review']?['createdAt'] != null,
      incidents: (json['incidentReports'] as List? ?? [])
          .map((e) => TripIncident.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      invoiceId: popId(json['invoiceId']),
      disputeId: popId(json['disputeId']),
    );
  }
}

/// Section 6.1 ordered lifecycle — index defines display order on progress trackers.
const List<String> tripLifecycleOrder = [
  'draft',
  'published',
  'offers_received',
  'assigned',
  'driver_assigned',
  'en_route_pickup',
  'loaded',
  'en_route_delivery',
  'arrived_delivery',
  'delivered',
  'pod_confirmed',
  'invoiced',
  'paid',
  'closed',
];

const List<String> vehicleTypes = [
  'flatbed',
  'tipper',
  'semi_trailer',
  'car_carrier',
  'refrigerated',
  'tanker',
  'closed',
];

const List<String> goodsTypes = [
  'bulk',
  'palletized',
  'construction',
  'food',
  'hazardous',
  'machinery',
  'other',
];
