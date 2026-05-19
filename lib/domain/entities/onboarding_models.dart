class KycPayload {
  const KycPayload({
    this.firstName,
    this.lastName,
    this.phone,
    this.email,
    required this.licenseNumber,
    required this.drivingLicenseFrontUrl,
    required this.drivingLicenseBackUrl,
    required this.nationalIdType,
    required this.nationalIdNumber,
    required this.nationalIdFrontUrl,
    required this.nationalIdBackUrl,
  });

  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? email;
  final String licenseNumber;
  final String drivingLicenseFrontUrl;
  final String drivingLicenseBackUrl;
  final String nationalIdType;
  final String nationalIdNumber;
  final String nationalIdFrontUrl;
  final String nationalIdBackUrl;

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'driving_license_number': licenseNumber,
      'license_number': licenseNumber,
      'driving_license_front_url': drivingLicenseFrontUrl,
      'driving_license_back_url': drivingLicenseBackUrl,
      'national_id_type': nationalIdType,
      'national_id_number': nationalIdNumber,
      'national_id_front_url': nationalIdFrontUrl,
      'national_id_back_url': nationalIdBackUrl,
    };
    _putIfNotBlank(payload, 'first_name', firstName);
    _putIfNotBlank(payload, 'last_name', lastName);
    _putIfNotBlank(payload, 'phone', phone);
    _putIfNotBlank(payload, 'email', email);
    return payload;
  }
}

class VehiclePayload {
  const VehiclePayload({
    required this.vehicleType,
    required this.make,
    required this.model,
    required this.year,
    required this.registrationNumber,
    required this.rcDocumentUrl,
    required this.insuranceDocumentUrl,
  });

  final String vehicleType;
  final String make;
  final String model;
  final int year;
  final String registrationNumber;
  final String rcDocumentUrl;
  final String insuranceDocumentUrl;

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'vehicle_type': vehicleType,
      'make': make,
      'model': model,
      'year': year,
      'registration_number': registrationNumber,
      'registration_no': registrationNumber,
      'vehicle_number': registrationNumber,
    };
    _putIfNotBlank(payload, 'rc_document_url', rcDocumentUrl);
    _putIfNotBlank(payload, 'insurance_document_url', insuranceDocumentUrl);
    return payload;
  }
}

class BankDetailsPayload {
  const BankDetailsPayload({
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifscCode,
    required this.bankName,
    required this.branchName,
  });

  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final String branchName;

  Map<String, dynamic> toJson() => {
    'account_holder_name': accountHolderName,
    'account_number': accountNumber,
    'ifsc_code': ifscCode,
    'bank_name': bankName,
    'branch_name': branchName,
  };
}

void _putIfNotBlank(Map<String, dynamic> payload, String key, String? value) {
  final trimmed = value?.trim();
  if (trimmed != null && trimmed.isNotEmpty) {
    payload[key] = trimmed;
  }
}

class OnboardingStatusInfo {
  const OnboardingStatusInfo({
    required this.currentStatus,
    required this.completedSteps,
    required this.pendingSteps,
    this.rejectionReason,
    required this.isReadyToRide,
  });

  final String currentStatus;
  final List<String> completedSteps;
  final List<String> pendingSteps;
  final String? rejectionReason;
  final bool isReadyToRide;

  factory OnboardingStatusInfo.fromJson(Map<String, dynamic> json) {
    return OnboardingStatusInfo(
      currentStatus: json['current_status'] as String? ?? 'pending',
      completedSteps:
          (json['completed_steps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      pendingSteps:
          (json['pending_steps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rejectionReason: json['rejection_reason'] as String?,
      isReadyToRide: json['is_ready_to_ride'] as bool? ?? false,
    );
  }
}
