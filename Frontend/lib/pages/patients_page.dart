// ignore_for_file: deprecated_member_use, unused_element

import 'dart:async';
import 'dart:convert';

import 'package:curevoo_doctor/models/patient.dart';
import 'package:curevoo_doctor/models/nsclc_last_result.dart';
import 'package:curevoo_doctor/widgets/add_patient_dialog.dart';
import 'package:curevoo_doctor/widgets/async_state_panel.dart';
import 'package:curevoo_doctor/widgets/edit_patient_dialog.dart';
import 'package:curevoo_doctor/widgets/patient_connect_requests_section.dart';
import 'package:curevoo_doctor/widgets/patient_details_dialog.dart';
import 'package:curevoo_doctor/widgets/patient_history_ui_parts.dart';
import 'package:curevoo_doctor/widgets/patient_page_header.dart';
import 'package:curevoo_doctor/widgets/patient_table.dart';
import 'package:curevoo_doctor/widgets/patients_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:curevoo_doctor/providers/medical_history_cubit.dart';
import 'package:curevoo_doctor/providers/patients_cubit.dart';
import 'package:curevoo_doctor/providers/treatment_plan_cubit.dart';
import 'package:curevoo_doctor/repos/medical_history_repo.dart';
import 'package:curevoo_doctor/repos/treatment_plan_repo.dart';

class PatientManagementPage extends StatefulWidget {
  const PatientManagementPage({super.key});

  @override
  State<PatientManagementPage> createState() => _PatientManagementPageState();
}

