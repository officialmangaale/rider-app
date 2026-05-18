import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/rider_compliance_models.dart';
import '../../../../presentation/providers/app_providers.dart';
import '../../../../shared/widgets/feedback_widgets.dart';
import '../../../../shared/widgets/premium_controls.dart';
import '../../../../shared/widgets/premium_surfaces.dart';
import '../../../delivery/providers/rider_delivery_provider.dart';

class RiderCompliancePanel extends ConsumerWidget {
  const RiderCompliancePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complianceAsync = ref.watch(riderComplianceControllerProvider);
    final deliveryState = ref.watch(riderDeliveryControllerProvider);

    return complianceAsync.when(
      loading: () => const Column(
        children: [
          ShimmerCard(height: 110),
          SizedBox(height: AppSpacing.md),
          ShimmerCard(height: 140),
        ],
      ),
      error: (error, _) => EmptyStateCard(
        icon: Icons.assignment_late_outlined,
        title: 'Could not load setup',
        subtitle: error is ApiException
            ? error.message
            : 'Rider setup details are unavailable right now.',
        action: SecondaryButton(
          label: 'Retry',
          icon: Icons.refresh_rounded,
          onPressed: () =>
              ref.read(riderComplianceControllerProvider.notifier).refresh(),
        ),
      ),
      data: (state) {
        final profile = state.profile;
        final locationReady =
            deliveryState.locationPermissionGranted ||
            deliveryState.lastLocationUpdate != null ||
            profile.hasLocationSnapshot;
        final missing = profile.missingItems(locationReady: locationReady);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SetupProgressCard(
              profile: profile,
              locationReady: locationReady,
              isOnline: deliveryState.isOnline,
              missing: missing,
            ),
            const SizedBox(height: AppSpacing.lg),
            _SetupSectionCard(
              title: 'KYC verification',
              subtitle: profile.isKycComplete
                  ? profile.kycStatusLabel
                  : 'Upload identity and license documents.',
              icon: Icons.verified_user_outlined,
              complete: profile.isKycComplete,
              busy: state.isSectionBusy(RiderSetupSection.kyc),
              error: state.errorFor(RiderSetupSection.kyc),
              success: state.successFor(RiderSetupSection.kyc),
              detailRows: [
                _DetailRow('License', _display(profile.licenseNumber)),
                _DetailRow('National ID', _display(profile.nationalIdNumber)),
              ],
              onTap: () => _showComplianceSheet(
                context: context,
                title: 'KYC verification',
                child: _KycSheet(profile: profile),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SetupSectionCard(
              title: 'Vehicle details',
              subtitle: profile.vehicle.isComplete
                  ? 'Vehicle profile is saved.'
                  : 'Add vehicle registration and basic details.',
              icon: Icons.two_wheeler_rounded,
              complete: profile.vehicle.isComplete,
              busy: state.isSectionBusy(RiderSetupSection.vehicle),
              error: state.errorFor(RiderSetupSection.vehicle),
              success: state.successFor(RiderSetupSection.vehicle),
              detailRows: [
                _DetailRow('Type', _display(profile.vehicle.vehicleType)),
                _DetailRow(
                  'Registration',
                  _display(profile.vehicle.registrationNumber),
                ),
              ],
              onTap: () => _showComplianceSheet(
                context: context,
                title: 'Vehicle details',
                child: _VehicleSheet(profile: profile),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SetupSectionCard(
              title: 'Bank details',
              subtitle: profile.bank.isComplete
                  ? 'Payout account is saved.'
                  : 'Add payout account details.',
              icon: Icons.account_balance_outlined,
              complete: profile.bank.isComplete,
              busy: state.isSectionBusy(RiderSetupSection.bank),
              error: state.errorFor(RiderSetupSection.bank),
              success: state.successFor(RiderSetupSection.bank),
              detailRows: [
                _DetailRow('Bank', _display(profile.bank.bankName)),
                _DetailRow('Account', profile.bank.maskedAccountNumber),
              ],
              onTap: () => _showComplianceSheet(
                context: context,
                title: 'Bank details',
                child: _BankSheet(profile: profile),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _LocationComplianceCard(
              state: deliveryState,
              profile: profile,
              locationReady: locationReady,
            ),
            const SizedBox(height: AppSpacing.md),
            _AvailabilityComplianceCard(
              ready: missing.isEmpty,
              isOnline: deliveryState.isOnline,
              missing: missing,
            ),
          ],
        );
      },
    );
  }
}

class _SetupProgressCard extends StatelessWidget {
  const _SetupProgressCard({
    required this.profile,
    required this.locationReady,
    required this.isOnline,
    required this.missing,
  });

  final RiderComplianceProfile profile;
  final bool locationReady;
  final bool isOnline;
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final completed = profile.completedSections(locationReady: locationReady);
    final progress = profile.progress(locationReady: locationReady);
    final ready = missing.isEmpty;

    return GlassCard(
      accent: ready ? AppColors.emerald : AppColors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Complete your rider profile',
            subtitle: ready
                ? 'Your setup is ready for online delivery.'
                : 'Finish the required sections before going online.',
            trailing: StatusPill(
              label: isOnline
                  ? 'Online'
                  : ready
                  ? 'Ready'
                  : '$completed/4',
              color: isOnline
                  ? AppColors.emerald
                  : ready
                  ? AppColors.emerald
                  : AppColors.gold,
              icon: isOnline ? Icons.flash_on_rounded : Icons.task_alt_rounded,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress.clamp(0, 1).toDouble(),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
              valueColor: AlwaysStoppedAnimation<Color>(
                ready ? AppColors.emerald : AppColors.gold,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _ChecklistPill(label: 'KYC', complete: profile.isKycComplete),
              _ChecklistPill(
                label: 'Vehicle',
                complete: profile.vehicle.isComplete,
              ),
              _ChecklistPill(label: 'Bank', complete: profile.bank.isComplete),
              _ChecklistPill(label: 'Location', complete: locationReady),
            ],
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Missing: ${missing.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SetupSectionCard extends StatelessWidget {
  const _SetupSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.complete,
    required this.busy,
    required this.detailRows,
    required this.onTap,
    this.error,
    this.success,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool complete;
  final bool busy;
  final List<_DetailRow> detailRows;
  final VoidCallback onTap;
  final String? error;
  final String? success;

  @override
  Widget build(BuildContext context) {
    final accent = error != null
        ? AppColors.cherry
        : complete
        ? AppColors.emerald
        : AppColors.gold;

    return GlassCard(
      accent: accent,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBox(icon: icon, color: accent),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                StatusPill(
                  label: complete ? 'Done' : 'Edit',
                  color: accent,
                  icon: complete
                      ? Icons.check_circle_outline_rounded
                      : Icons.edit_outlined,
                ),
            ],
          ),
          if (detailRows.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final row in detailRows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        row.value,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _InlineMessage(message: error!, color: AppColors.cherry),
          ] else if (success != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _InlineMessage(message: success!, color: AppColors.emerald),
          ],
        ],
      ),
    );
  }
}

class _LocationComplianceCard extends ConsumerWidget {
  const _LocationComplianceCard({
    required this.state,
    required this.profile,
    required this.locationReady,
  });

  final RiderDeliveryState state;
  final RiderComplianceProfile profile;
  final bool locationReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = locationReady ? AppColors.emerald : AppColors.warning;
    final lastUpdate = state.lastLocationUpdate ?? profile.lastLocationUpdate;

    return GlassCard(
      accent: color,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Location tracking',
            subtitle: state.locationMessage,
            trailing: StatusPill(
              label: locationReady ? 'Ready' : 'Needed',
              color: color,
              icon: locationReady
                  ? Icons.gps_fixed_rounded
                  : Icons.location_off_outlined,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SmallInfoRow(
            label: 'Permission',
            value: state.locationPermissionGranted ? 'Granted' : 'Required',
          ),
          _SmallInfoRow(
            label: 'GPS',
            value: state.locationServiceEnabled ? 'Enabled' : 'Check required',
          ),
          _SmallInfoRow(
            label: 'Last update',
            value: lastUpdate == null
                ? 'Not updated yet'
                : _timeAgo(lastUpdate),
          ),
          if (_hasLocationActions(state)) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (state.canRequestLocationPermission)
                  PrimaryButton(
                    label: 'Grant permission',
                    icon: Icons.my_location_rounded,
                    onPressed: state.locationActionInProgress
                        ? null
                        : () => ref
                              .read(riderDeliveryControllerProvider.notifier)
                              .requestLocationPermission(),
                  ),
                if (state.canOpenLocationSettings)
                  PrimaryButton(
                    label: 'Enable GPS',
                    icon: Icons.location_searching_rounded,
                    onPressed: state.locationActionInProgress
                        ? null
                        : () => ref
                              .read(riderDeliveryControllerProvider.notifier)
                              .openLocationSettings(),
                  ),
                if (state.canOpenAppSettings)
                  SecondaryButton(
                    label: 'Open settings',
                    icon: Icons.settings_rounded,
                    onPressed: state.locationActionInProgress
                        ? null
                        : () => ref
                              .read(riderDeliveryControllerProvider.notifier)
                              .openAppSettings(),
                  ),
                if (state.locationStatus == RiderLocationTrackingStatus.failed)
                  SecondaryButton(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    onPressed: state.locationActionInProgress
                        ? null
                        : () => ref
                              .read(riderDeliveryControllerProvider.notifier)
                              .retryLocationUpdate(),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _hasLocationActions(RiderDeliveryState state) {
    return state.canRequestLocationPermission ||
        state.canOpenLocationSettings ||
        state.canOpenAppSettings ||
        state.locationStatus == RiderLocationTrackingStatus.failed;
  }
}

class _AvailabilityComplianceCard extends StatelessWidget {
  const _AvailabilityComplianceCard({
    required this.ready,
    required this.isOnline,
    required this.missing,
  });

  final bool ready;
  final bool isOnline;
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final color = isOnline
        ? AppColors.emerald
        : ready
        ? AppColors.riderPrimary
        : AppColors.smoke;

    return GlassCard(
      accent: color,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Account status',
            subtitle: ready
                ? 'You can manage online mode from Availability.'
                : 'Online mode is locked until setup is complete.',
            trailing: StatusPill(
              label: isOnline
                  ? 'Online'
                  : ready
                  ? 'Ready'
                  : 'Locked',
              color: color,
              icon: isOnline
                  ? Icons.flash_on_rounded
                  : ready
                  ? Icons.lock_open_rounded
                  : Icons.lock_outline_rounded,
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Complete ${missing.join(', ')} to go online.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: 'Open availability',
            icon: Icons.schedule_rounded,
            onPressed: () => context.push(AppRoutes.availability),
          ),
        ],
      ),
    );
  }
}

class _KycSheet extends ConsumerStatefulWidget {
  const _KycSheet({required this.profile});

  final RiderComplianceProfile profile;

  @override
  ConsumerState<_KycSheet> createState() => _KycSheetState();
}

class _KycSheetState extends ConsumerState<_KycSheet> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _license;
  late final TextEditingController _nationalIdNumber;
  late String _nationalIdType;
  late RiderComplianceDocuments _documents;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _firstName = TextEditingController(text: profile.firstName);
    _lastName = TextEditingController(text: profile.lastName);
    _phone = TextEditingController(text: profile.phone);
    _email = TextEditingController(text: profile.email);
    _license = TextEditingController(text: profile.licenseNumber);
    _nationalIdNumber = TextEditingController(text: profile.nationalIdNumber);
    _nationalIdType = profile.nationalIdType.isEmpty
        ? 'aadhar'
        : profile.nationalIdType;
    _documents = profile.documents;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _license.dispose();
    _nationalIdNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(riderComplianceControllerProvider).valueOrNull;
    final saving = state?.isSaving(RiderSetupSection.kyc) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: PremiumTextField(
                label: 'First name',
                hint: 'First name',
                controller: _firstName,
                prefixIcon: Icons.person_outline_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: PremiumTextField(
                label: 'Last name',
                hint: 'Last name',
                controller: _lastName,
                prefixIcon: Icons.person_outline_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumTextField(
          label: 'Phone',
          hint: '9876543210',
          controller: _phone,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumTextField(
          label: 'Email',
          hint: 'name@example.com',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumTextField(
          label: 'Driving license number',
          hint: 'DL-123456789',
          controller: _license,
          prefixIcon: Icons.badge_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        _DropdownField(
          label: 'National ID type',
          value: _nationalIdType,
          items: const {
            'aadhar': 'Aadhar',
            'pan': 'PAN',
            'voter_id': 'Voter ID',
            'passport': 'Passport',
          },
          onChanged: (value) => setState(() => _nationalIdType = value),
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumTextField(
          label: 'National ID number',
          hint: '1234-5678-9012',
          controller: _nationalIdNumber,
          prefixIcon: Icons.credit_card_rounded,
        ),
        const SizedBox(height: AppSpacing.lg),
        _UploadTile(
          slot: RiderDocumentSlot.nationalIdFront,
          url: _documents.nationalIdFrontUrl,
          progress: state?.uploadProgress[RiderDocumentSlot.nationalIdFront],
          onUpload: _pickAndUpload,
        ),
        _UploadTile(
          slot: RiderDocumentSlot.nationalIdBack,
          url: _documents.nationalIdBackUrl,
          progress: state?.uploadProgress[RiderDocumentSlot.nationalIdBack],
          onUpload: _pickAndUpload,
        ),
        _UploadTile(
          slot: RiderDocumentSlot.drivingLicenseFront,
          url: _documents.drivingLicenseFrontUrl,
          progress:
              state?.uploadProgress[RiderDocumentSlot.drivingLicenseFront],
          onUpload: _pickAndUpload,
        ),
        _UploadTile(
          slot: RiderDocumentSlot.drivingLicenseBack,
          url: _documents.drivingLicenseBackUrl,
          progress: state?.uploadProgress[RiderDocumentSlot.drivingLicenseBack],
          onUpload: _pickAndUpload,
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: saving ? 'Saving KYC...' : 'Save KYC',
          icon: Icons.save_outlined,
          expanded: true,
          onPressed: saving ? null : _save,
        ),
      ],
    );
  }

  Future<void> _pickAndUpload(RiderDocumentSlot slot) async {
    final url = await _pickAndUploadDocument(context, ref, slot);
    if (url == null || !mounted) {
      return;
    }
    setState(() => _documents = _documents.setUrl(slot, url));
  }

  Future<void> _save() async {
    try {
      await ref
          .read(riderComplianceControllerProvider.notifier)
          .saveKyc(
            KycComplianceDraft(
              firstName: _firstName.text,
              lastName: _lastName.text,
              phone: _phone.text,
              email: _email.text,
              licenseNumber: _license.text,
              nationalIdType: _nationalIdType,
              nationalIdNumber: _nationalIdNumber.text,
              documents: _documents,
            ),
          );
      if (!mounted) return;
      showLuxurySnackBar(context, 'KYC details saved successfully.');
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      showLuxurySnackBar(context, error.message, isError: true);
    }
  }
}

class _VehicleSheet extends ConsumerStatefulWidget {
  const _VehicleSheet({required this.profile});

  final RiderComplianceProfile profile;

  @override
  ConsumerState<_VehicleSheet> createState() => _VehicleSheetState();
}

class _VehicleSheetState extends ConsumerState<_VehicleSheet> {
  late final TextEditingController _make;
  late final TextEditingController _model;
  late final TextEditingController _year;
  late final TextEditingController _registration;
  late String _vehicleType;
  late String _rcUrl;
  late String _insuranceUrl;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.profile.vehicle;
    _vehicleType = _normalizeVehicleType(vehicle.vehicleType);
    _make = TextEditingController(text: vehicle.make);
    _model = TextEditingController(text: vehicle.model);
    _year = TextEditingController(text: vehicle.year?.toString() ?? '');
    _registration = TextEditingController(text: vehicle.registrationNumber);
    _rcUrl = vehicle.rcDocumentUrl;
    _insuranceUrl = vehicle.insuranceDocumentUrl;
  }

  @override
  void dispose() {
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _registration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(riderComplianceControllerProvider).valueOrNull;
    final saving = state?.isSaving(RiderSetupSection.vehicle) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DropdownField(
          label: 'Vehicle type',
          value: _vehicleType,
          items: const {
            'motorcycle': 'Motorcycle',
            'scooter': 'Scooter',
            'bicycle': 'Bicycle',
            'car': 'Car',
          },
          onChanged: (value) => setState(() => _vehicleType = value),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: PremiumTextField(
                label: 'Make',
                hint: 'Honda',
                controller: _make,
                prefixIcon: Icons.factory_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: PremiumTextField(
                label: 'Model',
                hint: 'Activa',
                controller: _model,
                prefixIcon: Icons.two_wheeler_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumTextField(
          label: 'Year',
          hint: '2022',
          controller: _year,
          keyboardType: TextInputType.number,
          prefixIcon: Icons.calendar_today_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumTextField(
          label: 'Registration number',
          hint: 'MH-01-AB-1234',
          controller: _registration,
          prefixIcon: Icons.confirmation_number_outlined,
        ),
        const SizedBox(height: AppSpacing.lg),
        _UploadTile(
          slot: RiderDocumentSlot.rcDocument,
          url: _rcUrl,
          optional: true,
          progress: state?.uploadProgress[RiderDocumentSlot.rcDocument],
          onUpload: _pickAndUpload,
        ),
        _UploadTile(
          slot: RiderDocumentSlot.insuranceDocument,
          url: _insuranceUrl,
          optional: true,
          progress: state?.uploadProgress[RiderDocumentSlot.insuranceDocument],
          onUpload: _pickAndUpload,
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: saving ? 'Saving vehicle...' : 'Save vehicle',
          icon: Icons.save_outlined,
          expanded: true,
          onPressed: saving ? null : _save,
        ),
      ],
    );
  }

  Future<void> _pickAndUpload(RiderDocumentSlot slot) async {
    final url = await _pickAndUploadDocument(context, ref, slot);
    if (url == null || !mounted) {
      return;
    }
    setState(() {
      if (slot == RiderDocumentSlot.rcDocument) {
        _rcUrl = url;
      } else if (slot == RiderDocumentSlot.insuranceDocument) {
        _insuranceUrl = url;
      }
    });
  }

  Future<void> _save() async {
    final year = int.tryParse(_year.text.trim());
    if (year == null) {
      showLuxurySnackBar(context, 'Please enter a valid year.', isError: true);
      return;
    }
    try {
      await ref
          .read(riderComplianceControllerProvider.notifier)
          .saveVehicle(
            VehicleComplianceDraft(
              vehicleType: _vehicleType,
              make: _make.text,
              model: _model.text,
              year: year,
              registrationNumber: _registration.text,
              rcDocumentUrl: _rcUrl,
              insuranceDocumentUrl: _insuranceUrl,
            ),
          );
      if (!mounted) return;
      showLuxurySnackBar(context, 'Vehicle details saved successfully.');
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      showLuxurySnackBar(context, error.message, isError: true);
    }
  }
}

class _BankSheet extends ConsumerStatefulWidget {
  const _BankSheet({required this.profile});

  final RiderComplianceProfile profile;

  @override
  ConsumerState<_BankSheet> createState() => _BankSheetState();
}

class _BankSheetState extends ConsumerState<_BankSheet> {
  late final TextEditingController _holder;
  late final TextEditingController _account;
  late final TextEditingController _ifsc;
  late final TextEditingController _bank;
  late final TextEditingController _branch;

  @override
  void initState() {
    super.initState();
    final bank = widget.profile.bank;
    _holder = TextEditingController(text: bank.accountHolderName);
    _account = TextEditingController(
      text: _looksMasked(bank.accountNumber) ? '' : bank.accountNumber,
    );
    _ifsc = TextEditingController(text: bank.ifscCode);
    _bank = TextEditingController(text: bank.bankName);
    _branch = TextEditingController(text: bank.branchName);
  }

  @override
  void dispose() {
    _holder.dispose();
    _account.dispose();
    _ifsc.dispose();
    _bank.dispose();
    _branch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(riderComplianceControllerProvider).valueOrNull;
    final saving = state?.isSaving(RiderSetupSection.bank) ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumTextField(
          label: 'Account holder name',
          hint: 'John Doe',
          controller: _holder,
          prefixIcon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumTextField(
          label: 'Account number',
          hint: widget.profile.bank.accountNumber.isEmpty
              ? '123456789012'
              : 'Re-enter to update account number',
          controller: _account,
          keyboardType: TextInputType.number,
          prefixIcon: Icons.numbers_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumTextField(
          label: 'IFSC code',
          hint: 'HDFC0001234',
          controller: _ifsc,
          prefixIcon: Icons.account_balance_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumTextField(
          label: 'Bank name',
          hint: 'HDFC Bank',
          controller: _bank,
          prefixIcon: Icons.account_balance_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        PremiumTextField(
          label: 'Branch name',
          hint: 'Main Branch',
          controller: _branch,
          prefixIcon: Icons.location_city_outlined,
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: saving ? 'Saving bank...' : 'Save bank details',
          icon: Icons.save_outlined,
          expanded: true,
          onPressed: saving ? null : _save,
        ),
      ],
    );
  }

  Future<void> _save() async {
    try {
      await ref
          .read(riderComplianceControllerProvider.notifier)
          .saveBank(
            BankComplianceDraft(
              accountHolderName: _holder.text,
              accountNumber: _account.text,
              ifscCode: _ifsc.text,
              bankName: _bank.text,
              branchName: _branch.text,
            ),
          );
      if (!mounted) return;
      showLuxurySnackBar(context, 'Bank details saved successfully.');
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      showLuxurySnackBar(context, error.message, isError: true);
    }
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.slot,
    required this.url,
    required this.onUpload,
    this.progress,
    this.optional = false,
  });

  final RiderDocumentSlot slot;
  final String url;
  final double? progress;
  final bool optional;
  final ValueChanged<RiderDocumentSlot> onUpload;

  @override
  Widget build(BuildContext context) {
    final uploading = progress != null;
    final uploaded = url.trim().isNotEmpty;
    final color = uploaded ? AppColors.emerald : AppColors.gold;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBox(
                icon: uploaded
                    ? Icons.check_circle_outline_rounded
                    : Icons.file_upload_outlined,
                color: color,
                size: 36,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.label,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      uploaded
                          ? 'Uploaded and ready to save.'
                          : optional
                          ? 'Optional document.'
                          : 'Required before saving.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SecondaryButton(
                label: uploading
                    ? 'Uploading...'
                    : uploaded
                    ? 'Replace'
                    : 'Upload',
                icon: Icons.upload_file_rounded,
                onPressed: uploading ? null : () => onUpload(slot),
              ),
            ],
          ),
          if (uploading) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress!.clamp(0, 1).toDouble(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: items.containsKey(value) ? value : items.keys.first,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.tune_rounded, size: 20),
          ),
          items: [
            for (final entry in items.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ],
    );
  }
}

class _ChecklistPill extends StatelessWidget {
  const _ChecklistPill({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: label,
      color: complete ? AppColors.emerald : AppColors.smoke,
      icon: complete
          ? Icons.check_circle_outline_rounded
          : Icons.radio_button_unchecked_rounded,
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color, this.size = 42});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        color: color.withValues(alpha: 0.12),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _SmallInfoRow extends StatelessWidget {
  const _SmallInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;
}

Future<void> _showComplianceSheet({
  required BuildContext context,
  required String title,
  required Widget child,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(child: SingleChildScrollView(child: child)),
            ],
          ),
        ),
      );
    },
  );
}

