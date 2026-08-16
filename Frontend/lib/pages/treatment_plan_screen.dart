// ignore_for_file: deprecated_member_use

import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:curevoo_doctor/models/patient.dart';
import 'package:curevoo_doctor/providers/patients_cubit.dart';
import 'package:curevoo_doctor/providers/treatment_plan_cubit.dart';
import 'package:curevoo_doctor/repos/treatment_plan_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TreatmentPlanScreen extends StatefulWidget {
  const TreatmentPlanScreen({super.key});

  @override
  State<TreatmentPlanScreen> createState() => _TreatmentPlanScreenState();
}

class _TreatmentPlanScreenState extends State<TreatmentPlanScreen> {
  final TextEditingController _patientSearchController =
      TextEditingController();
  final TextEditingController additionalMedicinesController =
      TextEditingController();
  final TextEditingController customTreatmentTypeController =
      TextEditingController();

  String? selectedPatientId;
  String? selectedLungCancerType;
  String? selectedTreatmentType;
  String? selectedReviewPeriod;
  DateTime? nextReviewDate;
  bool _isLoadingPatients = true;
  String? _patientsLoadError;

  List<PatientSummary> patients = [];

  final List<String> lungCancerTypeKeys = const [
    'Non-small cell lung cancer (NSCLC)',
    'Small cell lung cancer (SCLC)',
    'Lung carcinoid tumor',
    'Mesothelioma',
  ];

  final List<String> treatmentTypeKeys = const [
    'Chemotherapy',
    'Hormonal',
    'Other',
  ];

  final List<String> reviewPeriodKeys = const [
    'Weekly',
    'Every 2 weeks',
    'Monthly',
    'Every 3 months',
  ];

  final List<String> commonMedicines = const [
    'Cisplatin',
    'Carboplatin',
    'Paclitaxel',
    'Docetaxel',
    'Etoposide',
    'Pembrolizumab',
  ];