class _PatientManagementPageState extends State<PatientManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<Patient> patients = [];
  List<PatientConnectRequest> _connectRequests = [];
  final Set<String> _processingConnectRequestIds = <String>{};
  bool _isLoadingPatients = true;
  bool _isLoadingConnectRequests = true;
  String? _patientsLoadError;
  String? _connectRequestsLoadError;
  String _searchQuery = '';

  void addPatient(Patient newPatient) {
    setState(() {
      patients.add(newPatient);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPatients();
      _loadConnectRequests();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value;
      });
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  List<Patient> get _filteredPatients {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return patients;

    return patients
        .where((patient) {
          return patient.name.toLowerCase().contains(query) ||
              patient.phone.toLowerCase().contains(query) ||
              patient.gender.toLowerCase().contains(query) ||
              patient.age.toString().contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _loadPatients() async {
    if (!mounted) return;
    final patientsCubit = context.read<PatientsCubit>();

    setState(() {
      _isLoadingPatients = true;
      _patientsLoadError = null;
    });

    final summaries = await patientsCubit.fetchPatients();
    if (!mounted) return;

    final nextPatients = summaries
        .map((summary) {
          final sex = summary.sex.trim().toUpperCase();
          final mappedGender = switch (sex) {
            'FEMALE' => 'Female',
            'MALE' => 'Male',
            _ => 'Other',
          };
          return Patient(
            summary.fullName,
            summary.age,
            mappedGender,
            summary.phone,
            id: summary.id,
          );
        })
        .toList(growable: true);

    setState(() {
      patients = nextPatients;
      _isLoadingPatients = false;
      _patientsLoadError = patientsCubit.state.errorMessage;
    });
  }

  Future<void> _loadConnectRequests() async {
    if (!mounted) return;
    final patientsCubit = context.read<PatientsCubit>();

    setState(() {
      _isLoadingConnectRequests = true;
      _connectRequestsLoadError = null;
    });

    final requests = await patientsCubit.fetchConnectRequests();
    if (!mounted) return;

    setState(() {
      _connectRequests = requests
          .where((request) => request.status.trim().toUpperCase() == 'PENDING')
          .toList(growable: true);
      _isLoadingConnectRequests = false;
      _connectRequestsLoadError = patientsCubit.state.errorMessage;
    });
  }

  Future<void> _respondToConnectRequest(
    PatientConnectRequest request, {
    required DoctorConnectRequestAction action,
  }) async {
    if (_processingConnectRequestIds.contains(request.id)) return;
    final patientsCubit = context.read<PatientsCubit>();

    setState(() {
      _processingConnectRequestIds.add(request.id);
    });

    final success = await patientsCubit.respondToConnectRequest(
      requestId: request.id,
      action: action,
    );
    if (!mounted) return;

    setState(() {
      _processingConnectRequestIds.remove(request.id);
    });

    if (!success) {
      final message = patientsCubit.state.errorMessage ??
          context.tr('Failed to submit request response.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          action == DoctorConnectRequestAction.accept
              ? context.tr('Request accepted successfully.')
              : context.tr('Request rejected successfully.'),
        ),
      ),
    );

    await _loadConnectRequests();
    if (action == DoctorConnectRequestAction.accept) {
      await _loadPatients();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PatientPageHeader(
                    onAddPressed: () => _showAddPatientDialog(context),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cs.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: cs.shadow.withOpacity(
                            theme.brightness == Brightness.dark ? 0.2 : 0.06,
                          ),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        PatientsToolbar(
                          colorScheme: cs,
                          patientsCount: _filteredPatients.length,
                          searchController: _searchController,
                          searchQuery: _searchQuery,
                          onSearchChanged: _onSearchChanged,
                          onSearchCleared: _clearSearch,
                        ),
                        if (_isLoadingPatients)
                          _buildListStatus(
                            icon: Icons.people_outline,
                            title: context.tr("Loading patients..."),
                            child: const CircularProgressIndicator(),
                          )
                        else if (_patientsLoadError != null && patients.isEmpty)
                          _buildListStatus(
                            icon: Icons.error_outline,
                            title: _patientsLoadError!,
                            isError: true,
                            child: OutlinedButton.icon(
                              onPressed: _loadPatients,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: Text(context.tr('Retry')),
                            ),
                          )
                        else if (_filteredPatients.isEmpty)
                          _buildListStatus(
                            icon: Icons.person_search_outlined,
                            title: context.tr("No patients found"),
                            message: _searchQuery.trim().isEmpty
                                ? context.tr("Add a patient to get started.")
                                : context.tr("Try a different search term."),
                          )
                        else
                          PatientTable(
                            patients: _filteredPatients,
                            onViewPressed: (patient) =>
                                _showPatientDetailsDialog(context, patient),
                            onEditPressed: (patient) =>
                                _showEditPatientDialog(context, patient),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  PatientConnectRequestsSection(
                    theme: theme,
                    colorScheme: cs,
                    requests: _connectRequests,
                    isLoading: _isLoadingConnectRequests,
                    loadError: _connectRequestsLoadError,
                    processingIds: _processingConnectRequestIds,
                    onRefresh: _loadConnectRequests,
                    onRespond: _respondToConnectRequest,
                    buildListStatus: ({
                      required icon,
                      required title,
                      message,
                      isError = false,
                      child,
                    }) => _buildListStatus(
                      icon: icon,
                      title: title,
                      message: message,
                      isError: isError,
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListStatus({
    required IconData icon,
    required String title,
    String? message,
    bool isError = false,
    Widget? child,
  }) {
    return AsyncStatePanel(
      icon: icon,
      title: title,
      message: message,
      isError: isError,
      child: child,
    );
  }

  EdgeInsets _dialogInsetPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return EdgeInsets.all(width < 600 ? 12 : 20);
  }

  double _responsiveDialogWidth(BuildContext context, double maxWidth) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - _dialogInsetPadding(context).horizontal;
    return availableWidth.clamp(320.0, maxWidth).toDouble();
  }

  void _showAddPatientDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AddPatientDialog(onPatientCreated: _loadPatients),
    );
  }

  void _showPatientDetailsDialog(BuildContext context, Patient patient) {
    showDialog(
      context: context,
      builder: (dialogContext) => PatientDetailsDialog(
        patient: patient,
        onLastRecord: () => _showLastRecordDialog(dialogContext, patient),
        onLatestTreatmentPlan: () =>
            _showLatestTreatmentPlanDialog(dialogContext, patient),
        onPatientHistory: () => _showPatientHistoryDialog(dialogContext, patient),
        onTreatmentHistory: () =>
            _showTreatmentPlanHistoryDialog(dialogContext, patient),
        onLastTreatmentResistanceTest: () =>
            _showLastTreatmentResistanceResult(dialogContext, patient),
        onDelete: (ctx) => _handleDeletePatientFromDetailsDialog(ctx, patient),
        onEdit: () {
          Navigator.pop(dialogContext);
          _showEditPatientDialog(context, patient);
        },
      ),
    );
  }

  Future<void> _showLastTreatmentResistanceResult(
    BuildContext dialogContext,
    Patient patient,
  ) async {
    final patientId = patient.id.trim();
    if (patientId.isEmpty) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(
          content: Text(
            dialogContext.tr(
              "This patient is missing an id, so the last treatment resistance result cannot be loaded.",
            ),
          ),
        ),
      );
      return;
    }

    showDialog<void>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (loadingContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result = await dialogContext.read<PatientsCubit>().fetchLastNsclcResult(
      patientId,
    );

    if (dialogContext.mounted) {
      Navigator.of(dialogContext, rootNavigator: true).pop();
    }
    if (!dialogContext.mounted) return;

    if (result == null) {
      final message =
          dialogContext.read<PatientsCubit>().state.errorMessage ??
          dialogContext.tr(
            "Failed to load the latest treatment resistance result.",
          );
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    _showLastTreatmentResistanceResultDialog(dialogContext, result);
  }

void _showLastTreatmentResistanceResultDialog(
    BuildContext context,
    NsclcLastResult result,
  ) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final createdAt = result.createdAt;
    final createdAtLabel = createdAt == null
        ? '-'
        : '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} '
            '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: _dialogInsetPadding(dialogContext),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          width: _responsiveDialogWidth(dialogContext, 800),
          constraints: const BoxConstraints(maxHeight: 720),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withOpacity(
                  theme.brightness == Brightness.dark ? 0.32 : 0.15,
                ),
                blurRadius: 32,
                offset: const Offset(0, 16),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.fromLTRB(28, 26, 20, 26),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary,
                      cs.primaryContainer,
                      cs.primary.withOpacity(0.85),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon with background
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.medical_information_outlined,
                        color: cs.onPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dialogContext.tr("Last Treatment Resistance Test"),
                            style: TextStyle(
                              color: cs.onPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _buildResultInfoChip(
                                dialogContext,
                                Icons.science_outlined,
                                result.cancerType,
                                cs.onPrimary,
                                backgroundColor: Colors.white.withOpacity(0.2),
                              ),
                              _buildResultInfoChip(
                                dialogContext,
                                Icons.schedule_outlined,
                                createdAtLabel,
                                cs.onPrimary,
                                backgroundColor: Colors.white.withOpacity(0.2),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Close button
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => Navigator.pop(dialogContext),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.close,
                            color: cs.onPrimary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content Section
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              cs.primary.withOpacity(0.06),
                              cs.primary.withOpacity(0.02),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: cs.primary.withOpacity(0.15),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.08),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  topRight: Radius.circular(18),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.psychology_alt_outlined,
                                    size: 20,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    dialogContext.tr("Clinical Summary"),
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                result.summaryText?.trim().isNotEmpty == true
                                    ? result.summaryText!
                                    : dialogContext.tr("No summary returned."),
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Support Label
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                result.supportLabel?.trim().isNotEmpty == true
                                    ? result.supportLabel!
                                    : dialogContext.tr(
                                        "Prediction support only. Not treatment instruction.",
                                      ),
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Risk Assessment Section
                      Text(
                        dialogContext.tr("Risk Assessment"),
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      
                      // Early Failure Risk Card
                      _buildTreatmentRiskCard(
                        dialogContext,
                        title: result.earlyFailureRisk.title,
                        probability: result.earlyFailureRisk.probability,
                        level: result.earlyFailureRisk.riskLevel,
                        icon: Icons.warning_amber_rounded,
                      ),
                      const SizedBox(height: 12),
                      
                      // Durable Benefit Card
                      _buildTreatmentRiskCard(
                        dialogContext,
                        title: result.durableBenefitLikelihood.title,
                        probability: result.durableBenefitLikelihood.probability,
                        level: result.durableBenefitLikelihood.riskLevel,
                        icon: Icons.health_and_safety_outlined,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Resistance Interpretation Section
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: cs.outlineVariant.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withOpacity(0.5),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  topRight: Radius.circular(18),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.analytics_outlined,
                                    size: 20,
                                    color: cs.secondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    dialogContext.tr("Resistance Interpretation"),
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                result.resistanceInterpretation.summary
                                              ?.trim()
                                              .isNotEmpty ==
                                        true
                                    ? result.resistanceInterpretation.summary!
                                    : dialogContext.tr("No interpretation returned."),
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  height: 1.45,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Version Footer
                      Container(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.code_outlined,
                                    size: 14,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${dialogContext.tr("Prediction version")}: ${result.predictionVersion ?? '-'}',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Footer Section
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                decoration: BoxDecoration(
                  color: cs.surfaceContainer.withOpacity(0.5),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: cs.outlineVariant.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: Icon(Icons.close, size: 18),
                      label: Text(dialogContext.tr("Close")),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Helper Widget: Info Chip for metadata
Widget _buildResultInfoChip(
  BuildContext context,
  IconData icon,
  String? label,
  Color textColor, {
  Color? backgroundColor,
}) {
  final bgColor = backgroundColor ?? Colors.white.withOpacity(0.15);
  final displayLabel = label ?? '-';
  
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: textColor),
        const SizedBox(width: 6),
        Text(
          displayLabel,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

// Helper Widget: Enhanced Risk Card
Widget _buildTreatmentRiskCard(
  BuildContext context, {
  required String title,
  required double probability,
  required String? level,
  required IconData icon,
}) {
  final cs = Theme.of(context).colorScheme;
  final levelText = (level?.trim().isNotEmpty == true) ? level!.trim() : '-';
  final normalizedProbability = probability > 1 ? probability / 100 : probability;
  final safeProbability = normalizedProbability.clamp(0.0, 1.0);
  final isHighRisk = levelText.toLowerCase().contains('high');
  final isMediumRisk = levelText.toLowerCase().contains('medium') || levelText.toLowerCase().contains('moderate');
  final riskColor = isHighRisk ? Colors.red : (isMediumRisk ? Colors.orange : Colors.green);
  final riskBgColor = riskColor.withOpacity(0.08);
  
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: riskBgColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: riskColor.withOpacity(0.15), width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: riskColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            // Risk Level Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                levelText.toUpperCase(),
                style: TextStyle(
                  color: riskColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Probability Bar
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr("Probability"),
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${(safeProbability * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: riskColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: safeProbability,
                backgroundColor: riskColor.withOpacity(0.15),
                color: riskColor,
                minHeight: 8,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  Future<void> _handleDeletePatientFromDetailsDialog(
    BuildContext dialogContext,
    Patient patient,
  ) async {
    final cs = Theme.of(dialogContext).colorScheme;

    if (patient.id.trim().isEmpty) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(
          content: Text(
            dialogContext.tr(
              "This patient is missing an id, so it cannot be deleted.",
            ),
          ),
          backgroundColor: cs.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final confirmed = await _showDeletePatientConfirmationDialog(
      dialogContext,
      patient,
    );
    if (confirmed != true || !dialogContext.mounted) {
      return;
    }

    final patientsCubit = dialogContext.read<PatientsCubit>();
    final deleted = await patientsCubit.deletePatient(patient.id);
    if (!dialogContext.mounted) return;

    if (deleted) {
      await _loadPatients();
      if (!dialogContext.mounted) return;
      Navigator.pop(dialogContext);
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(
          content: Text(dialogContext.tr("Patient deleted successfully!")),
          backgroundColor: cs.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final errorMessage = patientsCubit.state.errorMessage;
    ScaffoldMessenger.of(dialogContext).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage ?? dialogContext.tr("Failed to delete patient"),
        ),
        backgroundColor: cs.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<bool?> _showDeletePatientConfirmationDialog(
    BuildContext context,
    Patient patient,
  ) {
    final cs = Theme.of(context).colorScheme;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.error),
            const SizedBox(width: 12),
            Text(dialogContext.tr("Delete Patient")),
          ],
        ),
        content: Text(
          dialogContext.tr("Are you sure you want to delete this patient?"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr("Cancel")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            child: Text(dialogContext.tr("Delete")),
          ),
        ],
      ),
    );
  }

  void _showPatientHistoryDialog(BuildContext context, Patient patient) {
    if (patient.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              "This patient is missing an id, so the history could not be loaded.",
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final historyFuture = context
        .read<MedicalHistoryCubit>()
        .fetchAllHistoryRecords(patientId: patient.id);

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final cs = theme.colorScheme;

        return Dialog(
          insetPadding: _dialogInsetPadding(dialogContext),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            width: _responsiveDialogWidth(dialogContext, 980),
            constraints: const BoxConstraints(maxHeight: 820),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: FutureBuilder<List<PatientHistoryRecord>>(
              future: historyFuture,
              builder: (context, snapshot) {
                final sortedRecords = _sortHistoryRecordsForDisplay(
                  snapshot.data ?? const <PatientHistoryRecord>[],
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 28, 20, 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cs.primary,
                            cs.primaryContainer.withOpacity(0.92),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.history_edu_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dialogContext.tr("Patient History"),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        patient.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    _buildModernMetaChip(
                                      dialogContext,
                                      Icons.folder_copy_outlined,
                                      snapshot.connectionState ==
                                              ConnectionState.waiting
                                          ? dialogContext.tr(
                                              "Loading records...",
                                            )
                                          : "${sortedRecords.length} ${dialogContext.tr("records")}",
                                      Colors.white,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              tooltip: 'Close',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Builder(
                        builder: (context) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return AsyncStatePanel(
                              icon: Icons.history_edu_outlined,
                              title: dialogContext.tr("Loading medical records..."),
                              child: const CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            final message = snapshot.error is Exception
                                ? snapshot.error.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  )
                                : dialogContext.tr(
                                    "Failed to load patient history.",
                                  );

                            return AsyncStatePanel(
                              icon: Icons.error_outline,
                              title: message,
                              isError: true,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  _showPatientHistoryDialog(context, patient);
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: Text(dialogContext.tr("Try Again")),
                              ),
                            );
                          }

                          if (sortedRecords.isEmpty) {
                            return AsyncStatePanel(
                              icon: Icons.history_toggle_off_outlined,
                              title: dialogContext.tr("No medical records found"),
                              message: dialogContext.tr(
                                "This patient hasn't had any medical records yet.",
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.all(24),
                            itemCount: sortedRecords.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final record = sortedRecords[index];
                              return _buildHistoryTimelineTile(
                                dialogContext,
                                record: record,
                                index: index,
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  _showHistoryRecordDetailsDialog(
                                    context,
                                    patient: patient,
                                    record: record,
                                    index: index,
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: cs.outlineVariant.withOpacity(0.3),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(dialogContext.tr("Close")),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showLatestTreatmentPlanDialog(BuildContext context, Patient patient) {
    if (patient.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              "This patient is missing an id, so the treatment plan could not be loaded.",
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final treatmentPlanFuture = context
        .read<TreatmentPlanCubit>()
        .fetchLatestTreatmentPlan(patientUserId: patient.id);

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final cs = theme.colorScheme;

        return Dialog(
          insetPadding: _dialogInsetPadding(dialogContext),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            width: _responsiveDialogWidth(dialogContext, 900),
            constraints: const BoxConstraints(maxHeight: 800),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: FutureBuilder<LatestTreatmentPlanRecord>(
              future: treatmentPlanFuture,
              builder: (context, snapshot) {
                final treatmentPlanData = _normalizeTreatmentPlanForDisplay(
                  snapshot.data?.rawData ?? const <String, dynamic>{},
                );
                final treatmentPlanEntries = _buildTreatmentPlanEntries(
                  treatmentPlanData,
                );
                final createdAt = _formatHistoryRecordDate(
                  treatmentPlanData['createdAt'],
                );
                final updatedAt = _formatHistoryRecordDate(
                  treatmentPlanData['updatedAt'],
                );

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 28, 20, 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cs.secondary,
                            cs.primaryContainer.withOpacity(0.92),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.assignment_turned_in_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dialogContext.tr("Latest Treatment Plan"),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        patient.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (snapshot.connectionState !=
                                        ConnectionState.waiting)
                                      _buildModernMetaChip(
                                        dialogContext,
                                        Icons.article_outlined,
                                        "${treatmentPlanEntries.length} fields",
                                        Colors.white,
                                      ),
                                    if (createdAt != '-')
                                      _buildModernMetaChip(
                                        dialogContext,
                                        Icons.calendar_today_outlined,
                                        createdAt,
                                        Colors.white,
                                      ),
                                    if (updatedAt != '-' &&
                                        updatedAt != createdAt)
                                      _buildModernMetaChip(
                                        dialogContext,
                                        Icons.update,
                                        "Updated: $updatedAt",
                                        Colors.white,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              tooltip: 'Close',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Builder(
                        builder: (context) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return AsyncStatePanel(
                              icon: Icons.assignment_turned_in_outlined,
                              title: dialogContext.tr("Loading treatment plan..."),
                              child: const CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            final message = snapshot.error is Exception
                                ? snapshot.error.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  )
                                : dialogContext.tr(
                                    "Failed to load treatment plan.",
                                  );

                            return AsyncStatePanel(
                              icon: Icons.error_outline,
                              title: message,
                              isError: true,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  _showLatestTreatmentPlanDialog(
                                    context,
                                    patient,
                                  );
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: Text(dialogContext.tr("Try Again")),
                              ),
                            );
                          }

                          if (treatmentPlanEntries.isEmpty) {
                            return AsyncStatePanel(
                              icon: Icons.assignment_late_outlined,
                              title: dialogContext.tr("No treatment plan found"),
                              message: dialogContext.tr(
                                "This patient does not have a saved treatment plan yet.",
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.all(24),
                            itemCount: treatmentPlanEntries.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final entry = treatmentPlanEntries[index];
                              return Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest
                                      .withOpacity(0.22),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: cs.outlineVariant.withOpacity(0.35),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _treatmentPlanLabel(
                                        dialogContext,
                                        entry.key,
                                      ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: cs.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatHistoryRecordValue(entry.value),
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.45,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: cs.outlineVariant.withOpacity(0.3),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(dialogContext.tr("Close")),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showTreatmentPlanHistoryDialog(BuildContext context, Patient patient) {
    if (patient.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              "This patient is missing an id, so the treatment plans could not be loaded.",
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final treatmentPlansFuture = context
        .read<TreatmentPlanCubit>()
        .fetchAllTreatmentPlans(patientUserId: patient.id);

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final cs = theme.colorScheme;

        return Dialog(
          insetPadding: _dialogInsetPadding(dialogContext),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            width: _responsiveDialogWidth(dialogContext, 920),
            constraints: const BoxConstraints(maxHeight: 820),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: FutureBuilder<List<LatestTreatmentPlanRecord>>(
              future: treatmentPlansFuture,
              builder: (context, snapshot) {
                final plans = _sortTreatmentPlansForDisplay(
                  snapshot.data ?? const <LatestTreatmentPlanRecord>[],
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 28, 20, 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cs.secondary,
                            cs.primaryContainer.withOpacity(0.92),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.medical_information_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dialogContext.tr("Treatment History"),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        patient.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    _buildModernMetaChip(
                                      dialogContext,
                                      Icons.folder_copy_outlined,
                                      snapshot.connectionState ==
                                              ConnectionState.waiting
                                          ? dialogContext.tr(
                                              "Loading plans...",
                                            )
                                          : "${plans.length} ${dialogContext.tr("plans")}",
                                      Colors.white,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              tooltip: 'Close',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Builder(
                        builder: (context) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return AsyncStatePanel(
                              icon: Icons.medical_information_outlined,
                              title: dialogContext.tr("Loading treatment plans..."),
                              child: const CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            final message = snapshot.error is Exception
                                ? snapshot.error.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  )
                                : dialogContext.tr(
                                    "Failed to load treatment history.",
                                  );

                            return AsyncStatePanel(
                              icon: Icons.error_outline,
                              title: message,
                              isError: true,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  _showTreatmentPlanHistoryDialog(
                                    context,
                                    patient,
                                  );
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: Text(dialogContext.tr("Try Again")),
                              ),
                            );
                          }

                          if (plans.isEmpty) {
                            return AsyncStatePanel(
                              icon: Icons.assignment_late_outlined,
                              title: dialogContext.tr("No treatment plans found"),
                              message: dialogContext.tr(
                                "This patient does not have any saved treatment plans yet.",
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.all(24),
                            itemCount: plans.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final record = plans[index];
                              final recordData = _normalizeTreatmentPlanForDisplay(
                                record.rawData,
                              );
                              final createdAt = _formatHistoryRecordDate(
                                recordData['createdAt'],
                              );
                              final phase = _formatHistoryRecordValue(
                                recordData['phase'],
                              );
                              final treatmentType = _formatHistoryRecordValue(
                                recordData['treatmentType'],
                              );

                              final subtitleParts = <String>[
                                if (phase != '-') phase,
                                if (treatmentType != '-') treatmentType,
                              ];

                              return InkWell(
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  _showTreatmentPlanRecordDialog(
                                    context,
                                    patient: patient,
                                    treatmentPlanData: recordData,
                                    title: "Treatment Plan",
                                  );
                                },
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest
                                        .withOpacity(0.22),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: cs.outlineVariant.withOpacity(
                                        0.35,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: cs.secondary.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.event_note_outlined,
                                          color: cs.secondary,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              createdAt == '-'
                                                  ? dialogContext.tr(
                                                      "Unknown date",
                                                    )
                                                  : createdAt,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: cs.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              subtitleParts.isEmpty
                                                  ? dialogContext.tr(
                                                      "Tap to view treatment plan details",
                                                    )
                                                  : subtitleParts.join(" • "),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: cs.outlineVariant.withOpacity(0.3),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(dialogContext.tr("Close")),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showTreatmentPlanRecordDialog(
    BuildContext context, {
    required Patient patient,
    required Map<String, dynamic> treatmentPlanData,
    required String title,
  }) {
    final normalizedData = _normalizeTreatmentPlanForDisplay(treatmentPlanData);
    final treatmentPlanEntries = _buildTreatmentPlanEntries(normalizedData);
    final createdAt = _formatHistoryRecordDate(normalizedData['createdAt']);
    final updatedAt = _formatHistoryRecordDate(normalizedData['updatedAt']);

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final cs = theme.colorScheme;

        return Dialog(
          insetPadding: _dialogInsetPadding(dialogContext),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            width: _responsiveDialogWidth(dialogContext, 900),
            constraints: const BoxConstraints(maxHeight: 800),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(28, 28, 20, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.secondary,
                        cs.primaryContainer.withOpacity(0.92),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.assignment_turned_in_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dialogContext.tr(title),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    patient.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                _buildModernMetaChip(
                                  dialogContext,
                                  Icons.article_outlined,
                                  "${treatmentPlanEntries.length} fields",
                                  Colors.white,
                                ),
                                if (createdAt != '-')
                                  _buildModernMetaChip(
                                    dialogContext,
                                    Icons.calendar_today_outlined,
                                    createdAt,
                                    Colors.white,
                                  ),
                                if (updatedAt != '-' && updatedAt != createdAt)
                                  _buildModernMetaChip(
                                    dialogContext,
                                    Icons.update,
                                    "Updated: $updatedAt",
                                    Colors.white,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                          tooltip: 'Close',
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: treatmentPlanEntries.isEmpty
                      ? Center(
                          child: Text(
                            dialogContext.tr("No treatment plan found"),
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: treatmentPlanEntries.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final entry = treatmentPlanEntries[index];
                            return Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withOpacity(
                                  0.22,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: cs.outlineVariant.withOpacity(0.35),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _treatmentPlanLabel(dialogContext, entry.key),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: cs.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatHistoryRecordValue(entry.value),
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.45,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: cs.outlineVariant.withOpacity(0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(dialogContext.tr("Close")),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<LatestTreatmentPlanRecord> _sortTreatmentPlansForDisplay(
    List<LatestTreatmentPlanRecord> records,
  ) {
    final sorted = List<LatestTreatmentPlanRecord>.from(records);
    sorted.sort((a, b) {
      final aData = _normalizeTreatmentPlanForDisplay(a.rawData);
      final bData = _normalizeTreatmentPlanForDisplay(b.rawData);
      final aDate = DateTime.tryParse(aData['createdAt']?.toString() ?? '');
      final bDate = DateTime.tryParse(bData['createdAt']?.toString() ?? '');

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return sorted;
  }

  void _showLastRecordDialog(BuildContext context, Patient patient) {
    if (patient.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              "This patient is missing an id, so the last record could not be loaded.",
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final historyFuture = context
        .read<MedicalHistoryCubit>()
        .fetchLatestHistoryRecord(patientId: patient.id);

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final cs = theme.colorScheme;

        return Dialog(
          insetPadding: _dialogInsetPadding(dialogContext),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            width: _responsiveDialogWidth(dialogContext, 900),
            constraints: const BoxConstraints(maxHeight: 800),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: FutureBuilder<PatientHistoryRecord>(
              future: historyFuture,
              builder: (context, snapshot) {
                final recordData = _normalizeHistoryRecordForDisplay(
                  snapshot.data?.rawData ?? const <String, dynamic>{},
                );
                final recordEntries = _buildHistoryRecordEntries(recordData);
                final customAnswers = _extractQuestionAnswers(
                  recordData['customQuestionAnswers'],
                );
                final images = _extractImageAttachments(recordData['images']);
                final createdAt = _formatHistoryRecordDate(
                  recordData['createdAt'],
                );
                final updatedAt = _formatHistoryRecordDate(
                  recordData['updatedAt'],
                );

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Modern Header with Gradient
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 28, 20, 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cs.primary,
                            cs.primaryContainer.withOpacity(0.9),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.assignment_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dialogContext.tr("Last Medical Record"),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        patient.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildModernMetaChip(
                                      dialogContext,
                                      Icons.article_outlined,
                                      "${recordEntries.length} fields",
                                      Colors.white,
                                    ),
                                    if (createdAt != '-')
                                      _buildModernMetaChip(
                                        dialogContext,
                                        Icons.calendar_today,
                                        createdAt,
                                        Colors.white,
                                      ),
                                    if (updatedAt != '-' &&
                                        updatedAt != createdAt)
                                      _buildModernMetaChip(
                                        dialogContext,
                                        Icons.update,
                                        "Updated: $updatedAt",
                                        Colors.white,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              tooltip: 'Close',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Content Area with Scroll
                    Flexible(
                      child: Builder(
                        builder: (context) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return AsyncStatePanel(
                              icon: Icons.medical_information_outlined,
                              title: dialogContext.tr("Loading medical records..."),
                              child: const CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            final message = snapshot.error is Exception
                                ? snapshot.error.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  )
                                : dialogContext.tr(
                                    "Failed to load the last record.",
                                  );

                            return AsyncStatePanel(
                              icon: Icons.error_outline,
                              title: message,
                              isError: true,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  _showLastRecordDialog(context, patient);
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: Text(dialogContext.tr("Try Again")),
                              ),
                            );
                          }

                          if (recordEntries.isEmpty &&
                              customAnswers.isEmpty &&
                              images.isEmpty) {
                            return AsyncStatePanel(
                              icon: Icons.medical_information_outlined,
                              title: dialogContext.tr("No medical records found"),
                              message: dialogContext.tr(
                                "This patient hasn't had any medical records yet.",
                              ),
                            );
                          }

                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Clinical Information Section
                                if (recordEntries.isNotEmpty)
                                  _buildModernSection(
                                    dialogContext,
                                    title: "Clinical Information",
                                    icon: Icons.health_and_safety_outlined,
                                    color: cs.primary,
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final columns =
                                            constraints.maxWidth >= 800
                                            ? 3
                                            : constraints.maxWidth >= 550
                                            ? 2
                                            : 1;
                                        final spacing = 14.0;
                                        final itemWidth =
                                            (constraints.maxWidth -
                                                (spacing * (columns - 1))) /
                                            columns;

                                        return Wrap(
                                          spacing: spacing,
                                          runSpacing: spacing,
                                          children: recordEntries
                                              .map(
                                                (entry) => SizedBox(
                                                  width: itemWidth,
                                                  child: _buildModernInfoCard(
                                                    dialogContext,
                                                    _historyRecordLabel(
                                                      dialogContext,
                                                      entry.key,
                                                    ),
                                                    _formatHistoryRecordValue(
                                                      entry.value,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(growable: false),
                                        );
                                      },
                                    ),
                                  ),

                                if (customAnswers.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  _buildModernSection(
                                    dialogContext,
                                    title: "Custom Questionnaire",
                                    icon: Icons.quiz_outlined,
                                    color: Colors.purple,
                                    child: Column(
                                      children: customAnswers
                                          .map(
                                            (answer) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              child: _buildModernQACard(
                                                dialogContext,
                                                question: answer.question,
                                                answer: answer.answer,
                                              ),
                                            ),
                                          )
                                          .toList(growable: false),
                                    ),
                                  ),
                                ],

                                if (images.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  _buildModernSection(
                                    dialogContext,
                                    title: "Medical Images",
                                    icon: Icons.image_outlined,
                                    color: Colors.teal,
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: images
                                          .map(
                                            (image) => _buildModernImageCard(
                                              dialogContext,
                                              image,
                                            ),
                                          )
                                          .toList(growable: false),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Footer with Action Buttons
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: cs.outlineVariant.withOpacity(0.3),
                          ),
                        ),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        runSpacing: 8,
                        spacing: 12,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(dialogContext.tr("Close")),
                          ),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    dialogContext.tr(
                                      "Export feature coming soon",
                                    ),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.download_outlined, size: 18),
                            label: Text(dialogContext.tr("Export Record")),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<PatientHistoryRecord> _sortHistoryRecordsForDisplay(
    List<PatientHistoryRecord> records,
  ) {
    final sorted = [...records];
    sorted.sort((a, b) {
      final aData = _normalizeHistoryRecordForDisplay(a.rawData);
      final bData = _normalizeHistoryRecordForDisplay(b.rawData);
      final aTimestamp = _parseHistoryTimestamp(
        aData['createdAt'] ?? aData['updatedAt'],
      );
      final bTimestamp = _parseHistoryTimestamp(
        bData['createdAt'] ?? bData['updatedAt'],
      );

      if (aTimestamp == null && bTimestamp == null) return 0;
      if (aTimestamp == null) return 1;
      if (bTimestamp == null) return -1;
      return bTimestamp.compareTo(aTimestamp);
    });
    return sorted;
  }

  DateTime? _parseHistoryTimestamp(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Widget _buildHistoryTimelineTile(
    BuildContext context, {
    required PatientHistoryRecord record,
    required int index,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final recordData = _normalizeHistoryRecordForDisplay(record.rawData);
    final createdAt = _formatHistoryRecordDate(
      recordData['createdAt'] ?? recordData['updatedAt'],
    );
    final displayDate =
        createdAt == '-' ? context.tr("Unknown date") : createdAt;
    final symptomDuration = _formatHistoryRecordValue(
      recordData['symptomDuration'],
    );
    final diagnosisResult = _formatHistoryRecordValue(
      recordData['diagnosisResult'],
    );

    final subtitleParts = <String>[
      if (symptomDuration != '-') symptomDuration,
      if (diagnosisResult != '-') diagnosisResult,
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.22),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: cs.outlineVariant.withOpacity(0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.history_edu_outlined,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayDate,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitleParts.isEmpty
                        ? dialogRecordTitle(context, index)
                        : subtitleParts.join(" • "),
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _showHistoryRecordDetailsDialog(
    BuildContext context, {
    required Patient patient,
    required PatientHistoryRecord record,
    required int index,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final cs = theme.colorScheme;
        final recordData = _normalizeHistoryRecordForDisplay(record.rawData);
        final createdAt = _formatHistoryRecordDate(
          recordData['createdAt'] ?? recordData['updatedAt'],
        );

        return Dialog(
          insetPadding: _dialogInsetPadding(dialogContext),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            width: _responsiveDialogWidth(dialogContext, 900),
            constraints: const BoxConstraints(maxHeight: 800),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(28, 28, 20, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary,
                        cs.primaryContainer.withOpacity(0.9),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.assignment_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dialogContext.tr("Medical Record"),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    patient.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (createdAt != '-')
                                  _buildModernMetaChip(
                                    dialogContext,
                                    Icons.calendar_today,
                                    createdAt,
                                    Colors.white,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                          tooltip: 'Close',
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _buildPatientHistoryRecordCard(
                      dialogContext,
                      patient: patient,
                      record: record,
                      index: index,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: cs.outlineVariant.withOpacity(0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(dialogContext.tr("Close")),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPatientHistoryRecordCard(
    BuildContext context, {
    required Patient patient,
    required PatientHistoryRecord record,
    required int index,
  }) {
    final cs = Theme.of(context).colorScheme;
    final recordData = _normalizeHistoryRecordForDisplay(record.rawData);
    final recordEntries = _buildHistoryRecordEntries(recordData);
    final customAnswers = _extractQuestionAnswers(
      recordData['customQuestionAnswers'],
    );
    final images = _extractImageAttachments(recordData['images']);
    final createdAt = _formatHistoryRecordDate(recordData['createdAt']);
    final updatedAt = _formatHistoryRecordDate(recordData['updatedAt']);
    final recordTitle = dialogRecordTitle(context, index);
    final visibleFieldCount =
        recordEntries.length + customAnswers.length + images.length;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.primary.withOpacity(0.72)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recordTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildHistorySummaryChip(
                          context,
                          icon: Icons.person_outline,
                          label: patient.name,
                        ),
                        _buildHistorySummaryChip(
                          context,
                          icon: Icons.article_outlined,
                          label: "$visibleFieldCount ${context.tr("items")}",
                        ),
                        if (createdAt != '-')
                          _buildHistorySummaryChip(
                            context,
                            icon: Icons.calendar_today_outlined,
                            label: createdAt,
                          ),
                        if (updatedAt != '-' && updatedAt != createdAt)
                          _buildHistorySummaryChip(
                            context,
                            icon: Icons.update_outlined,
                            label: "Updated: $updatedAt",
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_recordHasRenderableContent(recordEntries, customAnswers, images))
            const SizedBox(height: 22),
          if (recordEntries.isNotEmpty)
            _buildModernSection(
              context,
              title: "Clinical Information",
              icon: Icons.health_and_safety_outlined,
              color: cs.primary,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 820
                      ? 3
                      : constraints.maxWidth >= 540
                      ? 2
                      : 1;
                  final spacing = 14.0;
                  final itemWidth =
                      (constraints.maxWidth - (spacing * (columns - 1))) /
                      columns;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: recordEntries
                        .map(
                          (entry) => SizedBox(
                            width: itemWidth,
                            child: _buildModernInfoCard(
                              context,
                              _historyRecordLabel(context, entry.key),
                              _formatHistoryRecordValue(entry.value),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
            ),
          if (customAnswers.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildModernSection(
              context,
              title: "Custom Questionnaire",
              icon: Icons.quiz_outlined,
              color: Colors.purple,
              child: Column(
                children: customAnswers
                    .map(
                      (answer) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildModernQACard(
                          context,
                          question: answer.question,
                          answer: answer.answer,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
          if (images.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildModernSection(
              context,
              title: "Medical Images",
              icon: Icons.image_outlined,
              color: Colors.teal,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: images
                    .map((image) => _buildModernImageCard(context, image))
                    .toList(growable: false),
              ),
            ),
          ],
          if (!_recordHasRenderableContent(
            recordEntries,
            customAnswers,
            images,
          ))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.28),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                context.tr("No visible details were returned for this record."),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _recordHasRenderableContent(
    List<MapEntry<String, dynamic>> recordEntries,
    List<MedicalHistoryQuestionAnswer> customAnswers,
    List<Map<String, String>> images,
  ) {
    return recordEntries.isNotEmpty ||
        customAnswers.isNotEmpty ||
        images.isNotEmpty;
  }

  String dialogRecordTitle(BuildContext context, int index) {
    return "${context.tr("Record")} ${index + 1}";
  }

  Map<String, dynamic> _normalizeHistoryRecordForDisplay(
    Map<String, dynamic> record,
  ) {
    if (record.isEmpty) return record;

    final nestedCandidates = [
      record['record'],
      record['historyRecord'],
      record['latestRecord'],
      record['data'],
      record['item'],
      record['value'],
    ];

    for (final candidate in nestedCandidates) {
      final normalized = _decodeHistoryRecordCandidate(candidate);
      if (normalized != null && normalized.isNotEmpty) {
        final merged = <String, dynamic>{...normalized};
        _mergeHistoryRecordMetadata(record, merged);
        return merged;
      }
    }

    return record;
  }

  void _mergeHistoryRecordMetadata(
    Map<String, dynamic> source,
    Map<String, dynamic> target,
  ) {
    const metadataKeys = {
      'id',
      '_id',
      'patientId',
      'patientUserId',
      'createdPatientId',
      'createdAt',
      'updatedAt',
    };

    for (final key in metadataKeys) {
      if (target.containsKey(key) && !_isEmptyHistoryValue(target[key])) {
        continue;
      }

      final value = source[key];
      if (_isEmptyHistoryValue(value)) continue;
      target[key] = value;
    }
  }

  Map<String, dynamic>? _decodeHistoryRecordCandidate(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;

      try {
        return _decodeHistoryRecordCandidate(jsonDecode(trimmed));
      } catch (_) {
        return null;
      }
    }

    if (value is Map<String, dynamic>) {
      return _normalizeHistoryRecordForDisplay(value);
    }

    if (value is Map) {
      return _normalizeHistoryRecordForDisplay(
        value.map((key, dynamic value) => MapEntry(key.toString(), value)),
      );
    }

    return null;
  }

  List<MapEntry<String, dynamic>> _buildHistoryRecordEntries(
    Map<String, dynamic> record,
  ) {
    const preferredOrder = [
      'patientName',
      'patientPhone',
      'patientAge',
      'patientSex',
      'symptomDuration',
      'familyHistory',
      'previousTreatmentHistory',
      'shortnessOfBreath',
      'coughingBlood',
      'chestPain',
      'faintingOrSevereDizziness',
      'recentWeightLoss',
      'smoker',
      'profession',
      'hoarseness',
      'symptomSectionNotes',
      'diagnosisResult',
      'customQuestionAnswers',
      'images',
      'createdAt',
      'updatedAt',
    ];

    final entries = <MapEntry<String, dynamic>>[];
    final seenKeys = <String>{};

    for (final key in preferredOrder) {
      if (!record.containsKey(key)) continue;
      final value = record[key];
      if (_isEmptyHistoryValue(value)) continue;
      if (key == 'customQuestionAnswers' || key == 'images') continue;
      if (_isHistoryMetadataKey(key)) continue;
      entries.add(MapEntry(key, value));
      seenKeys.add(key);
    }

    for (final entry in record.entries) {
      if (seenKeys.contains(entry.key) || _isEmptyHistoryValue(entry.value)) {
        continue;
      }
      if (entry.key == 'customQuestionAnswers' || entry.key == 'images') {
        continue;
      }
      if (_isHistoryMetadataKey(entry.key)) continue;
      entries.add(entry);
    }

    return entries;
  }

  bool _isEmptyHistoryValue(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Iterable) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return false;
  }

  bool _isHistoryMetadataKey(String key) {
    const metadataKeys = {
      'id',
      '_id',
      'patientId',
      'patientUserId',
      'createdPatientId',
      '__v',
      'createdAt',
      'updatedAt',
    };
    return metadataKeys.contains(key);
  }

  String _historyRecordLabel(BuildContext context, String key) {
    const labels = {
      'patientName': 'Patient Name',
      'patientPhone': 'Patient Phone',
      'patientAge': 'Patient Age',
      'patientSex': 'Patient Sex',
      'symptomDuration': 'Symptom Duration',
      'familyHistory': 'Family History',
      'previousTreatmentHistory': 'Previous Treatment History',
      'shortnessOfBreath': 'Shortness of Breath',
      'coughingBlood': 'Coughing Blood',
      'chestPain': 'Chest Pain',
      'faintingOrSevereDizziness': 'Fainting or Severe Dizziness',
      'recentWeightLoss': 'Recent Weight Loss',
      'smoker': 'Smoker',
      'profession': 'Profession',
      'hoarseness': 'Hoarseness of Voice',
      'symptomSectionNotes': 'Additional Notes',
      'customQuestionAnswers': 'Custom Question Answers',
      'images': 'Images',
      'diagnosisResult': 'Diagnosis Result',
      'createdAt': 'Created At',
      'updatedAt': 'Updated At',
      'value': 'Record',
    };

    return context.tr(labels[key] ?? _humanizeHistoryKey(key));
  }

  Map<String, dynamic> _normalizeTreatmentPlanForDisplay(
    Map<String, dynamic> record,
  ) {
    if (record.isEmpty) return record;

    final nestedCandidates = [
      record['treatmentPlan'],
      record['latestTreatmentPlan'],
      record['plan'],
      record['data'],
      record['item'],
      record['value'],
    ];

    for (final candidate in nestedCandidates) {
      final normalized = _decodeTreatmentPlanCandidate(candidate);
      if (normalized != null && normalized.isNotEmpty) {
        final merged = <String, dynamic>{...normalized};
        _mergeTreatmentPlanMetadata(record, merged);
        return merged;
      }
    }

    return record;
  }

  Map<String, dynamic>? _decodeTreatmentPlanCandidate(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;

      try {
        return _decodeTreatmentPlanCandidate(jsonDecode(trimmed));
      } catch (_) {
        return null;
      }
    }

    if (value is Map<String, dynamic>) {
      return _normalizeTreatmentPlanForDisplay(value);
    }

    if (value is Map) {
      return _normalizeTreatmentPlanForDisplay(
        value.map((key, dynamic value) => MapEntry(key.toString(), value)),
      );
    }

    return null;
  }

  void _mergeTreatmentPlanMetadata(
    Map<String, dynamic> source,
    Map<String, dynamic> target,
  ) {
    const metadataKeys = {
      'id',
      '_id',
      'patientId',
      'patientUserId',
      'createdPatientId',
      'doctorId',
      'doctorUserId',
      'createdAt',
      'updatedAt',
    };

    for (final key in metadataKeys) {
      if (target.containsKey(key) && !_isEmptyHistoryValue(target[key])) {
        continue;
      }

      final value = source[key];
      if (_isEmptyHistoryValue(value)) continue;
      target[key] = value;
    }
  }

  List<MapEntry<String, dynamic>> _buildTreatmentPlanEntries(
    Map<String, dynamic> plan,
  ) {
    const preferredOrder = [
      'phase',
      'status',
      'lungCancerType',
      'treatmentType',
      'commonMedicines',
      'additionalMedicines',
      'reviewPeriod',
      'nextReviewDate',
      'startDate',
      'endDate',
      'notes',
      'createdAt',
      'updatedAt',
    ];

    final entries = <MapEntry<String, dynamic>>[];
    final seenKeys = <String>{};

    for (final key in preferredOrder) {
      if (!plan.containsKey(key)) continue;
      final value = plan[key];
      if (_isEmptyHistoryValue(value)) continue;
      if (_isTreatmentPlanMetadataKey(key)) continue;
      entries.add(MapEntry(key, value));
      seenKeys.add(key);
    }

    for (final entry in plan.entries) {
      if (seenKeys.contains(entry.key) || _isEmptyHistoryValue(entry.value)) {
        continue;
      }
      if (_isTreatmentPlanMetadataKey(entry.key)) continue;
      entries.add(entry);
    }

    return entries;
  }

  bool _isTreatmentPlanMetadataKey(String key) {
    const metadataKeys = {
      'id',
      '_id',
      'patientId',
      'patientUserId',
      'createdPatientId',
      'doctorId',
      'doctorUserId',
      '__v',
      'createdAt',
      'updatedAt',
    };
    return metadataKeys.contains(key);
  }

  String _treatmentPlanLabel(BuildContext context, String key) {
    const labels = {
      'phase': 'Phase',
      'status': 'Status',
      'lungCancerType': 'Lung Cancer Type',
      'treatmentType': 'Treatment Type',
      'commonMedicines': 'Common Medicines',
      'additionalMedicines': 'Additional Medicines',
      'reviewPeriod': 'Review Time Period',
      'nextReviewDate': 'Next Review Date',
      'startDate': 'Start Date',
      'endDate': 'End Date',
      'notes': 'Notes',
      'value': 'Treatment Plan',
    };

    return context.tr(labels[key] ?? _humanizeHistoryKey(key));
  }

  String _humanizeHistoryKey(String key) {
    final withSpaces = key
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll('_', ' ')
        .trim();

    if (withSpaces.isEmpty) return key;

    return withSpaces
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _formatHistoryRecordValue(dynamic value) {
    if (value == null) return '-';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is num) return value.toString();
    if (value is String) return value.trim().isEmpty ? '-' : value.trim();
    if (value is List) {
      if (value.isEmpty) return '-';
      return value.map(_formatListHistoryValue).join('\n');
    }
    if (value is Map) {
      if (value.isEmpty) return '-';
      if (value.containsKey('question') || value.containsKey('answer')) {
        final question = value['question']?.toString().trim() ?? '';
        final answer = value['answer']?.toString().trim() ?? '';
        if (question.isNotEmpty && answer.isNotEmpty) {
          return '$question: $answer';
        }
      }

      return value.entries
          .where((entry) => !_isEmptyHistoryValue(entry.value))
          .map(
            (entry) =>
                '${_humanizeHistoryKey(entry.key)}: ${_formatHistoryRecordValue(entry.value)}',
          )
          .join('\n');
    }
    return value.toString();
  }

  String _formatHistoryRecordDate(dynamic value) {
    if (value == null) return '-';

    final raw = value.toString().trim();
    if (raw.isEmpty) return '-';

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return _formatHistoryRecordValue(value);

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();
    return '$day/$month/$year';
  }

  String _formatListHistoryValue(dynamic item) {
    if (item is Map) {
      final question = item['question']?.toString().trim() ?? '';
      final answer = item['answer']?.toString().trim() ?? '';
      if (question.isNotEmpty && answer.isNotEmpty) {
        return '$question: $answer';
      }
    }

    return _formatHistoryRecordValue(item);
  }

  // Modern helper widgets for the redesigned dialog

  Widget _buildModernMetaChip(
    BuildContext context,
    IconData icon,
    String label,
    Color textColor,
  ) {
    return PatientModernMetaChip(
      icon: icon,
      label: label,
      textColor: textColor,
    );
  }

  Widget _buildHistorySummaryChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return PatientHistorySummaryChip(
      icon: icon,
      label: label,
    );
  }

  Widget _buildModernSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return PatientModernSection(
      title: title,
      icon: icon,
      color: color,
      child: child,
    );
  }

  Widget _buildModernInfoCard(
    BuildContext context,
    String label,
    String value,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isBoolean = value == 'Yes' || value == 'No';
    final isPositive = value == 'Yes';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBoolean
                    ? (isPositive ? Icons.check_circle : Icons.cancel)
                    : Icons.info_outline,
                size: 16,
                color: isBoolean
                    ? (isPositive ? Colors.green : cs.onSurfaceVariant)
                    : cs.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isBoolean)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isPositive
                    ? Colors.green.withOpacity(0.1)
                    : cs.errorContainer.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isPositive ? Colors.green.shade700 : cs.error,
                ),
              ),
            )
          else
            SelectableText(
              value,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernQACard(
    BuildContext context, {
    required String question,
    required String answer,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surfaceContainerHighest.withOpacity(0.2),
            cs.surfaceContainerHighest.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "Question",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.purple,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            question.isEmpty ? '-' : question,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "Answer",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.primary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            answer.isEmpty ? '-' : answer,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernImageCard(
    BuildContext context,
    Map<String, String> image,
  ) {
    final cs = Theme.of(context).colorScheme;
    final preview = (image['preview'] ?? '').trim();
    final previewCandidates = _buildImagePreviewCandidates(preview);
    final imageAuthHeaders = _buildImageAuthHeaders(context);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: previewCandidates.isEmpty
                  ? null
                  : () => _showImagePreviewDialog(context, previewCandidates),
              child: Ink(
                width: double.infinity,
                height: 190,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: previewCandidates.isEmpty
                      ? _buildImageFallback(cs)
                      : _ProgressiveNetworkImage(
                          urls: previewCandidates,
                          headers: imageAuthHeaders,
                          fallback: _buildImageFallback(cs),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePreviewDialog(
    BuildContext context,
    List<String> previewCandidates,
  ) {
    final imageAuthHeaders = _buildImageAuthHeaders(context);
    showDialog(
      context: context,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        final size = MediaQuery.of(dialogContext).size;

        return Dialog(
          insetPadding: _dialogInsetPadding(dialogContext),
          backgroundColor: Colors.black.withOpacity(0.9),
          child: Stack(
            children: [
              SizedBox(
                width: size.width * 0.88,
                height: size.height * 0.82,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Center(
                    child: _ProgressiveNetworkImage(
                      urls: previewCandidates,
                      headers: imageAuthHeaders,
                      fit: BoxFit.contain,
                      fallback: _buildImageFallback(cs),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.35),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, String>? _buildImageAuthHeaders(BuildContext context) {
    final token = context.read<AuthCubit>().state.token?.trim();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  Widget _buildImageFallback(ColorScheme cs) {
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: 48,
        color: cs.onSurfaceVariant.withOpacity(0.5),
      ),
    );
  }

  List<String> _buildImagePreviewCandidates(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty) return const [];

    final parsed = Uri.tryParse(raw);
    if (parsed != null &&
        (parsed.scheme == 'http' || parsed.scheme == 'https')) {
      return [raw];
    }

    final baseUri = Uri.tryParse(AuthCubit.defaultApiBaseUrl.trim());
    if (baseUri == null || baseUri.host.isEmpty) return const [];

    final origin = '${baseUri.scheme}://${baseUri.authority}';
    final normalized = raw.replaceFirst(RegExp(r'^/+'), '');
    final filename = normalized.split('/').last;

    final candidates = <String>[
      if (raw.startsWith('/')) '$origin$raw' else '$origin/$normalized',
      '$origin/uploads/$filename',
      '$origin/api/uploads/$filename',
      '$origin/images/$filename',
      '$origin/storage/$filename',
    ];

    return candidates.toSet().toList(growable: false);
  }

  Widget _buildRecordInfoCard(
    BuildContext context,
    String label,
    String value,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isBoolean = value == 'Yes' || value == 'No';
    final isPositive = value == 'Yes';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (isBoolean)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isPositive
                    ? Colors.green.withOpacity(0.12)
                    : cs.surfaceContainerHighest.withOpacity(0.6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive
                        ? Icons.check_circle_outline
                        : Icons.remove_circle_outline,
                    size: 16,
                    color: isPositive ? Colors.green : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isPositive
                          ? Colors.green.shade700
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            SelectableText(
              value,
              style: TextStyle(fontSize: 14, height: 1.45, color: cs.onSurface),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildHistoryMetaChip(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  List<MedicalHistoryQuestionAnswer> _extractQuestionAnswers(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map(
          (entry) => MedicalHistoryQuestionAnswer(
            question: entry['question']?.toString().trim() ?? '',
            answer: entry['answer']?.toString().trim() ?? '',
          ),
        )
        .where((entry) => entry.question.isNotEmpty || entry.answer.isNotEmpty)
        .toList(growable: false);
  }

  List<Map<String, String>> _extractImageAttachments(dynamic value) {
    if (value is! List) return const [];

    final attachments = <Map<String, String>>[];

    for (final item in value) {
      if (item is String) {
        final trimmed = item.trim();
        if (trimmed.isEmpty) continue;
        final isLikelyUrl = Uri.tryParse(trimmed)?.hasScheme ?? false;
        attachments.add({
          'title': trimmed,
          'subtitle': context.tr('Uploaded image'),
          if (isLikelyUrl) 'preview': trimmed,
        });
        continue;
      }

      if (item is Map) {
        final originalName = item['originalName']?.toString().trim() ?? '';
        final filename = item['filename']?.toString().trim() ?? '';
        final url = item['url']?.toString().trim() ?? '';
        final imageUrl = item['imageUrl']?.toString().trim() ?? '';
        final downloadUrl = item['downloadUrl']?.toString().trim() ?? '';
        final path = item['path']?.toString().trim() ?? '';
        final filePath = item['filePath']?.toString().trim() ?? '';
        final localPath = item['localPath']?.toString().trim() ?? '';
        final uploadedAt = item['uploadedAt']?.toString().trim() ?? '';
        final size = item['size']?.toString().trim() ?? '';
        final preview = [
          url,
          imageUrl,
          downloadUrl,
          path,
          filePath,
          localPath,
          filename,
        ].firstWhere((entry) => entry.isNotEmpty, orElse: () => '');

        final details = <String>[
          if (filename.isNotEmpty) '${context.tr("File")}: $filename',
          if (size.isNotEmpty)
            '${context.tr("Size")}: $size ${context.tr("bytes")}',
          if (uploadedAt.isNotEmpty) '${context.tr("Uploaded")}: $uploadedAt',
          if (url.isNotEmpty) '${context.tr("URL")}: $url',
        ];

        attachments.add({
          'title': originalName.isNotEmpty ? originalName : filename,
          'subtitle': details.join('\n'),
          if (preview.isNotEmpty) 'preview': preview,
        });
      }
    }

    return attachments;
  }

  Widget _buildQuestionAnswerCard(
    BuildContext context, {
    required String question,
    required String answer,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr("Question"),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            question.isEmpty ? '-' : question,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr("Answer"),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            answer.isEmpty ? '-' : answer,
            style: TextStyle(fontSize: 14, height: 1.45, color: cs.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildImageAttachmentCard(
    BuildContext context,
    Map<String, String> image,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.image_outlined, color: cs.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  (image['title'] ?? '').isEmpty ? '-' : image['title']!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                if ((image['subtitle'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SelectableText(
                    image['subtitle']!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditPatientDialog(BuildContext context, Patient patient) {
    showDialog(
      context: context,
      builder: (_) => EditPatientDialog(
        patient: patient,
        onPatientUpdated: _loadPatients,
      ),
    );
  }
}

class _ProgressiveNetworkImage extends StatefulWidget {
  const _ProgressiveNetworkImage({
    required this.urls,
    this.headers,
    this.fit = BoxFit.cover,
    required this.fallback,
  });

  final List<String> urls;
  final Map<String, String>? headers;
  final BoxFit fit;
  final Widget fallback;

  @override
  State<_ProgressiveNetworkImage> createState() =>
      _ProgressiveNetworkImageState();
}

class _ProgressiveNetworkImageState extends State<_ProgressiveNetworkImage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.urls.length) return widget.fallback;

    return Image.network(
      widget.urls[_index],
      headers: widget.headers,
      fit: widget.fit,
      errorBuilder: (_, __, ___) {
        if (_index < widget.urls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _index += 1);
          });
          return const SizedBox.expand();
        }
        return widget.fallback;
      },
    );
  }
}