Future<String?> _pickAndUploadDocument(
  BuildContext context,
  WidgetRef ref,
  RiderDocumentSlot slot,
) async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Images and PDF',
        extensions: ['jpg', 'jpeg', 'png', 'pdf'],
        mimeTypes: ['image/jpeg', 'image/png', 'application/pdf'],
      ),
    ],
  );
  if (file == null) {
    return null;
  }
  if (file.path.isEmpty) {
    if (context.mounted) {
      showLuxurySnackBar(
        context,
        'This file could not be opened. Please choose another file.',
        isError: true,
      );
    }
    return null;
  }

  try {
    final url = await ref
        .read(riderComplianceControllerProvider.notifier)
        .uploadDocument(slot: slot, file: File(file.path));
    if (context.mounted) {
      showLuxurySnackBar(context, '${slot.label} uploaded.');
    }
    return url;
  } on ApiException catch (error) {
    if (context.mounted) {
      showLuxurySnackBar(context, error.message, isError: true);
    }
    return null;
  }
}

String _display(String value) => value.trim().isEmpty ? 'Not added' : value;

String _normalizeVehicleType(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(' ', '_');
  if (normalized.contains('scooter')) {
    return 'scooter';
  }
  if (normalized.contains('bicycle') || normalized.contains('cycle')) {
    return 'bicycle';
  }
  if (normalized.contains('car')) {
    return 'car';
  }
  return 'motorcycle';
}

bool _looksMasked(String value) {
  return value.contains('*') || value.contains('X') || value.contains('x');
}

String _timeAgo(DateTime value) {
  final diff = DateTime.now().difference(value.toLocal());
  if (diff.inSeconds < 45) {
    return 'Just now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} min ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} hr ago';
  }
  return '${value.day}/${value.month}/${value.year}';
}