  final Set<String> selectedCommonMedicines = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPatients();
    });
  }

  @override
  void dispose() {
    _patientSearchController.dispose();
    additionalMedicinesController.dispose();
    customTreatmentTypeController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    if (!mounted) return;

    setState(() {
      _isLoadingPatients = true;
      _patientsLoadError = null;
    });

    final patientsCubit = context.read<PatientsCubit>();
    final fetchedPatients = await patientsCubit.fetchPatients();
    if (!mounted) return;

    setState(() {
      patients = fetchedPatients;
      _isLoadingPatients = false;
      _patientsLoadError = patientsCubit.state.errorMessage;
    });
  }

  PatientSummary? get selectedPatient {
    if (selectedPatientId == null) return null;
    for (final patient in patients) {
      if (patient.id == selectedPatientId) return patient;
    }
    return null;
  }

  Future<void> _pickReviewDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: nextReviewDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() {
        nextReviewDate = picked;
      });
    }
  }

  Future<void> _saveTreatmentPlan() async {
    if (selectedPatientId == null ||
        selectedLungCancerType == null ||
        selectedTreatmentType == null ||
        selectedReviewPeriod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Please complete all required fields.')),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final patient = selectedPatient;
    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Please select a patient')),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final isOtherTreatmentType = selectedTreatmentType == 'Other';
    final customTreatmentType = customTreatmentTypeController.text.trim();
    if (isOtherTreatmentType && customTreatmentType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Please enter a custom treatment type for Other.'),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final effectiveTreatmentType = isOtherTreatmentType
        ? customTreatmentType
        : selectedTreatmentType!;

    final treatmentPlanCubit = context.read<TreatmentPlanCubit>();
    final success = await treatmentPlanCubit.createTreatmentPlan(
      request: CreateTreatmentPlanRequest(
        patientId: patient.id,
        lungCancerType: selectedLungCancerType!,
        treatmentType: effectiveTreatmentType,
        commonMedicines: selectedCommonMedicines.toList(growable: false),
        additionalMedicines: additionalMedicinesController.text.trim(),
        reviewPeriod: selectedReviewPeriod!,
        nextReviewDate: nextReviewDate,
      ),
    );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            treatmentPlanCubit.state.errorMessage ??
                'Failed to create treatment plan.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      selectedLungCancerType = null;
      selectedTreatmentType = null;
      selectedReviewPeriod = null;
      nextReviewDate = null;
      selectedCommonMedicines.clear();
      additionalMedicinesController.clear();
      customTreatmentTypeController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('Treatment plan saved successfully.')),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  _buildCard(
                    title: context.tr('Patient Selection'),
                    icon: Icons.person_search,
                    child: _buildPatientSelection(cs),
                  ),
                  const SizedBox(height: 24),
                  _buildCard(
                    title: context.tr('Treatment Details'),
                    icon: Icons.medication_liquid,
                    child: _buildTreatmentDetails(cs),
                  ),
                  const SizedBox(height: 24),
                  _buildSavePanel(cs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary,
            // cs.secondary.withOpacity(0.86),
            cs.primary.withOpacity(0.70),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(
            theme.brightness == Brightness.dark ? 0.08 : 0.24,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Icon(
              Icons.assignment_turned_in,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Treatment Plan'),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    'Choose a patient and configure the lung cancer treatment plan.',
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.22 : 0.06,
            ),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainer.withValues(alpha: 0.58),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: cs.primary, size: 21),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildPatientSelection(ColorScheme cs) {
    if (_isLoadingPatients) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 34),
        decoration: BoxDecoration(
          color: cs.surfaceContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_patientsLoadError != null && patients.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: cs.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _patientsLoadError!,
                style: TextStyle(color: cs.error),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _loadPatients,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.tr('Retry')),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final dropdownWidth = constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Patient *'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: dropdownWidth,
              child: DropdownMenu<String>(
                controller: _patientSearchController,
                width: dropdownWidth,
                enableFilter: true,
                enableSearch: true,
                requestFocusOnTap: true,
                initialSelection: selectedPatientId,
                hintText: context.tr('Search patients'),
                leadingIcon: const Icon(Icons.search),
                menuHeight: 280,
                menuStyle: MenuStyle(
                  fixedSize: WidgetStatePropertyAll(
                    Size(dropdownWidth, 280),
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: cs.surfaceContainer.withValues(alpha: 0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: cs.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: cs.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: cs.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                filterCallback: (entries, filter) {
                  final query = filter.trim().toLowerCase();
                  if (query.isEmpty) return entries;

                  return entries.where((entry) {
                    final patient = patients.cast<PatientSummary?>().firstWhere(
                      (item) => item?.id == entry.value,
                      orElse: () => null,
                    );
                    if (patient == null) return false;

                    return patient.fullName.toLowerCase().contains(query) ||
                        patient.phone.toLowerCase().contains(query) ||
                        patient.age.toString().contains(query) ||
                        patient.sex.toLowerCase().contains(query);
                  }).toList();
                },
                dropdownMenuEntries: patients
                    .map(
                      (patient) => DropdownMenuEntry<String>(
                        value: patient.id,
                        label: patient.fullName,
                        labelWidget: Text(
                          '${patient.fullName} - ${patient.phone}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onSelected: (value) {
                  setState(() {
                    selectedPatientId = value;
                  });
                },
              ),
            ),
            if (selectedPatient != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.person, color: cs.onPrimary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${selectedPatient!.fullName}, ${selectedPatient!.age} ${context.tr('years old')}, ${context.tr('Phone')}: ${selectedPatient!.phone}',
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTreatmentDetails(ColorScheme cs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 780;
        final fieldGap = twoColumns ? 16.0 : 0.0;

        final lungCancerField = _buildDropdown(
          label: context.tr('Lung Cancer Type *'),
          value: selectedLungCancerType,
          hint: context.tr('Select lung cancer type'),
          items: lungCancerTypeKeys,
          itemLabelBuilder: (value) => context.tr(value),
          onChanged: (value) {
            setState(() {
              selectedLungCancerType = value;
            });
          },
        );

        final treatmentTypeField = _buildDropdown(
          label: context.tr('Treatment Type *'),
          value: selectedTreatmentType,
          hint: context.tr('Select treatment type'),
          items: treatmentTypeKeys,
          itemLabelBuilder: (value) => context.tr(value),
          onChanged: (value) {
            setState(() {
              selectedTreatmentType = value;
              if (value != 'Other') {
                customTreatmentTypeController.clear();
              }
            });
          },
        );

        final customTreatmentTypeField = _buildTextArea(
          controller: customTreatmentTypeController,
          label: context.tr('Custom Treatment Type *'),
          hint: context.tr('Enter treatment type'),
          maxLines: 2,
        );

        final reviewPeriodField = _buildDropdown(
          label: context.tr('Review Time Period *'),
          value: selectedReviewPeriod,
          hint: context.tr('Select review period'),
          items: reviewPeriodKeys,
          itemLabelBuilder: (value) => context.tr(value),
          onChanged: (value) {
            setState(() {
              selectedReviewPeriod = value;
            });
          },
        );

        final dateField = _buildDateField(cs);

        return Column(
          children: [
            if (twoColumns)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: lungCancerField),
                  SizedBox(width: fieldGap),
                  Expanded(child: treatmentTypeField),
                ],
              )
            else ...[
              lungCancerField,
              const SizedBox(height: 16),
              treatmentTypeField,
            ],
            if (selectedTreatmentType == 'Other') ...[
              const SizedBox(height: 18),
              customTreatmentTypeField,
            ],
            const SizedBox(height: 18),
            _buildCommonMedicines(cs),
            const SizedBox(height: 18),
            _buildTextArea(
              controller: additionalMedicinesController,
              label: context.tr('Additional Medicines'),
              hint: context.tr(
                'Write additional medicines and dosage notes...',
              ),
            ),
            const SizedBox(height: 18),
            if (twoColumns)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: reviewPeriodField),
                  SizedBox(width: fieldGap),
                  Expanded(child: dateField),
                ],
              )
            else ...[
              reviewPeriodField,
              const SizedBox(height: 16),
              dateField,
            ],
          ],
        );
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required String hint,
    required List<String> items,
    required String Function(String) itemLabelBuilder,
    required ValueChanged<String?> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;

    final bool hasValue = value != null && items.contains(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainer.withValues(alpha: 0.45),
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButtonFormField<String>(
            value: hasValue ? value : null,
            hint: Text(hint),
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: cs.primary),
            borderRadius: BorderRadius.circular(16),
            dropdownColor: cs.surface,
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      itemLabelBuilder(item),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              filled: false,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              hintStyle: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommonMedicines(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Common Medicines'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: commonMedicines.map((medicine) {
            final isSelected = selectedCommonMedicines.contains(medicine);
            return FilterChip(
              selected: isSelected,
              label: Text(medicine),
              avatar: isSelected
                  ? Icon(Icons.check, color: cs.onPrimaryContainer, size: 16)
                  : null,
              showCheckmark: false,
              selectedColor: cs.primaryContainer,
              backgroundColor: cs.surfaceContainer.withValues(alpha: 0.72),
              side: BorderSide(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.45)
                    : cs.outlineVariant,
              ),
              labelStyle: TextStyle(
                color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selectedCommonMedicines.add(medicine);
                  } else {
                    selectedCommonMedicines.remove(medicine);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTextArea({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 4,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: cs.surfaceContainer.withValues(alpha: 0.45),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(ColorScheme cs) {
    final dateLabel = nextReviewDate == null
        ? context.tr('Pick next review date')
        : '${nextReviewDate!.year}-${nextReviewDate!.month.toString().padLeft(2, '0')}-${nextReviewDate!.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Next Review Date'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickReviewDate,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: cs.surfaceContainer.withValues(alpha: 0.45),
              border: Border.all(color: cs.outline),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: cs.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dateLabel,
                    style: TextStyle(
                      color: nextReviewDate == null
                          ? cs.onSurfaceVariant
                          : cs.onSurface,
                      fontWeight: nextReviewDate == null
                          ? FontWeight.w500
                          : FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavePanel(ColorScheme cs) {
    return BlocBuilder<TreatmentPlanCubit, TreatmentPlanState>(
      builder: (context, state) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.verified_outlined, color: cs.secondary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  context.tr('Save Treatment Plan'),
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 220),
                child: ElevatedButton.icon(
                  onPressed: state.isSubmitting
                      ? null
                      : () {
                          _saveTreatmentPlan();
                        },
                  icon: state.isSubmitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    state.isSubmitting
                        ? context.tr('Saving...')
                        : context.tr('Save Treatment Plan'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
