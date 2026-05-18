import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/router/app_routes.dart';
import '../../domain/entities/onboarding_models.dart';
import '../../domain/entities/rider_compliance_models.dart';
import 'core_providers.dart';
import 'profile_provider.dart';

final riderComplianceControllerProvider =
    AsyncNotifierProvider<RiderComplianceController, RiderComplianceState>(
      RiderComplianceController.new,
    );

class RiderComplianceState {
  const RiderComplianceState({
    required this.profile,
    this.savingSections = const <RiderSetupSection>{},
    this.uploadProgress = const <RiderDocumentSlot, double>{},
    this.sectionErrors = const <RiderSetupSection, String>{},
    this.sectionSuccess = const <RiderSetupSection, String>{},
  });

  final RiderComplianceProfile profile;
  final Set<RiderSetupSection> savingSections;
  final Map<RiderDocumentSlot, double> uploadProgress;
  final Map<RiderSetupSection, String> sectionErrors;
  final Map<RiderSetupSection, String> sectionSuccess;

  bool isSaving(RiderSetupSection section) => savingSections.contains(section);

  bool isUploading(RiderDocumentSlot slot) => uploadProgress.containsKey(slot);

  bool isSectionBusy(RiderSetupSection section) {
    return isSaving(section) ||
        uploadProgress.keys.any((slot) => slot.section == section);
  }

  String? errorFor(RiderSetupSection section) => sectionErrors[section];

  String? successFor(RiderSetupSection section) => sectionSuccess[section];

  RiderComplianceState copyWith({
    RiderComplianceProfile? profile,
    Set<RiderSetupSection>? savingSections,
    Map<RiderDocumentSlot, double>? uploadProgress,
    Map<RiderSetupSection, String>? sectionErrors,
    Map<RiderSetupSection, String>? sectionSuccess,
  }) {
    return RiderComplianceState(
      profile: profile ?? this.profile,
      savingSections: savingSections ?? this.savingSections,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      sectionErrors: sectionErrors ?? this.sectionErrors,
      sectionSuccess: sectionSuccess ?? this.sectionSuccess,
    );
  }
}

