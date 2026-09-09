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

  factory Trip.fromJson(Map<String, dynamic> json) {
    String? popName(dynamic v) {
      if (v is Map) return v['companyName'] ?? v['fullName'];
      return null;
    }

    String? popId(dynamic v) {
      if (v is Map) return v['_id'];
      return v as String?;
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
      lastKnownLocation: TripLocation.fromJson(json['lastKnownLocation']),
      specialInstructions: json['specialInstructions'],
      commissionAmount: (json['commission']?['computedAmount'] as num?)?.toDouble(),
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
