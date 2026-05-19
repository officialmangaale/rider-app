import 'dart:convert';

enum RiderSetupSection { kyc, vehicle, bank, location }

enum RiderDocumentSlot {
  nationalIdFront,
  nationalIdBack,
  drivingLicenseFront,
  drivingLicenseBack,
  rcDocument,
  insuranceDocument,
}

extension RiderDocumentSlotLabels on RiderDocumentSlot {
  String get label => switch (this) {
    RiderDocumentSlot.nationalIdFront => 'ID front',
    RiderDocumentSlot.nationalIdBack => 'ID back',
    RiderDocumentSlot.drivingLicenseFront => 'License front',
    RiderDocumentSlot.drivingLicenseBack => 'License back',
    RiderDocumentSlot.rcDocument => 'RC document',
    RiderDocumentSlot.insuranceDocument => 'Insurance',
  };

  RiderSetupSection get section => switch (this) {
    RiderDocumentSlot.nationalIdFront ||
    RiderDocumentSlot.nationalIdBack ||
    RiderDocumentSlot.drivingLicenseFront ||
    RiderDocumentSlot.drivingLicenseBack => RiderSetupSection.kyc,
    RiderDocumentSlot.rcDocument ||
    RiderDocumentSlot.insuranceDocument => RiderSetupSection.vehicle,
  };
}

class RiderComplianceDocuments {
  const RiderComplianceDocuments({
    this.nationalIdFrontUrl = '',
    this.nationalIdBackUrl = '',
    this.drivingLicenseFrontUrl = '',
    this.drivingLicenseBackUrl = '',
  });

  final String nationalIdFrontUrl;
  final String nationalIdBackUrl;
  final String drivingLicenseFrontUrl;
  final String drivingLicenseBackUrl;

  bool get isComplete =>
      nationalIdFrontUrl.isNotEmpty &&
      nationalIdBackUrl.isNotEmpty &&
      drivingLicenseFrontUrl.isNotEmpty &&
      drivingLicenseBackUrl.isNotEmpty;

  RiderComplianceDocuments copyWith({
    String? nationalIdFrontUrl,
    String? nationalIdBackUrl,
    String? drivingLicenseFrontUrl,
    String? drivingLicenseBackUrl,
  }) {
    return RiderComplianceDocuments(
      nationalIdFrontUrl: nationalIdFrontUrl ?? this.nationalIdFrontUrl,
      nationalIdBackUrl: nationalIdBackUrl ?? this.nationalIdBackUrl,
      drivingLicenseFrontUrl:
          drivingLicenseFrontUrl ?? this.drivingLicenseFrontUrl,
      drivingLicenseBackUrl:
          drivingLicenseBackUrl ?? this.drivingLicenseBackUrl,
    );
  }

  RiderComplianceDocuments withFallback(RiderComplianceDocuments fallback) {
    return RiderComplianceDocuments(
      nationalIdFrontUrl: _fallback(
        nationalIdFrontUrl,
        fallback.nationalIdFrontUrl,
      ),
      nationalIdBackUrl: _fallback(
        nationalIdBackUrl,
        fallback.nationalIdBackUrl,
      ),
      drivingLicenseFrontUrl: _fallback(
        drivingLicenseFrontUrl,
        fallback.drivingLicenseFrontUrl,
      ),
      drivingLicenseBackUrl: _fallback(
        drivingLicenseBackUrl,
        fallback.drivingLicenseBackUrl,
      ),
    );
  }

  String urlFor(RiderDocumentSlot slot) => switch (slot) {
    RiderDocumentSlot.nationalIdFront => nationalIdFrontUrl,
    RiderDocumentSlot.nationalIdBack => nationalIdBackUrl,
    RiderDocumentSlot.drivingLicenseFront => drivingLicenseFrontUrl,
    RiderDocumentSlot.drivingLicenseBack => drivingLicenseBackUrl,
    RiderDocumentSlot.rcDocument || RiderDocumentSlot.insuranceDocument => '',
  };

  RiderComplianceDocuments setUrl(RiderDocumentSlot slot, String url) {
    return switch (slot) {
      RiderDocumentSlot.nationalIdFront => copyWith(nationalIdFrontUrl: url),
      RiderDocumentSlot.nationalIdBack => copyWith(nationalIdBackUrl: url),
      RiderDocumentSlot.drivingLicenseFront => copyWith(
        drivingLicenseFrontUrl: url,
      ),
      RiderDocumentSlot.drivingLicenseBack => copyWith(
        drivingLicenseBackUrl: url,
      ),
      RiderDocumentSlot.rcDocument ||
      RiderDocumentSlot.insuranceDocument => this,
    };
  }