class KycComplianceDraft {
  const KycComplianceDraft({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.licenseNumber,
    required this.nationalIdType,
    required this.nationalIdNumber,
    required this.documents,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String licenseNumber;
  final String nationalIdType;
  final String nationalIdNumber;
  final RiderComplianceDocuments documents;
}

class VehicleComplianceDraft {
  const VehicleComplianceDraft({
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
}

class BankComplianceDraft {
  const BankComplianceDraft({
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
}

class RiderComplianceController extends AsyncNotifier<RiderComplianceState> {
  @override
  Future<RiderComplianceState> build() => _fetch();

  Future<RiderComplianceState> _fetch() async {
    final api = ref.read(riderBackendApiProvider);
    try {
      final envelope = await api.rider.me();
      return RiderComplianceState(
        profile: RiderComplianceProfile.fromJson(envelope.data),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return const RiderComplianceState(profile: RiderComplianceProfile());
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<String> uploadDocument({
    required RiderDocumentSlot slot,
    required File file,
  }) async {
    _ensureAuthenticated();
    _setUploadProgress(slot, 0.01);
    try {
      final envelope = await ref
          .read(riderBackendApiProvider)
          .rider
          .uploadDocument(
            file,
            onProgress: (progress) {
              _setUploadProgress(slot, progress);
            },
          );
      final fileUrl = _extractFileUrl(envelope.data, envelope.raw);
      if (fileUrl == null) {
        throw ApiException(
          message:
              '${slot.label} upload finished, but no file URL was returned.',
          statusCode: envelope.statusCode,
          errorCode: 'UPLOAD_URL_MISSING',
          rawData: envelope.raw,
        );
      }

      _updateState((current) {
        final progress = Map<RiderDocumentSlot, double>.from(
          current.uploadProgress,
        )..remove(slot);
        final profile = current.profile.setDocumentUrl(slot, fileUrl);
        return current.copyWith(
          profile: profile,
          uploadProgress: progress,
          sectionErrors: _withoutKey(current.sectionErrors, slot.section),
          sectionSuccess: {
            ...current.sectionSuccess,
            slot.section: '${slot.label} uploaded.',
          },
        );
      });
      return fileUrl;
    } on ApiException catch (error) {
      final message = _friendlyMessage(
        error,
        fallback: '${slot.label} upload failed. Please try again.',
      );
      _finishUploadWithError(slot, message);
      throw ApiException(
        message: message,
        statusCode: error.statusCode,
        errorCode: error.errorCode,
        errors: error.errors,
        rawData: error.rawData,
      );
    } catch (error) {
      const message = 'Upload failed. Please try again.';
      _finishUploadWithError(slot, message);
      throw ApiException(message: message, rawData: error);
    }
  }

  Future<void> saveKyc(KycComplianceDraft draft) async {
    _ensureAuthenticated();
    final error = _validateKyc(draft);
    if (error != null) {
      _setSectionError(RiderSetupSection.kyc, error);
      throw ApiException(message: error, errorCode: 'VALIDATION_FAILED');
    }

    _setSectionSaving(RiderSetupSection.kyc, true);
    try {
      final envelope = await ref
          .read(riderBackendApiProvider)
          .rider
          .updateKYC(
            payload: KycPayload(
              firstName: draft.firstName.trim(),
              lastName: draft.lastName.trim(),
              phone: draft.phone.trim(),
              email: draft.email.trim(),
              licenseNumber: draft.licenseNumber.trim(),
              drivingLicenseFrontUrl: draft.documents.drivingLicenseFrontUrl
                  .trim(),
              drivingLicenseBackUrl: draft.documents.drivingLicenseBackUrl
                  .trim(),
              nationalIdType: draft.nationalIdType.trim(),
              nationalIdNumber: draft.nationalIdNumber.trim(),
              nationalIdFrontUrl: draft.documents.nationalIdFrontUrl.trim(),
              nationalIdBackUrl: draft.documents.nationalIdBackUrl.trim(),
            ),
          );
      _applySavedProfile(
        RiderSetupSection.kyc,
        envelope.data,
        success: 'KYC details saved successfully.',
      );
      ref.invalidate(profileControllerProvider);
    } on ApiException catch (error) {
      _setSectionError(
        RiderSetupSection.kyc,
        _friendlyMessage(error, fallback: 'KYC update failed.'),
      );
      rethrow;
    } finally {
      _setSectionSaving(RiderSetupSection.kyc, false);
    }
  }

  Future<void> saveVehicle(VehicleComplianceDraft draft) async {
    _ensureAuthenticated();
    final error = _validateVehicle(draft);
    if (error != null) {
      _setSectionError(RiderSetupSection.vehicle, error);
      throw ApiException(message: error, errorCode: 'VALIDATION_FAILED');
    }

    _setSectionSaving(RiderSetupSection.vehicle, true);
    try {
      final envelope = await ref
          .read(riderBackendApiProvider)
          .rider
          .updateVehicle(
            payload: VehiclePayload(
              vehicleType: draft.vehicleType.trim(),
              make: draft.make.trim(),
              model: draft.model.trim(),
              year: draft.year,
              registrationNumber: draft.registrationNumber.trim(),
              rcDocumentUrl: draft.rcDocumentUrl.trim(),
              insuranceDocumentUrl: draft.insuranceDocumentUrl.trim(),
            ),
          );
      _applySavedProfile(
        RiderSetupSection.vehicle,
        envelope.data,
        success: 'Vehicle details saved successfully.',
      );
      ref.invalidate(profileControllerProvider);
    } on ApiException catch (error) {
      _setSectionError(
        RiderSetupSection.vehicle,
        _friendlyMessage(
          error,
          fallback: 'Vehicle details could not be saved.',
        ),
      );
      rethrow;
    } finally {
      _setSectionSaving(RiderSetupSection.vehicle, false);
    }
  }

  Future<void> saveBank(BankComplianceDraft draft) async {
    _ensureAuthenticated();
    final error = _validateBank(draft);
    if (error != null) {
      _setSectionError(RiderSetupSection.bank, error);
      throw ApiException(message: error, errorCode: 'VALIDATION_FAILED');
    }

    _setSectionSaving(RiderSetupSection.bank, true);
    try {
      final envelope = await ref
          .read(riderBackendApiProvider)
          .rider
          .updateBankDetails(
            payload: BankDetailsPayload(
              accountHolderName: draft.accountHolderName.trim(),
              accountNumber: draft.accountNumber.trim(),
              ifscCode: draft.ifscCode.trim().toUpperCase(),
              bankName: draft.bankName.trim(),
              branchName: draft.branchName.trim(),
            ),
          );
      _applySavedProfile(
        RiderSetupSection.bank,
        envelope.data,
        success: 'Bank details saved successfully.',
      );
      ref.invalidate(profileControllerProvider);
    } on ApiException catch (error) {
      _setSectionError(
        RiderSetupSection.bank,
        _friendlyMessage(error, fallback: 'Bank details could not be saved.'),
      );
      rethrow;
    } finally {
      _setSectionSaving(RiderSetupSection.bank, false);
    }
  }

  void _applySavedProfile(
    RiderSetupSection section,
    Map<String, dynamic> data, {
    required String success,
  }) {
    _updateState((current) {
      final parsed = data.isEmpty
          ? current.profile
          : RiderComplianceProfile.fromJson(data).withFallback(current.profile);
      return current.copyWith(
        profile: parsed,
        sectionErrors: _withoutKey(current.sectionErrors, section),
        sectionSuccess: {...current.sectionSuccess, section: success},
      );
    });
  }

  void _ensureAuthenticated() {
    final prefs = ref.read(appPreferencesProvider);
    final token = prefs.accessToken;
    final role = AppRoutes.normalizeRole(prefs.authRole);
    if (!prefs.isAuthenticated ||
        token == null ||
        token.isEmpty ||
        !AppRoutes.isSupportedRiderRole(role)) {
      throw const ApiException(
        message: 'Please sign in again before updating rider setup.',
        statusCode: 401,
        errorCode: 'AUTH_REQUIRED',
      );
    }
  }

  void _setUploadProgress(RiderDocumentSlot slot, double progress) {
    _updateState((current) {
      return current.copyWith(
        uploadProgress: {
          ...current.uploadProgress,
          slot: progress.clamp(0, 1).toDouble(),
        },
        sectionErrors: _withoutKey(current.sectionErrors, slot.section),
      );
    });
  }

  void _finishUploadWithError(RiderDocumentSlot slot, String message) {
    _updateState((current) {
      final progress = Map<RiderDocumentSlot, double>.from(
        current.uploadProgress,
      )..remove(slot);
      return current.copyWith(
        uploadProgress: progress,
        sectionErrors: {...current.sectionErrors, slot.section: message},
      );
    });
  }

  void _setSectionSaving(RiderSetupSection section, bool saving) {
    _updateState((current) {
      final next = Set<RiderSetupSection>.from(current.savingSections);
      if (saving) {
        next.add(section);
      } else {
        next.remove(section);
      }
      return current.copyWith(
        savingSections: next,
        sectionErrors: saving
            ? _withoutKey(current.sectionErrors, section)
            : current.sectionErrors,
      );
    });
  }

  void _setSectionError(RiderSetupSection section, String message) {
    _updateState((current) {
      return current.copyWith(
        sectionErrors: {...current.sectionErrors, section: message},
        sectionSuccess: _withoutKey(current.sectionSuccess, section),
      );
    });
  }

  void _updateState(
    RiderComplianceState Function(RiderComplianceState current) update,
  ) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncValue.data(update(current));
  }

  String? _extractFileUrl(Map<String, dynamic> data, Map<String, dynamic> raw) {
    return _firstNonEmptyString([
      data['file_url'],
      data['url'],
      data['document_url'],
      data['avatar_url'],
      _asMap(raw['data'])['file_url'],
    ]);
  }

  String? _validateKyc(KycComplianceDraft draft) {
    if (draft.firstName.trim().isEmpty || draft.lastName.trim().isEmpty) {
      return 'Please enter your first and last name.';
    }
    if (draft.phone.trim().isEmpty || draft.email.trim().isEmpty) {
      return 'Please enter your phone and email.';
    }
    if (draft.licenseNumber.trim().isEmpty) {
      return 'Please enter your driving license number.';
    }
    if (draft.nationalIdType.trim().isEmpty ||
        draft.nationalIdNumber.trim().isEmpty) {
      return 'Please enter your national ID details.';
    }
    if (!draft.documents.isComplete) {
      return 'Upload ID front, ID back, license front, and license back.';
    }
    return null;
  }

  String? _validateVehicle(VehicleComplianceDraft draft) {
    if (draft.vehicleType.trim().isEmpty) {
      return 'Please choose a vehicle type.';
    }
    if (draft.make.trim().isEmpty || draft.model.trim().isEmpty) {
      return 'Please enter the vehicle make and model.';
    }
    final currentYear = DateTime.now().year + 1;
    if (draft.year < 1990 || draft.year > currentYear) {
      return 'Please enter a valid vehicle year.';
    }
    if (draft.registrationNumber.trim().length < 6) {
      return 'Please enter a valid registration number.';
    }
    return null;
  }

  String? _validateBank(BankComplianceDraft draft) {
    if (draft.accountHolderName.trim().isEmpty) {
      return 'Please enter the account holder name.';
    }
    final accountNumber = draft.accountNumber.trim();
    if (accountNumber.length < 9 || accountNumber.length > 18) {
      return 'Please enter a valid account number.';
    }
    final ifsc = draft.ifscCode.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc)) {
      return 'Please enter a valid IFSC code.';
    }
    if (draft.bankName.trim().isEmpty) {
      return 'Please enter the bank name.';
    }
    return null;
  }

  String _friendlyMessage(ApiException error, {required String fallback}) {
    if (error.statusCode == 401) {
      return 'Your session expired. Please sign in again.';
    }
    if (error.statusCode == 0) {
      return 'Network unavailable. Please check your connection.';
    }
    if ((error.statusCode ?? 0) >= 500) {
      return 'Server error. Please try again shortly.';
    }
    if (error.message.trim().isNotEmpty) {
      return error.message;
    }
    return fallback;
  }

  Map<T, String> _withoutKey<T>(Map<T, String> map, T key) {
    final next = Map<T, String>.from(map);
    next.remove(key);
    return next;
  }

  String? _firstNonEmptyString(List<Object?> values) {
    for (final value in values) {
      if (value != null && '$value'.trim().isNotEmpty) {
        return '$value'.trim();
      }
    }
    return null;
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    return const <String, dynamic>{};
  }

  void debugLog(String message) {
    assert(() {
      debugPrint('[RiderCompliance] $message');
      return true;
    }());
  }
}
