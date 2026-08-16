// ignore_for_file: deprecated_member_use

import 'package:curevoo_doctor/models/patient.dart';
import 'package:curevoo_doctor/providers/medical_history_cubit.dart';
import 'package:curevoo_doctor/providers/patients_cubit.dart';
import 'package:curevoo_doctor/providers/treatment_resistance_cubit.dart';
import 'package:curevoo_doctor/repos/medical_history_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TreatmentResistancePage extends StatefulWidget {
  const TreatmentResistancePage({super.key});

  @override
  State<TreatmentResistancePage> createState() =>
      _TreatmentResistancePageState();
}

class _TreatmentResistancePageState extends State<TreatmentResistancePage> {
  final TextEditingController _searchController = TextEditingController();

  List<PatientSummary> _patients = const [];
  final Map<String, PatientHistoryRecord?> _historyByPatientId = {};
  final Map<String, String> _reviewFields = {};
  final List<_PredictionRun> _predictionHistory = [];

  bool _isLoadingPatients = true;
  bool _isLoadingHistory = false;
  String? _loadError;
  PatientSummary? _selectedPatient;
  _PredictionRun? _latestResult;

  static const _clinicalFields = [
    _FieldSpec('age', 'Age'),
    _FieldSpec('sex', 'Sex'),
    _FieldSpec('institution', 'Institution / care center'),
    _FieldSpec('histology', 'NSCLC histology'),
    _FieldSpec('stageAtDiagnosis', 'Stage at diagnosis'),
    _FieldSpec('smokingStatus', 'Smoking status'),
  ];

  static const _treatmentFields = [
    _FieldSpec('selectedRegimen', 'Selected EGFR-targeted regimen'),
    _FieldSpec('regimenNumber', 'Regimen number'),
    _FieldSpec('priorSystemicTherapyCount', 'Prior systemic therapy count'),
    _FieldSpec('priorEgfrExposure', 'Prior EGFR-targeted exposure'),
  ];

  static const _sequencingFields = [
    _FieldSpec('sequencingBeforeTreatment', 'Sequencing before treatment'),
    _FieldSpec('sequencingCloseToStart', 'Sequencing close to regimen start'),
    _FieldSpec('largeSequencingGap', 'Large sequencing gap'),
  ];

  static const _genomicMarkers = [
    _MarkerSpec('egfrAlterationPresent', 'EGFR alteration present'),
    _MarkerSpec('egfrExon19Deletion', 'EGFR exon 19 deletion'),
    _MarkerSpec('egfrL858R', 'EGFR L858R'),
    _MarkerSpec('egfrT790M', 'EGFR T790M'),
    _MarkerSpec('kras', 'KRAS'),
    _MarkerSpec('braf', 'BRAF'),
    _MarkerSpec('met', 'MET'),
    _MarkerSpec('erbb2', 'ERBB2'),
    _MarkerSpec('pik3ca', 'PIK3CA'),
    _MarkerSpec('tp53', 'TP53'),
    _MarkerSpec('rb1', 'RB1'),
    _MarkerSpec('stk11', 'STK11'),
    _MarkerSpec('keap1', 'KEAP1'),
    _MarkerSpec('pten', 'PTEN'),
    _MarkerSpec('cdkn2a', 'CDKN2A'),
  ];

  static const Set<String> _mandatoryFieldKeys = {
    'age',
    'sex',
    'stageAtDiagnosis',
    'histology',
    'smokingStatus',
    'selectedRegimen',
    'egfrAlterationPresent',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPatients());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    if (!mounted) return;

    setState(() {
      _isLoadingPatients = true;
      _loadError = null;
    });

    final patientsCubit = context.read<PatientsCubit>();
    final patients = await patientsCubit.fetchPatients();
    if (!mounted) return;