  static RiderComplianceDocuments fromJson(Map<String, dynamic> json) {
    return RiderComplianceDocuments(
      nationalIdFrontUrl: _asString(json['national_id_front_url']),
      nationalIdBackUrl: _asString(json['national_id_back_url']),
      drivingLicenseFrontUrl: _asString(json['driving_license_front_url']),
      drivingLicenseBackUrl: _asString(json['driving_license_back_url']),
    );
  }
}

class RiderVehicleCompliance {
  const RiderVehicleCompliance({
    this.vehicleType = '',
    this.make = '',
    this.model = '',
    this.year,
    this.registrationNumber = '',
    this.rcDocumentUrl = '',
    this.insuranceDocumentUrl = '',
  });

  final String vehicleType;
  final String make;
  final String model;
  final int? year;
  final String registrationNumber;
  final String rcDocumentUrl;
  final String insuranceDocumentUrl;

  bool get isComplete =>
      vehicleType.isNotEmpty &&
      make.isNotEmpty &&
      model.isNotEmpty &&
      year != null &&
      registrationNumber.isNotEmpty;

  RiderVehicleCompliance copyWith({
    String? vehicleType,
    String? make,
    String? model,
    int? year,
    bool clearYear = false,
    String? registrationNumber,
    String? rcDocumentUrl,
    String? insuranceDocumentUrl,
  }) {
    return RiderVehicleCompliance(
      vehicleType: vehicleType ?? this.vehicleType,
      make: make ?? this.make,
      model: model ?? this.model,
      year: clearYear ? null : year ?? this.year,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      rcDocumentUrl: rcDocumentUrl ?? this.rcDocumentUrl,
      insuranceDocumentUrl: insuranceDocumentUrl ?? this.insuranceDocumentUrl,
    );
  }

  RiderVehicleCompliance withFallback(RiderVehicleCompliance fallback) {
    return RiderVehicleCompliance(
      vehicleType: _fallback(vehicleType, fallback.vehicleType),
      make: _fallback(make, fallback.make),
      model: _fallback(model, fallback.model),
      year: year ?? fallback.year,
      registrationNumber: _fallback(
        registrationNumber,
        fallback.registrationNumber,
      ),
      rcDocumentUrl: _fallback(rcDocumentUrl, fallback.rcDocumentUrl),
      insuranceDocumentUrl: _fallback(
        insuranceDocumentUrl,
        fallback.insuranceDocumentUrl,
      ),
    );
  }

  String urlFor(RiderDocumentSlot slot) => switch (slot) {
    RiderDocumentSlot.rcDocument => rcDocumentUrl,
    RiderDocumentSlot.insuranceDocument => insuranceDocumentUrl,
    RiderDocumentSlot.nationalIdFront ||
    RiderDocumentSlot.nationalIdBack ||
    RiderDocumentSlot.drivingLicenseFront ||
    RiderDocumentSlot.drivingLicenseBack => '',
  };

  RiderVehicleCompliance setUrl(RiderDocumentSlot slot, String url) {
    return switch (slot) {
      RiderDocumentSlot.rcDocument => copyWith(rcDocumentUrl: url),
      RiderDocumentSlot.insuranceDocument => copyWith(
        insuranceDocumentUrl: url,
      ),
      RiderDocumentSlot.nationalIdFront ||
      RiderDocumentSlot.nationalIdBack ||
      RiderDocumentSlot.drivingLicenseFront ||
      RiderDocumentSlot.drivingLicenseBack => this,
    };
  }
}

class RiderBankCompliance {
  const RiderBankCompliance({
    this.accountHolderName = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.bankName = '',
    this.branchName = '',
  });

  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final String branchName;

  bool get isComplete =>
      accountHolderName.isNotEmpty &&
      accountNumber.isNotEmpty &&
      ifscCode.isNotEmpty &&
      bankName.isNotEmpty;

  String get maskedAccountNumber {
    if (accountNumber.isEmpty) {
      return 'Not added';
    }
    if (accountNumber.contains('X') ||
        accountNumber.contains('x') ||
        accountNumber.contains('*')) {
      return accountNumber;
    }
    final suffix = accountNumber.length <= 4
        ? accountNumber
        : accountNumber.substring(accountNumber.length - 4);
    return '**** $suffix';
  }

