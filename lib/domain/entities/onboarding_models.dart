class KycPayload {
  const KycPayload({
    required this.drivingLicenseNumber,
    required this.drivingLicenseFrontUrl,
    required this.drivingLicenseBackUrl,
    required this.nationalIdType,
    required this.nationalIdNumber,
    required this.nationalIdFrontUrl,
    required this.nationalIdBackUrl,
  });

  final String drivingLicenseNumber;
  final String drivingLicenseFrontUrl;
  final String drivingLicenseBackUrl;
  final String nationalIdType;
  final String nationalIdNumber;
  final String nationalIdFrontUrl;
  final String nationalIdBackUrl;

  Map<String, dynamic> toJson() => {
        'driving_license_number': drivingLicenseNumber,
        'driving_license_front_url': drivingLicenseFrontUrl,
        'driving_license_back_url': drivingLicenseBackUrl,
        'national_id_type': nationalIdType,
        'national_id_number': nationalIdNumber,
        'national_id_front_url': nationalIdFrontUrl,
        'national_id_back_url': nationalIdBackUrl,
      };
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

  Map<String, dynamic> toJson() => {
        'vehicle_type': vehicleType,
        'make': make,
        'model': model,
        'year': year,
        'registration_number': registrationNumber,
        'rc_document_url': rcDocumentUrl,
        'insurance_document_url': insuranceDocumentUrl,
      };
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
      completedSteps: (json['completed_steps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      pendingSteps: (json['pending_steps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rejectionReason: json['rejection_reason'] as String?,
      isReadyToRide: json['is_ready_to_ride'] as bool? ?? false,
    );
  }
}