    setState(() {
      _patients = patients;
      _isLoadingPatients = false;
      _loadError = patientsCubit.state.errorMessage;
    });
  }

  Future<void> _selectPatient(PatientSummary patient) async {
    final cached = _historyByPatientId[patient.id];

    setState(() {
      _selectedPatient = patient;
      _isLoadingHistory = cached == null;
      _latestResult = null;
      _seedReviewFields(patient, cached?.rawData);
      _loadError = null;
    });
    context.read<TreatmentResistanceCubit>().clearResult();

    if (cached != null) return;

    try {
      final record = await context
          .read<MedicalHistoryCubit>()
          .fetchLatestHistoryRecord(patientId: patient.id);
      if (!mounted) return;
      setState(() {
        _historyByPatientId[patient.id] = record;
        _seedReviewFields(patient, record.rawData);
        _isLoadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _runPrediction() async {
    final patient = _selectedPatient;
    final cubit = context.read<TreatmentResistanceCubit>();
    if (patient == null || cubit.state.isRunningPrediction) return;

    final missingMandatoryFields = _missingMandatoryFieldLabels();
    if (missingMandatoryFields.isNotEmpty) {
      cubit.setValidationError(
        'Mandatory fields are required before running prediction: '
        '${missingMandatoryFields.join(', ')}.',
      );
      return;
    }

    final regimenCategory = _nullableText(_reviewFields['selectedRegimen']);
    if (regimenCategory == null ||
        !regimenCategory.toLowerCase().contains('egfr')) {
      cubit.setValidationError(
        'Selected EGFR-targeted regimen must include "EGFR" (for example: EGFR TKI).',
      );
      return;
    }

    final response = await cubit.predictNsclc(
      body: _predictionRequestBody(patient),
    );
    if (!mounted || response == null) return;

    final run = _PredictionRun.fromResponse(
      response,
      patient: patient,
      fallbackMissingFields: _missingFields(),
    );
    setState(() {
      _predictionHistory.insert(0, run);
      _latestResult = run;
    });
  }

  Map<String, dynamic> _predictionRequestBody(PatientSummary patient) {
    final indexRegimenNumber =
        int.tryParse((_reviewFields['regimenNumber'] ?? '').trim());
    final priorSystemicTherapyCount = int.tryParse(
      (_reviewFields['priorSystemicTherapyCount'] ?? '').trim(),
    );
    final bypassPathwayBurden = _countPositive([
      'met',
      'erbb2',
      'pik3ca',
      'braf',
      'kras',
    ]);
    final coMutationCount = _countPositive([
      'tp53',
      'rb1',
      'stk11',
      'keap1',
      'met',
      'erbb2',
      'pik3ca',
      'pten',
      'cdkn2a',
      'braf',
      'kras',
    ]);
    final tumorSuppressorLossCount = _countPositive([
      'tp53',
      'rb1',
      'stk11',
      'keap1',
      'pten',
      'cdkn2a',
    ]);

    return {
      'patientId': patient.id,
      'includeLlmExplanation': false,
      'overrides': {
        'age_feature': int.tryParse(_reviewFields['age'] ?? '') ?? patient.age,
        'sex': _nullableText(_reviewFields['sex']) ?? patient.sex,
        'smoking_status_group': _nullableText(_reviewFields['smokingStatus']),
        'histology_group': _nullableText(_reviewFields['histology']),
        'stage_dx': _nullableText(_reviewFields['stageAtDiagnosis']),
        'advanced_stage_flag': _advancedStageFlag(_reviewFields['stageAtDiagnosis']),
        'institution': _nullableText(_reviewFields['institution']),
        'index_regimen_number': indexRegimenNumber,
        'n_regimens_pt': indexRegimenNumber,
        'later_line_flag': indexRegimenNumber == null
            ? null
            : (indexRegimenNumber > 1 ? 1 : 0),
        'regimen_category': _nullableText(_reviewFields['selectedRegimen']),
        'regimen_has_osimertinib': _containsOsimertinib(
          _reviewFields['selectedRegimen'],
        ),
        'prior_therapy_class_summary': _nullableText(
          _reviewFields['selectedRegimen'],
        ),
        'prior_egfr_targeted_exposure': _flagFromReview('priorEgfrExposure'),
        'prior_systemic_therapy_count':
            priorSystemicTherapyCount ??
            (indexRegimenNumber == null
                ? null
                : (indexRegimenNumber > 1 ? indexRegimenNumber - 1 : 0)),
        'sequencing_before_regimen_flag': _flagFromReview(
          'sequencingBeforeTreatment',
        ),
        'sequencing_close_to_regimen_start_flag': _flagFromReview(
          'sequencingCloseToStart',
        ),
        'large_sequencing_gap_flag': _flagFromReview('largeSequencingGap'),
        'n_imaging_reports_pt': 1,
        'n_md_notes_pt': 1,
        'EGFR': _flagFromReview('egfrAlterationPresent'),
        'EGFR_exon19del_flag': _flagFromReview('egfrExon19Deletion'),
        'EGFR_L858R_flag': _flagFromReview('egfrL858R'),
        'EGFR_T790M_flag': _flagFromReview('egfrT790M'),
        'EGFR_subtype_group': _egfrSubtypeGroup(),
        'TP53': _flagFromReview('tp53'),
        'RB1': _flagFromReview('rb1'),
        'STK11': _flagFromReview('stk11'),
        'KEAP1': _flagFromReview('keap1'),
        'MET': _flagFromReview('met'),
        'ERBB2': _flagFromReview('erbb2'),
        'PIK3CA': _flagFromReview('pik3ca'),
        'PTEN': _flagFromReview('pten'),
        'CDKN2A': _flagFromReview('cdkn2a'),
        'BRAF': _flagFromReview('braf'),
        'KRAS': _flagFromReview('kras'),
        'TP53_RB1_double_hit_flag': _allPositive(['tp53', 'rb1']) ? 1 : 0,
        'STK11_KEAP1_double_hit_flag': _allPositive(['stk11', 'keap1']) ? 1 : 0,
        'bypass_pathway_burden': bypassPathwayBurden,
        'bypass_pathway_flag': bypassPathwayBurden >= 1 ? 1 : 0,
        'cell_cycle_flag':
            (_isPositive('rb1') || _isPositive('cdkn2a')) ? 1 : 0,
        'co_mutation_count': coMutationCount,
        'tumor_suppressor_loss_count': tumorSuppressorLossCount,
      }..removeWhere((key, value) => value == null),
    };
  }

  int? _flagFromReview(String key) {
    final value = (_reviewFields[key] ?? '').trim().toLowerCase();
    if (value.isEmpty || value == 'unknown') return null;
    if (value == 'positive' ||
        value == 'present' ||
        value == 'true' ||
        value == 'yes' ||
        value == '1' ||
        value == 'detected') {
      return 1;
    }
    if (value == 'negative' ||
        value == 'absent' ||
        value == 'false' ||
        value == 'no' ||
        value == '0' ||
        value == 'not detected') {
      return 0;
    }
    final parsed = int.tryParse(value);
    return parsed == null ? null : (parsed > 0 ? 1 : 0);
  }

  bool _isPositive(String key) => _flagFromReview(key) == 1;

  bool _allPositive(List<String> keys) => keys.every(_isPositive);

  int _countPositive(List<String> keys) =>
      keys.where((key) => _isPositive(key)).length;

  int _containsOsimertinib(String? regimen) {
    final text = (regimen ?? '').toLowerCase();
    return text.contains('osimertinib') ? 1 : 0;
  }

  String? _egfrSubtypeGroup() {
    if (_isPositive('egfrT790M')) return 'T790M';
    if (_isPositive('egfrL858R')) return 'L858R';
    if (_isPositive('egfrExon19Deletion')) return 'Exon19del';
    return null;
  }

  int? _advancedStageFlag(String? stageText) {
    final stage = stageText?.trim().toLowerCase();
    if (stage == null || stage.isEmpty) return null;
    if (stage.contains('iv') ||
        stage.contains('4') ||
        stage.contains('metast')) {
      return 1;
    }
    return 0;
  }

  void _seedReviewFields(
    PatientSummary patient,
    Map<String, dynamic>? rawData,
  ) {
    _reviewFields
      ..clear()
      ..addAll({
        'age': patient.age.toString(),
        'sex': patient.sex,
        'institution': _readValue(rawData, const [
          'institution',
          'careCenter',
          'hospital',
          'clinic',
        ]),
        'histology': _readValue(rawData, const [
          'histology',
          'nsclcHistology',
          'subtype',
          'cancerSubtype',
        ]),
        'stageAtDiagnosis': _readValue(rawData, const [
          'stageAtDiagnosis',
          'stage',
          'metastaticStatus',
        ]),
        'smokingStatus': _readValue(rawData, const ['smokingStatus', 'smoker']),
        'selectedRegimen': _readValue(rawData, const [
          'selectedRegimen',
          'currentTreatment',
          'latestTreatment',
          'previousTreatmentHistory',
        ]),
        'regimenNumber': _readValue(rawData, const [
          'regimenNumber',
          'lineOfTherapy',
          'treatmentLine',
        ]),
        'priorSystemicTherapyCount': _readValue(rawData, const [
          'priorSystemicTherapyCount',
          'priorTherapyCount',
        ]),
        'priorEgfrExposure': _readValue(rawData, const [
          'priorEgfrExposure',
          'priorEGFRTargetedExposure',
        ]),
        'sequencingBeforeTreatment': _readValue(rawData, const [
          'sequencingBeforeTreatment',
        ]),
        'sequencingCloseToStart': _readValue(rawData, const [
          'sequencingCloseToRegimenStart',
          'sequencingCloseToStart',
        ]),
        'largeSequencingGap': _readValue(rawData, const ['largeSequencingGap']),
      });

    final markerText = _readValue(rawData, const [
      'genomicMarkers',
      'mutations',
      'molecularMarkers',
    ]).toLowerCase();
    for (final marker in _genomicMarkers) {
      _reviewFields[marker.key] = _markerState(rawData, marker, markerText);
    }
  }

  List<String> _missingFields() {
    final labels = <String, String>{
      'histology': 'NSCLC histology',
      'stageAtDiagnosis': 'Stage at diagnosis',
      'smokingStatus': 'Smoking status',
      'selectedRegimen': 'Selected EGFR-targeted regimen',
      'regimenNumber': 'Regimen number',
      'priorSystemicTherapyCount': 'Prior systemic therapy count',
      'priorEgfrExposure': 'Prior EGFR-targeted exposure',
      'sequencingBeforeTreatment': 'Sequencing before treatment',
      'sequencingCloseToStart': 'Sequencing close to regimen start',
      'largeSequencingGap': 'Large sequencing gap',
      for (final marker in _genomicMarkers) marker.key: marker.label,
    };

    return labels.entries
        .where(
          (entry) =>
              (_reviewFields[entry.key] ?? '').trim().isEmpty ||
              (_reviewFields[entry.key] ?? '').trim().toLowerCase() ==
                  'unknown',
        )
        .map((entry) => entry.value)
        .toList(growable: false);
  }

  List<String> _missingMandatoryFieldLabels() {
    final labels = <String>[];
    for (final key in _mandatoryFieldKeys) {
      final value = (_reviewFields[key] ?? '').trim().toLowerCase();
      if (value.isEmpty || value == 'unknown') {
        labels.add(_fieldLabelByKey(key));
      }
    }
    return labels;
  }

  String _fieldLabelByKey(String key) {
    const labels = <String, String>{
      'age': 'Age',
      'sex': 'Sex',
      'stageAtDiagnosis': 'Stage at diagnosis',
      'histology': 'NSCLC histology',
      'smokingStatus': 'Smoking status',
      'selectedRegimen': 'Selected EGFR-targeted regimen',
      'egfrAlterationPresent': 'EGFR alteration present',
    };
    return labels[key] ?? key;
  }

  bool _isMandatoryField(String key) {
    return _mandatoryFieldKeys.contains(key);
  }

  List<PatientSummary> get _filteredPatients {
    return _patients;
  }

  List<_PredictionRun> get _recentPredictionHistory =>
      _predictionHistory.sortedByDateDesc();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildOnePageFlow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lung NSCLC AI',
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Predict EGFR treatment-context risk signals for NSCLC patients.',
            style: TextStyle(
              color: cs.onPrimary.withOpacity(0.86),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnePageFlow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoPanel(
          title: 'EGFR treatment-context risk signal',
          subtitle:
              'This result supports clinical review and is not a standalone treatment decision.',
          child: const SizedBox.shrink(),
        ),
        const SizedBox(height: 20),
        _buildPatientSelection(),
        if (_selectedPatient != null) ...[
          const SizedBox(height: 20),
          _buildInputReview(),
          const SizedBox(height: 20),
          _buildConfirmation(),
        ],
        if (_latestResult != null) ...[
          const SizedBox(height: 20),
          _buildResult(),
        ],
        const SizedBox(height: 20),
        _buildHistory(),
      ],
    );
  }

  Widget _buildPatientSelection() {
    final cs = Theme.of(context).colorScheme;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person_search, color: cs.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient Selection',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search patients, filtered to lung NSCLC.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadPatients,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSelectPatientDropdown(cs),
        ],
      ),
    );
  }

  Widget _buildSelectPatientDropdown(ColorScheme cs) {
    if (_isLoadingPatients) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 34),
        decoration: BoxDecoration(
          color: cs.surfaceContainer.withOpacity(0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null && _filteredPatients.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.errorContainer.withOpacity(0.24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.error.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: cs.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_loadError!, style: TextStyle(color: cs.error)),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _loadPatients,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredPatients.isEmpty) {
      return _emptyState(
        'No patients found',
        'No patients are available right now.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final dropdownWidth = constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient *',
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
                controller: _searchController,
                width: dropdownWidth,
                enableFilter: true,
                enableSearch: true,
                requestFocusOnTap: true,
                initialSelection: _selectedPatient?.id,
                hintText: 'Search NSCLC patients',
                leadingIcon: const Icon(Icons.search),
                menuHeight: 280,
                menuStyle: MenuStyle(
                  fixedSize: WidgetStatePropertyAll(Size(dropdownWidth, 280)),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: cs.surfaceContainer.withOpacity(0.6),
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
                    final patient = _filteredPatients
                        .cast<PatientSummary?>()
                        .firstWhere(
                          (item) => item?.id == entry.value,
                          orElse: () => null,
                        );
                    if (patient == null) return false;
                    final rawData = _historyByPatientId[patient.id]?.rawData;
                    final haystack = [
                      patient.fullName,
                      patient.phone,
                      patient.age.toString(),
                      patient.sex,
                      _readValue(rawData, const ['stage', 'stageAtDiagnosis']),
                      _readValue(rawData, const [
                        'egfrStatus',
                        'EGFR',
                        'genomicMarkers',
                      ]),
                      _readValue(rawData, const [
                        'selectedRegimen',
                        'currentTreatment',
                        'latestTreatment',
                      ]),
                    ].join(' ').toLowerCase();
                    return haystack.contains(query);
                  }).toList();
                },
                dropdownMenuEntries: _filteredPatients
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
                    .toList(growable: false),
                onSelected: (value) {
                  if (value == null) return;
                  final patient = _filteredPatients
                      .cast<PatientSummary?>()
                      .firstWhere(
                        (item) => item?.id == value,
                        orElse: () => null,
                      );
                  if (patient == null) return;
                  _selectPatient(patient);
                },
              ),
            ),
            if (_loadError != null) ...[
              const SizedBox(height: 12),
              _errorBanner(_loadError!),
            ],
            if (_selectedPatient != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.34),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.primary.withOpacity(0.25)),
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
                        '${_selectedPatient!.fullName}, ${_selectedPatient!.age} years old, Phone: ${_selectedPatient!.phone}',
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
  Widget _buildInputReview() {
    final patient = _selectedPatient;
    if (patient == null) return _emptyState('No patient selected', '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _contextStrip(patient),
        const SizedBox(height: 18),
        if (_isLoadingHistory) const LinearProgressIndicator(),
        if (_missingFields().isNotEmpty) ...[
          _warningBanner(
            'Missing fields are highlighted. Unknown fields may affect prediction quality.',
          ),
          const SizedBox(height: 14),
        ],
        _warningBanner(
          'Mandatory fields: Selected EGFR-targeted regimen, EGFR alteration present.',
        ),
        const SizedBox(height: 14),
        _formSection('Patient', _clinicalFields.take(3).toList()),
        _formSection('Cancer', _clinicalFields.skip(3).toList()),
        _formSection('Treatment', _treatmentFields),
        _formSection('Sequencing', _sequencingFields),
        _genomicsSection(),
      ],
    );
  }

  Widget _buildConfirmation() {
    final patient = _selectedPatient;
    if (patient == null) return _emptyState('No patient selected', '');
    final resistanceState = context.watch<TreatmentResistanceCubit>().state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _contextStrip(patient),
        const SizedBox(height: 18),
        _infoPanel(
          title: 'Ready to run NSCLC AI prediction',
          subtitle:
              'Node will call the internal AI service. The frontend will not call FastAPI directly.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Patient', '${patient.fullName} / ${patient.id}'),
              _kv('Cancer type', 'NSCLC'),
              _kv('Treatment context', 'EGFR-targeted'),
              _kv(
                'Outputs',
                'Predicted Early Progression Risk, Predicted Durable Benefit Signal, Resistance-Related Interpretation',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (resistanceState.errorMessage != null)
          _errorBanner(resistanceState.errorMessage!),
        Wrap(
          spacing: 12,
          children: [
            FilledButton(
              onPressed: resistanceState.isRunningPrediction
                  ? null
                  : _runPrediction,
              child: resistanceState.isRunningPrediction
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Run NSCLC AI Prediction'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResult() {
    final result = _latestResult;
    if (result == null) {
      return _emptyState(
        'No result available',
        'Run a prediction to open the result page.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _resultHeader(result),
        const SizedBox(height: 18),
        _summaryCard(result.summaryText),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 760;
            final cards = [
              _riskCard(result.acquiredResistanceRisk, isPrimary: true),
              _riskCard(result.earlyProgressionRisk),
              _riskCard(result.durableBenefit, benefitOriented: true),
            ];
            return narrow
                ? Column(children: cards)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: cards
                        .map((card) => Expanded(child: card))
                        .toList(growable: false),
                  );
          },
        ),
        const SizedBox(height: 18),
        _interpretationCard(result.interpretation),
        const SizedBox(height: 18),
        _missingFieldsCard(result.missingRawFields),
        const SizedBox(height: 18),
        if ((result.aiGeneratedExplanation ?? '').trim().isNotEmpty) ...[
          _infoPanel(
            title: 'AI-generated explanation',
            subtitle: result.aiGeneratedExplanation!,
            child: const SizedBox.shrink(),
          ),
          const SizedBox(height: 18),
        ],
        _modelDetails(result.modelDetails),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: () {},
              child: const Text('Save to Patient Record'),
            ),
            OutlinedButton(
              onPressed: () {},
              child: const Text('View Patient Timeline'),
            ),
            OutlinedButton(
              onPressed: () {
                context.read<TreatmentResistanceCubit>().clearResult();
                setState(() {
                  _latestResult = null;
                });
              },
              child: const Text('Run Again'),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('Back to AI History'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'NSCLC AI history',
          'Prior NSCLC runs only. Other cancer packages are not mixed into this page.',
        ),
        const SizedBox(height: 16),
        if (_recentPredictionHistory.isEmpty)
          _emptyState(
            'No prediction history available',
            'Run an NSCLC prediction first.',
          )
        else
          ..._recentPredictionHistory.map(_historyTile),
      ],
    );
  }

  /*
  Widget _patientDropdownLabel(PatientSummary patient, ColorScheme cs) {
    final rawData = _historyByPatientId[patient.id]?.rawData;
    final lastRun = _latestPatientHistory(patient.id).firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            patient.fullName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 5,
            children: [
              _patientInfoChip(Icons.badge, patient.id, cs),
              _patientInfoChip(Icons.phone, patient.phone, cs),
              _patientInfoChip(Icons.cake, '${patient.age}', cs),
              _patientInfoChip(Icons.biotech, 'NSCLC', cs),
              _patientInfoChip(
                Icons.timeline,
                _readValue(rawData, const ['stageAtDiagnosis', 'stage'])
                    .ifBlank('Stage unknown'),
                cs,
              ),
              _patientInfoChip(
                Icons.science,
                _readValue(rawData, const [
                  'egfrStatus',
                  'EGFR',
                  'genomicMarkers',
                ]).ifBlank('EGFR unknown'),
                cs,
              ),
              _patientInfoChip(
                Icons.history,
                lastRun == null ? 'No prior run' : _formatDateTime(lastRun.createdAt),
                cs,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPatientCard() {
    final cs = Theme.of(context).colorScheme;
    final patient = _selectedPatient!;
    final rawData = _historyByPatientId[patient.id]?.rawData;
    final lastRun = _latestPatientHistory(patient.id).firstOrNull;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withOpacity(0.3),
            cs.primaryContainer.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primaryContainer),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.verified_user, size: 18, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Patient Selected',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
                Icon(Icons.check_circle, size: 20, color: cs.primary),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _selectedInfoChip(
                        icon: Icons.person,
                        label: patient.fullName,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _selectedInfoChip(
                        icon: Icons.phone,
                        label: patient.phone,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _selectedInfoChip(
                        icon: Icons.biotech,
                        label: 'NSCLC',
                        color: cs.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _selectedInfoChip(
                        icon: Icons.science,
                        label: _readValue(rawData, const [
                          'egfrStatus',
                          'EGFR',
                          'genomicMarkers',
                        ]).ifBlank('EGFR unknown'),
                        color: cs.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lastRun == null
                              ? 'Patient information will prefill the NSCLC review step.'
                              : 'Last NSCLC AI run: ${_formatDateTime(lastRun.createdAt)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
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
    );
  }

  Widget _patientInfoChip(IconData icon, String label, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _selectedInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

*/
  Widget _formSection(String title, List<_FieldSpec> fields) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 760 ? 1 : 2;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: fields
                    .map((field) {
                      final width = columns == 1
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 14) / 2;
                      return SizedBox(width: width, child: _reviewField(field));
                    })
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _reviewField(_FieldSpec field) {
    final value = _reviewFields[field.key] ?? '';
    final missing = value.trim().isEmpty;
    final label = _isMandatoryField(field.key)
        ? '${field.label} *'
        : field.label;
    return TextFormField(
      initialValue: value,
      onChanged: (next) => _reviewFields[field.key] = next,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: missing,
        fillColor: missing
            ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.24)
            : null,
      ),
    );
  }

  Widget _genomicsSection() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Genomics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 760 ? 1 : 3;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - (14 * (columns - 1))) / columns;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: _genomicMarkers
                    .map((marker) {
                      return SizedBox(
                        width: width,
                        child: _markerDropdown(marker),
                      );
                    })
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _markerDropdown(_MarkerSpec marker) {
    final value = _reviewFields[marker.key] ?? 'unknown';
    final missing = value == 'unknown' || value.trim().isEmpty;
    final label = _isMandatoryField(marker.key)
        ? '${marker.label} *'
        : marker.label;
    return DropdownButtonFormField<String>(
      value: value.isEmpty ? 'unknown' : value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: missing,
        fillColor: missing
            ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.24)
            : null,
      ),
      items: const [
        DropdownMenuItem(value: 'positive', child: Text('Positive')),
        DropdownMenuItem(value: 'negative', child: Text('Negative')),
        DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
      ],
      onChanged: (next) {
        if (next == null) return;
        setState(() => _reviewFields[marker.key] = next);
      },
    );
  }

  Widget _contextStrip(PatientSummary patient) {
    return _panel(
      child: Wrap(
        spacing: 18,
        runSpacing: 10,
        children: [
          _tileMetric('Patient', '${patient.fullName} / ${patient.id}'),
          _tileMetric('Cancer type', 'NSCLC'),
          _tileMetric('Treatment context', 'EGFR-targeted'),
          _tileMetric('Package slug', 'nsclc'),
        ],
      ),
    );
  }

  Widget _resultHeader(_PredictionRun result) {
    return _panel(
      child: Wrap(
        spacing: 18,
        runSpacing: 10,
        children: [
          _tileMetric(
            'Patient',
            '${result.patientLabel} / ${result.patientId}',
          ),
          _tileMetric('Cancer type', 'NSCLC'),
          _tileMetric('Treatment context', 'EGFR-targeted'),
          _tileMetric('Prediction date', _formatDateTime(result.createdAt)),
          _tileMetric('Prediction version', result.predictionVersion),
        ],
      ),
    );
  }

  Widget _summaryCard(String summary) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        summary,
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _riskCard(
    _RiskOutput risk, {
    bool benefitOriented = false,
    bool isPrimary = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final color = benefitOriented ? Colors.teal : _badgeColor(risk.badge);
    return Padding(
      padding: const EdgeInsets.only(right: 10, bottom: 10),
      child: _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    risk.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _badge(color, risk.badge.toUpperCase()),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _percentage(risk.probability),
              style: TextStyle(
                color: color,
                fontSize: 38,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              risk.subtitle,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
            ),
            if (isPrimary) ...[
              const SizedBox(height: 8),
              Text(
                'Acquired-resistance-like risk, not a confirmed resistance diagnosis.',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (benefitOriented) ...[
              const SizedBox(height: 8),
              Text(
                'Benefit-oriented signal, not a failure-risk score.',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _interpretationCard(_ResistanceInterpretation interpretation) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resistance-Related Interpretation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(interpretation.summary, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: interpretation.tags
                .map((tag) => _badge(Colors.indigo, tag))
                .toList(),
          ),
          const SizedBox(height: 12),
          ...interpretation.signals.map(
            (signal) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _kv(signal.tag, signal.message),
            ),
          ),
        ],
      ),
    );
  }

  Widget _missingFieldsCard(List<String> missingFields) {
    return _infoPanel(
      title: 'Missing or unknown fields',
      subtitle: missingFields.isEmpty
          ? 'No missing fields were reported for this run.'
          : 'Missing fields may affect prediction quality.',
      child: missingFields.isEmpty
          ? const SizedBox.shrink()
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: missingFields
                  .map((field) => _badge(Colors.orange, field))
                  .toList(),
            ),
    );
  }

  Widget _modelDetails(_ModelDetails details) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 18),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      title: const Text(
        'Model details',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      children: [
        _kv('Profile key', details.profileKey),
        _kv('Model name', details.modelName),
        _kv('Feature set', details.featureSet),
        _kv(
          'Selected threshold',
          details.selectedThreshold == null
              ? 'Not returned'
              : details.selectedThreshold!.toStringAsFixed(3),
        ),
        _kv(
          'Mean accuracy',
          details.meanAccuracy == null
              ? 'Not returned'
              : details.meanAccuracy!.toStringAsFixed(2),
        ),
        _kv(
          'Mean ROC AUC',
          details.meanRocAuc == null
              ? 'Not returned'
              : details.meanRocAuc!.toStringAsFixed(2),
        ),
        _kv(
          'Mean Brier',
          details.meanBrier == null
              ? 'Not returned'
              : details.meanBrier!.toStringAsFixed(3),
        ),
        _kv(
          'Train rows',
          details.trainRows == null ? 'Not returned' : '${details.trainRows}',
        ),
        _kv(
          'Positive rows',
          details.positiveRows == null
              ? 'Not returned'
              : '${details.positiveRows}',
        ),
        _kv(
          'Negative rows',
          details.negativeRows == null
              ? 'Not returned'
              : '${details.negativeRows}',
        ),
        _kv('Prediction version', details.version),
      ],
    );
  }

  Widget _historyTile(_PredictionRun run) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _panel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${run.patientLabel} • ${_formatDateTime(run.createdAt)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    run.summaryText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(height: 1.45),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _badge(
                        _badgeColor(run.acquiredResistanceRisk.badge),
                        'Acquired: ${run.acquiredResistanceRisk.badge}',
                      ),
                      _badge(
                        _badgeColor(run.earlyProgressionRisk.badge),
                        'Early: ${run.earlyProgressionRisk.badge}',
                      ),
                      _badge(
                        Colors.teal,
                        'Benefit: ${run.durableBenefit.badge}',
                      ),
                      _badge(Colors.blueGrey, 'Doctor: ${run.doctorName}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            OutlinedButton(
              onPressed: () => setState(() {
                _latestResult = run;
              }),
              child: const Text('Open result'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoPanel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (child is! SizedBox) ...[const SizedBox(height: 16), child],
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _tileMetric(String label, String value) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? 'Unknown' : value,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(child: Text(value.trim().isEmpty ? 'Unknown' : value)),
        ],
      ),
    );
  }

  Widget _badge(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle),
          ],
        ],
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _banner(message, Theme.of(context).colorScheme.errorContainer),
    );
  }

  Widget _warningBanner(String message) {
    return _banner(message, Colors.orange.withOpacity(0.14));
  }

  Widget _banner(String message, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  String _readValue(Map<String, dynamic>? rawData, List<String> keys) {
    if (rawData == null) return '';
    for (final key in keys) {
      final value = rawData[key];
      final text = _stringify(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _markerState(
    Map<String, dynamic>? rawData,
    _MarkerSpec marker,
    String markerText,
  ) {
    final direct = _readValue(rawData, [marker.key, marker.label]);
    final parsed = _parseMarkerState(direct);
    if (parsed != null) return parsed;
    if (markerText.contains(marker.label.toLowerCase()) ||
        markerText.contains(marker.key.toLowerCase())) {
      return 'positive';
    }
    return 'unknown';
  }

  String? _parseMarkerState(String value) {
    switch (value.trim().toLowerCase()) {
      case 'positive':
      case 'present':
      case 'true':
      case 'yes':
      case 'detected':
        return 'positive';
      case 'negative':
      case 'absent':
      case 'false':
      case 'no':
      case 'not detected':
        return 'negative';
      case 'unknown':
      case '':
        return 'unknown';
    }
    return null;
  }

  String _stringify(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      return value.map(_stringify).where((item) => item.isNotEmpty).join(', ');
    }
    if (value is Map) {
      return value.values
          .map(_stringify)
          .where((item) => item.isNotEmpty)
          .join(', ');
    }
    final text = value.toString().trim();
    if (text.toLowerCase() == 'null') return '';
    return text;
  }

  String? _nullableText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Color _badgeColor(String badge) {
    switch (badge.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _percentage(double value) => '${(value * 100).round()}%';

  String _formatDateTime(DateTime value) {
    final date =
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

class _FieldSpec {
  const _FieldSpec(this.key, this.label);

  final String key;
  final String label;
}

class _MarkerSpec {
  const _MarkerSpec(this.key, this.label);

  final String key;
  final String label;
}

class _PredictionRun {
  const _PredictionRun({
    required this.id,
    required this.patientId,
    required this.patientLabel,
    required this.predictionVersion,
    required this.createdAt,
    required this.summaryText,
    required this.acquiredResistanceRisk,
    required this.earlyProgressionRisk,
    required this.durableBenefit,
    required this.interpretation,
    required this.modelDetails,
    required this.missingRawFields,
    required this.doctorName,
    this.aiGeneratedExplanation,
  });

  final String id;
  final String patientId;
  final String patientLabel;
  final String predictionVersion;
  final DateTime createdAt;
  final String summaryText;
  final _RiskOutput acquiredResistanceRisk;
  final _RiskOutput earlyProgressionRisk;
  final _RiskOutput durableBenefit;
  final _ResistanceInterpretation interpretation;
  final _ModelDetails modelDetails;
  final List<String> missingRawFields;
  final String doctorName;
  final String? aiGeneratedExplanation;

  factory _PredictionRun.fromResponse(
    dynamic response, {
    required PatientSummary patient,
    required List<String> fallbackMissingFields,
  }) {
    final root = _toMap(response);
    final data =
        _firstMap(root, const ['data', 'result', 'prediction']) ?? root;
    final early = _buildRiskMap(
      data: data,
      keys: const [
        'earlyProgressionRisk',
        'early_progression_risk',
        'earlyFailureRisk',
        'early_failure_risk',
      ],
    );
    final acquired = _buildRiskMap(
      data: data,
      keys: const [
        'acquiredResistanceRisk',
        'acquired_resistance_risk',
      ],
    );
    final benefit = _buildRiskMap(
      data: data,
      keys: const [
        'durableBenefit',
        'durableBenefitLikelihood',
        'durableBenefitSignal',
        'durable_benefit_signal',
        'durable_benefit_likelihood',
      ],
    );
    final interpretation =
        _firstMap(data, const [
          'resistanceInterpretation',
          'resistanceRelatedInterpretation',
          'resistance_related_interpretation',
          'interpretation',
        ]) ??
        const {};
    final modelFromAcquired = _firstMap(
      acquired,
      const ['modelMetadata', 'model_metadata'],
    );
    final modelFromRoot =
        _firstMap(data, const ['modelDetails', 'model', 'metadata']) ??
        const {};
    final model = {
      ...modelFromRoot,
      ...acquired,
      ...(modelFromAcquired ?? const {}),
    };

    final version =
        _readString(data, const ['predictionVersion', 'version']) ??
        _readString(model, const ['predictionVersion', 'version']) ??
        'Not returned';
    final summaryText =
        _readString(data, const ['summaryText', 'summary_text', 'summary']) ??
        'NSCLC AI prediction completed for EGFR treatment-context review.';
    final acquiredHint = _summaryRiskHint(
      summaryText,
      metricPattern: 'acquired\\s+resistance\\s+risk',
    );
    final earlyHint = _summaryRiskHint(
      summaryText,
      metricPattern: 'early\\s+failure\\s+risk|early\\s+progression\\s+risk',
    );
    final benefitHint = _summaryRiskHint(
      summaryText,
      metricPattern: 'durable\\s+benefit\\s+likelihood|durable\\s+benefit\\s+signal',
    );
    final normalizedAcquired = _mergeRiskMapWithSummaryHint(acquired, acquiredHint);
    final normalizedEarly = _mergeRiskMapWithSummaryHint(early, earlyHint);
    final normalizedBenefit = _mergeRiskMapWithSummaryHint(benefit, benefitHint);

    return _PredictionRun(
      id:
          _readString(data, const ['id', 'runId', '_id']) ??
          'nsclc-${DateTime.now().millisecondsSinceEpoch}',
      patientId: patient.id,
      patientLabel: patient.fullName,
      predictionVersion: version,
      createdAt:
          DateTime.tryParse(
            _readString(
                  data,
                  const ['createdAt', 'created_at', 'predictionDate'],
                ) ??
                '',
          ) ??
          DateTime.now(),
      summaryText: summaryText,
      acquiredResistanceRisk: _RiskOutput.fromMap(
        normalizedAcquired,
        fallbackTitle: 'Predicted Acquired Resistance Risk',
      ),
      earlyProgressionRisk: _RiskOutput.fromMap(
        normalizedEarly,
        fallbackTitle: 'Predicted Early Progression Risk',
      ),
      durableBenefit: _RiskOutput.fromMap(
        normalizedBenefit,
        fallbackTitle: 'Predicted Durable Benefit Signal',
      ),
      interpretation: _ResistanceInterpretation.fromMap(interpretation),
      modelDetails: _ModelDetails.fromMap(model, fallbackVersion: version),
      missingRawFields: _collectMissingFields(data, acquired, fallbackMissingFields),
      doctorName:
          _readString(data, const ['doctorName', 'doctor']) ?? 'Current doctor',
      aiGeneratedExplanation: _readString(data, const [
        'aiGeneratedExplanation',
        'ai_generated_explanation',
        'llmExplanation',
        'llm_explanation',
        'explanation',
      ]),
    );
  }
}

Map<String, dynamic> _buildRiskMap({
  required Map<String, dynamic> data,
  required List<String> keys,
}) {
  final mapValue = _firstMap(data, keys);
  if (mapValue != null) return mapValue;

  for (final key in keys) {
    if (!data.containsKey(key)) continue;
    final raw = data[key];
    if (raw is num) return {'probability': raw.toDouble()};
    if (raw is String) {
      final parsed = double.tryParse(raw.trim());
      if (parsed != null) return {'probability': parsed};
    }
  }

  return const {};
}

Map<String, dynamic> _mergeRiskMapWithSummaryHint(
  Map<String, dynamic> riskMap,
  _SummaryRiskHint? hint,
) {
  if (hint == null) return riskMap;
  final normalized = {...riskMap};
  final hasProbability =
      _readDouble(normalized, const ['probability', 'score', 'value']) != null;
  if (!hasProbability) {
    normalized['probability'] = hint.probability;
  }
  if (_readString(normalized, const ['riskLevel', 'risk_level', 'level', 'badge']) ==
      null) {
    normalized['riskLevel'] = hint.badge;
  }
  return normalized;
}

_SummaryRiskHint? _summaryRiskHint(
  String summary, {
  required String metricPattern,
}) {
  final regex = RegExp(
    '(?:$metricPattern)\\s*:\\s*(low|medium|high)\\s*\\((\\d+(?:\\.\\d+)?)%\\)',
    caseSensitive: false,
  );
  final match = regex.firstMatch(summary);
  if (match == null) return null;

  final level = (match.group(1) ?? '').trim().toLowerCase();
  final percent = double.tryParse((match.group(2) ?? '').trim());
  if (percent == null) return null;

  return _SummaryRiskHint(
    probability: percent / 100,
    badge: level,
  );
}

class _SummaryRiskHint {
  const _SummaryRiskHint({
    required this.probability,
    required this.badge,
  });

  final double probability;
  final String badge;
}

class _RiskOutput {
  const _RiskOutput({
    required this.title,
    required this.probability,
    required this.badge,
    required this.subtitle,
  });

  final String title;
  final double probability;
  final String badge;
  final String subtitle;

  factory _RiskOutput.fromMap(
    Map<String, dynamic> map, {
    required String fallbackTitle,
  }) {
    final probability =
        _readDouble(map, const ['probability', 'score', 'value']) ?? 0;
    return _RiskOutput(
      title:
          _readString(
            map,
            const ['title', 'label', 'public_result_label', 'display_name'],
          ) ??
          fallbackTitle,
      probability: probability > 1 ? probability / 100 : probability,
      badge:
          _readString(map, const ['riskLevel', 'risk_level', 'level', 'badge']) ??
          _badgeForProbability(
            probability > 1 ? probability / 100 : probability,
          ),
      subtitle:
          _readString(
            map,
            const ['subtitle', 'public_subtitle', 'message', 'description'],
          ) ??
          'Returned by the NSCLC AI prediction service.',
    );
  }
}

class _ResistanceInterpretation {
  const _ResistanceInterpretation({
    required this.summary,
    required this.tags,
    required this.signals,
  });

  final String summary;
  final List<String> tags;
  final List<_InterpretationSignal> signals;

  factory _ResistanceInterpretation.fromMap(Map<String, dynamic> map) {
    final tags = _readStringList(map, const ['tags', 'signalTags', 'signal_tags']);
    final signalsRaw = map['signals'];
    final signals = signalsRaw is List
        ? signalsRaw
              .whereType<Map>()
              .map(
                (item) => _InterpretationSignal.fromMap(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList(growable: false)
        : tags
              .map(
                (tag) => _InterpretationSignal(
                  tag: tag,
                  message: 'Signal returned by backend.',
                ),
              )
              .toList(growable: false);

    return _ResistanceInterpretation(
      summary:
          _readString(map, const ['summary', 'summaryText', 'summary_text']) ??
          'Resistance-related interpretation returned by the NSCLC AI service.',
      tags: tags,
      signals: signals,
    );
  }
}

class _InterpretationSignal {
  const _InterpretationSignal({required this.tag, required this.message});

  final String tag;
  final String message;

  factory _InterpretationSignal.fromMap(Map<String, dynamic> map) {
    return _InterpretationSignal(
      tag: _readString(map, const ['tag', 'label', 'name']) ?? 'Signal',
      message:
          _readString(map, const ['message', 'explanation', 'description']) ??
          'Signal returned by backend.',
    );
  }
}

class _ModelDetails {
  const _ModelDetails({
    required this.profileKey,
    required this.modelName,
    required this.featureSet,
    required this.version,
    this.selectedThreshold,
    this.meanAccuracy,
    this.meanRocAuc,
    this.meanBrier,
    this.trainRows,
    this.positiveRows,
    this.negativeRows,
  });

  final String profileKey;
  final String modelName;
  final String featureSet;
  final String version;
  final double? selectedThreshold;
  final double? meanAccuracy;
  final double? meanRocAuc;
  final double? meanBrier;
  final int? trainRows;
  final int? positiveRows;
  final int? negativeRows;

  factory _ModelDetails.fromMap(
    Map<String, dynamic> map, {
    required String fallbackVersion,
  }) {
    return _ModelDetails(
      profileKey:
          _readString(map, const ['profileKey', 'profile_key']) ?? 'nsclc',
      modelName:
          _readString(map, const ['modelName', 'name']) ?? 'Not returned',
      featureSet:
          _readString(map, const ['featureSet', 'feature_set']) ??
          'Not returned',
      selectedThreshold: _readDouble(
        map,
        const ['selectedThreshold', 'selected_threshold', 'threshold'],
      ),
      meanAccuracy: _readDouble(
        map,
        const ['meanAccuracy', 'accuracy', 'mean_accuracy'],
      ),
      meanRocAuc: _readDouble(
        map,
        const ['meanRocAuc', 'rocAuc', 'mean_auc', 'mean_roc_auc'],
      ),
      meanBrier: _readDouble(map, const ['meanBrier', 'mean_brier']),
      trainRows: _readInt(map, const ['trainRows', 'train_rows']),
      positiveRows: _readInt(map, const ['positiveRows', 'positive_rows']),
      negativeRows: _readInt(map, const ['negativeRows', 'negative_rows']),
      version:
          _readString(map, const ['predictionVersion', 'version']) ??
          fallbackVersion,
    );
  }
}

Map<String, dynamic> _toMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, dynamic value) => MapEntry(key.toString(), value));
  }
  return const {};
}

Map<String, dynamic>? _firstMap(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic value) => MapEntry(key.toString(), value));
    }
  }
  return null;
}

String? _readString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return null;
}

double? _readDouble(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

int? _readInt(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

List<String> _readStringList(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
  }
  return const [];
}

List<String> _collectMissingFields(
  Map<String, dynamic> root,
  Map<String, dynamic> acquired,
  List<String> fallback,
) {
  final primary = _readStringList(acquired, const ['missing_raw_fields']);
  final global = _readStringList(root, const [
    'missingFields',
    'missingRawFields',
    'missing_raw_fields',
    'unknownFields',
  ]);
  final combined = <String>[...primary, ...global];
  final unique = <String>[];
  final seen = <String>{};
  for (final item in combined) {
    if (seen.add(item)) unique.add(item);
  }
  return unique.ifEmpty(fallback);
}

String _badgeForProbability(double probability) {
  if (probability >= 0.67) return 'high';
  if (probability >= 0.34) return 'medium';
  return 'low';
}

extension _PredictionRunSorting on Iterable<_PredictionRun> {
  List<_PredictionRun> sortedByDateDesc() {
    final runs = toList(growable: false);
    return [...runs]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}

extension _FallbackList on List<String> {
  List<String> ifEmpty(List<String> fallback) => isEmpty ? fallback : this;
}