  RiderBankCompliance copyWith({
    String? accountHolderName,
    String? accountNumber,
    String? ifscCode,
    String? bankName,
    String? branchName,
  }) {
    return RiderBankCompliance(
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      bankName: bankName ?? this.bankName,
      branchName: branchName ?? this.branchName,
    );
  }

  RiderBankCompliance withFallback(RiderBankCompliance fallback) {
    return RiderBankCompliance(
      accountHolderName: _fallback(
        accountHolderName,
        fallback.accountHolderName,
      ),
      accountNumber: _fallback(accountNumber, fallback.accountNumber),
      ifscCode: _fallback(ifscCode, fallback.ifscCode),
      bankName: _fallback(bankName, fallback.bankName),
      branchName: _fallback(branchName, fallback.branchName),
    );
  }
}

class RiderComplianceProfile {
  const RiderComplianceProfile({
    this.id = '',
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.email = '',
    this.status = '',
    this.kycVerified = false,
    this.licenseNumber = '',
    this.nationalIdType = '',
    this.nationalIdNumber = '',
    this.documents = const RiderComplianceDocuments(),
    this.vehicle = const RiderVehicleCompliance(),
    this.bank = const RiderBankCompliance(),
    this.mode = '',
    this.linkedRestaurantCount = 0,
    this.isAvailable = false,
    this.onTrip = false,
    this.currentLat,
    this.currentLng,
    this.lastLocationUpdate,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String status;
  final bool kycVerified;
  final String licenseNumber;
  final String nationalIdType;
  final String nationalIdNumber;
  final RiderComplianceDocuments documents;
  final RiderVehicleCompliance vehicle;
  final RiderBankCompliance bank;
  final String mode;
  final int linkedRestaurantCount;
  final bool isAvailable;
  final bool onTrip;
  final double? currentLat;
  final double? currentLng;
  final DateTime? lastLocationUpdate;

  String get displayName {
    final fullName = [
      firstName,
      lastName,
    ].where((part) => part.trim().isNotEmpty).join(' ').trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }
    if (email.contains('@')) {
      return email.split('@').first;
    }
    return 'Rider';
  }

  String get kycStatusLabel {
    if (kycVerified) {
      return 'Verified';
    }
    if (isKycComplete) {
      return 'Pending verification';
    }
    return 'Incomplete';
  }

  bool get isKycComplete =>
      kycVerified ||
      (licenseNumber.isNotEmpty &&
          nationalIdType.isNotEmpty &&
          nationalIdNumber.isNotEmpty &&
          documents.isComplete);

  bool get hasLocationSnapshot =>
      currentLat != null && currentLng != null && lastLocationUpdate != null;

  bool get isRestaurantLinked =>
      _normalize(mode) == 'restaurant_owned' || linkedRestaurantCount > 0;

  String get riderTypeLabel =>
      isRestaurantLinked ? 'Restaurant-linked rider' : 'Self-signup rider';

  int completedSections({required bool locationReady}) {
    return [
      isKycComplete,
      vehicle.isComplete,
      bank.isComplete,
      locationReady || hasLocationSnapshot,
    ].where((value) => value).length;
  }

  double progress({required bool locationReady}) {
    return completedSections(locationReady: locationReady) / 4;
  }

  List<String> missingItems({
    required bool locationReady,
    bool includeLocation = true,
  }) {
    return [
      if (!isKycComplete) 'KYC verification',
      if (!vehicle.isComplete) 'Vehicle details',
      if (!bank.isComplete) 'Bank details',
      if (includeLocation && !(locationReady || hasLocationSnapshot))
        'Location tracking',
    ];
  }

  RiderComplianceProfile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? status,
    bool? kycVerified,
    String? licenseNumber,
    String? nationalIdType,
    String? nationalIdNumber,
    RiderComplianceDocuments? documents,
    RiderVehicleCompliance? vehicle,
    RiderBankCompliance? bank,
    String? mode,
    int? linkedRestaurantCount,
    bool? isAvailable,
    bool? onTrip,
    double? currentLat,
    bool clearCurrentLat = false,
    double? currentLng,
    bool clearCurrentLng = false,
    DateTime? lastLocationUpdate,
    bool clearLastLocationUpdate = false,
  }) {
    return RiderComplianceProfile(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      status: status ?? this.status,
      kycVerified: kycVerified ?? this.kycVerified,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      nationalIdType: nationalIdType ?? this.nationalIdType,
      nationalIdNumber: nationalIdNumber ?? this.nationalIdNumber,
      documents: documents ?? this.documents,
      vehicle: vehicle ?? this.vehicle,
      bank: bank ?? this.bank,
      mode: mode ?? this.mode,
      linkedRestaurantCount:
          linkedRestaurantCount ?? this.linkedRestaurantCount,
      isAvailable: isAvailable ?? this.isAvailable,
      onTrip: onTrip ?? this.onTrip,
      currentLat: clearCurrentLat ? null : currentLat ?? this.currentLat,
      currentLng: clearCurrentLng ? null : currentLng ?? this.currentLng,
      lastLocationUpdate: clearLastLocationUpdate
          ? null
          : lastLocationUpdate ?? this.lastLocationUpdate,
    );
  }

  RiderComplianceProfile withFallback(RiderComplianceProfile fallback) {
    return RiderComplianceProfile(
      id: _fallback(id, fallback.id),
      firstName: _fallback(firstName, fallback.firstName),
      lastName: _fallback(lastName, fallback.lastName),
      phone: _fallback(phone, fallback.phone),
      email: _fallback(email, fallback.email),
      status: _fallback(status, fallback.status),
      kycVerified: kycVerified || fallback.kycVerified,
      licenseNumber: _fallback(licenseNumber, fallback.licenseNumber),
      nationalIdType: _fallback(nationalIdType, fallback.nationalIdType),
      nationalIdNumber: _fallback(nationalIdNumber, fallback.nationalIdNumber),
      documents: documents.withFallback(fallback.documents),
      vehicle: vehicle.withFallback(fallback.vehicle),
      bank: bank.withFallback(fallback.bank),
      mode: _fallback(mode, fallback.mode),
      linkedRestaurantCount: linkedRestaurantCount > 0
          ? linkedRestaurantCount
          : fallback.linkedRestaurantCount,
      isAvailable: isAvailable,
      onTrip: onTrip,
      currentLat: currentLat ?? fallback.currentLat,
      currentLng: currentLng ?? fallback.currentLng,
      lastLocationUpdate: lastLocationUpdate ?? fallback.lastLocationUpdate,
    );
  }

  RiderComplianceProfile setDocumentUrl(RiderDocumentSlot slot, String url) {
    return switch (slot.section) {
      RiderSetupSection.kyc => copyWith(documents: documents.setUrl(slot, url)),
      RiderSetupSection.vehicle => copyWith(vehicle: vehicle.setUrl(slot, url)),
      RiderSetupSection.bank || RiderSetupSection.location => this,
    };
  }

  static RiderComplianceProfile fromJson(Map<String, dynamic> json) {
    final user = _readMap(json['user']);
    final rider = _readMap(json['rider']);
    final source = <String, dynamic>{...json, ...rider};
    final kycData = _readMap(source['kyc_data']);
    final verificationDocs = _documentsFrom(source, json['documents']);
    final vehicleData = _readMap(json['vehicle']);
    final vehicleDetails = _readMap(source['vehicle_details']);
    final insuranceDetails = _readMap(source['insurance_details']);
    final linkedRestaurants = _readList(
      _firstPresent([
        json['linked_restaurants'],
        json['restaurants'],
        json['assigned_restaurants'],
        rider['linked_restaurants'],
      ]),
    );
    final bankData = _readMap(
      _firstPresent([source['bank_details'], json['bank_account']]),
    );
    final kycStatus = _normalize(
      _asString(_firstPresent([source['kyc_status'], rider['kyc_status']])),
    );

    return RiderComplianceProfile(
      id: _asString(_firstPresent([source['id'], rider['id']])),
      firstName: _asString(
        _firstPresent([source['first_name'], user['first_name']]),
      ),
      lastName: _asString(
        _firstPresent([source['last_name'], user['last_name']]),
      ),
      phone: _asString(_firstPresent([source['phone'], user['phone']])),
      email: _asString(_firstPresent([source['email'], user['email']])),
      status: _asString(_firstPresent([source['status'], rider['status']])),
      kycVerified: _asBool(source['kyc_verified']) ?? kycStatus == 'approved',
      licenseNumber: _asString(
        _firstPresent([
          source['license_number'],
          source['driving_license_number'],
          kycData['license_number'],
          kycData['driving_license_number'],
        ]),
      ),
      nationalIdType: _asString(kycData['national_id_type']),
      nationalIdNumber: _asString(kycData['national_id_number']),
      documents: verificationDocs,
      vehicle: RiderVehicleCompliance(
        vehicleType: _asString(
          _firstPresent([
            source['vehicle_type'],
            vehicleData['vehicle_type'],
            vehicleDetails['vehicle_type'],
          ]),
        ),
        make: _asString(
          _firstPresent([vehicleDetails['make'], vehicleData['make']]),
        ),
        model: _asString(
          _firstPresent([vehicleDetails['model'], vehicleData['model']]),
        ),
        year: _asInt(
          _firstPresent([vehicleDetails['year'], vehicleData['year']]),
        ),
        registrationNumber: _asString(
          _firstPresent([
            source['vehicle_registration_number'],
            source['vehicle_number'],
            source['registration_number'],
            source['registration_no'],
            vehicleData['registration_number'],
            vehicleData['registration_no'],
            vehicleData['vehicle_number'],
          ]),
        ),
        rcDocumentUrl: _asString(
          _firstPresent([
            vehicleDetails['rc_document_url'],
            vehicleData['rc_document_url'],
          ]),
        ),
        insuranceDocumentUrl: _asString(
          _firstPresent([
            insuranceDetails['insurance_document_url'],
            vehicleDetails['insurance_document_url'],
            vehicleData['insurance_document_url'],
          ]),
        ),
      ),
      bank: RiderBankCompliance(
        accountHolderName: _asString(
          _firstPresent([
            bankData['account_holder_name'],
            bankData['account_holder'],
          ]),
        ),
        accountNumber: _asString(
          _firstPresent([
            bankData['account_number'],
            bankData['masked_account_number'],
          ]),
        ),
        ifscCode: _asString(bankData['ifsc_code']),
        bankName: _asString(bankData['bank_name']),
        branchName: _asString(bankData['branch_name']),
      ),
      mode: _asString(_firstPresent([source['mode'], json['mode']])),
      linkedRestaurantCount: linkedRestaurants.length,
      isAvailable: _asBool(source['is_available']) ?? false,
      onTrip: _asBool(source['on_trip']) ?? false,
      currentLat: _asDoubleOrNull(source['current_lat']),
      currentLng: _asDoubleOrNull(source['current_lng']),
      lastLocationUpdate: _asDateTime(source['last_location_update']),
    );
  }

  static RiderComplianceDocuments _documentsFrom(
    Map<String, dynamic> source,
    Object? documentsList,
  ) {
    final docs = _readMap(source['verification_docs']);
    if (docs.isNotEmpty) {
      return RiderComplianceDocuments.fromJson(docs);
    }

    var result = const RiderComplianceDocuments();
    if (documentsList is List) {
      for (final item in documentsList) {
        final doc = _readMap(item);
        final type = _normalize(_asString(doc['document_type']));
        final url = _asString(doc['document_url']);
        if (url.isEmpty) {
          continue;
        }
        if (type.contains('aadhaar') ||
            type.contains('aadhar') ||
            type.contains('national')) {
          result = result.copyWith(nationalIdFrontUrl: url);
        }
        if (type.contains('driving') || type.contains('license')) {
          result = result.copyWith(drivingLicenseFrontUrl: url);
        }
      }
    }
    return result;
  }
}

String _fallback(String value, String fallback) =>
    value.trim().isEmpty ? fallback : value.trim();

String _normalize(String value) =>
    value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

Object? _firstPresent(List<Object?> values) {
  for (final value in values) {
    if (value == null) {
      continue;
    }
    if (value is String && value.trim().isEmpty) {
      continue;
    }
    return value;
  }
  return null;
}

String _asString(Object? value) {
  if (value == null) {
    return '';
  }
  return '$value'.trim();
}

bool? _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'approved' ||
        normalized == 'verified') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no' ||
        normalized == 'pending' ||
        normalized == 'rejected') {
      return false;
    }
  }
  return null;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

double? _asDoubleOrNull(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}

DateTime? _asDateTime(Object? value) {
  if (value is DateTime) {
    return value.toLocal();
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim())?.toLocal();
  }
  return null;
}

Map<String, dynamic> _readMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', value));
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {
      return const <String, dynamic>{};
    }
  }
  return const <String, dynamic>{};
}

List<dynamic> _readList(Object? value) {
  if (value is List) {
    return value;
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded;
      }
    } catch (_) {
      return const <dynamic>[];
    }
  }
  return const <dynamic>[];
}
