class AppUser {
  AppUser({
    required this.id,
    required this.phone,
    required this.role,
    this.adminSubRole,
    this.fullName,
    this.email,
    this.preferredLanguage = 'fr',
    this.companyName,
    this.taxId,
    this.statisticalId,
    this.tradeRegister,
    this.address,
    this.wilaya,
    this.contactPerson,
    this.bankAccount,
    this.status = 'pending',
    this.rating = 0,
    this.ratingCount = 0,
    this.operatingWilayas = const [],
    this.licenseNumber,
    this.licenseCategory,
  });

  final String id;
  final String phone;
  final String role; // shipper | carrier | driver | admin
  final String? adminSubRole;
  final String? fullName;
  final String? email;
  final String preferredLanguage;
  final String? companyName;
  final String? taxId;
  final String? statisticalId;
  final String? tradeRegister;
  final String? address;
  final String? wilaya;
  final String? contactPerson;
  final String? bankAccount;
  final String status; // pending | active | blocked | rejected
  final double rating;
  final int ratingCount;
  final List<String> operatingWilayas;
  final String? licenseNumber;
  final String? licenseCategory;

  String get displayName => (companyName?.isNotEmpty ?? false) ? companyName! : (fullName ?? phone);

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['_id'] ?? json['id'],
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      adminSubRole: json['adminSubRole'],
      fullName: json['fullName'],
      email: json['email'],
      preferredLanguage: json['preferredLanguage'] ?? 'fr',
      companyName: json['companyName'],
      taxId: json['taxId'],
      statisticalId: json['statisticalId'],
      tradeRegister: json['tradeRegister'],
      address: json['address'],
      wilaya: json['wilaya'],
      contactPerson: json['contactPerson'],
      bankAccount: json['bankAccount'],
      status: json['status'] ?? 'pending',
      rating: (json['rating'] ?? 0).toDouble(),
      ratingCount: json['ratingCount'] ?? 0,
      operatingWilayas: List<String>.from(json['operatingWilayas'] ?? const []),
      licenseNumber: json['licenseNumber'],
      licenseCategory: json['licenseCategory'],
    );
  }
}
