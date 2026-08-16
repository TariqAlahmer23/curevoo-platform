// ignore_for_file: unnecessary_nullable_for_final_variable_declarations, use_build_context_synchronously, deprecated_member_use, unnecessary_to_list_in_spreads

import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:curevoo_doctor/models/patient.dart' as model;
import 'package:curevoo_doctor/providers/medical_history_cubit.dart';
import 'package:curevoo_doctor/providers/patients_cubit.dart';
import 'package:curevoo_doctor/repos/medical_history_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class DiagnosisOption {
  final String value;
  final String labelKey;

  const DiagnosisOption({required this.value, required this.labelKey});
}

class SymptomQuestionAnswerEntry {
  SymptomQuestionAnswerEntry()
    : questionController = TextEditingController(),
      answerController = TextEditingController();

  final TextEditingController questionController;
  final TextEditingController answerController;

  void dispose() {
    questionController.dispose();
    answerController.dispose();
  }
}

class _SymptomQuestionAnswerDraft {
  const _SymptomQuestionAnswerDraft({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;
}

class _DiagnosisFormDraft {
  const _DiagnosisFormDraft({
    required this.patientMode,
    required this.selectedPatientId,
    required this.patientName,
    required this.patientPhone,
    required this.patientAge,
    required this.selectedGender,
    required this.symptomDuration,
    required this.selectedFamilyHistory,
    required this.previousTreatmentHistory,
    required this.selectedShortnessOfBreath,
    required this.selectedCoughingBlood,
    required this.selectedChestPain,
    required this.selectedFaintingOrSevereDizziness,
    required this.selectedRecentWeightLoss,
    required this.selectedSmoker,
    required this.profession,
    required this.selectedHoarseness,
    required this.symptomSectionNotes,
    required this.customQuestionAnswers,
    required this.uploadedImagePaths,
    required this.diagnosisResult,
  });

  final String patientMode;
  final String? selectedPatientId;
  final String patientName;
  final String patientPhone;
  final String patientAge;
  final String? selectedGender;
  final String symptomDuration;
  final String? selectedFamilyHistory;
  final String previousTreatmentHistory;
  final String? selectedShortnessOfBreath;
  final String? selectedCoughingBlood;
  final String? selectedChestPain;
  final String? selectedFaintingOrSevereDizziness;
  final String? selectedRecentWeightLoss;
  final String? selectedSmoker;
  final String profession;
  final String? selectedHoarseness;
  final String symptomSectionNotes;
  final List<_SymptomQuestionAnswerDraft> customQuestionAnswers;
  final List<String> uploadedImagePaths;
  final String? diagnosisResult;
}

_DiagnosisFormDraft? _diagnosisFormDraft;

const List<DiagnosisOption> _genderOptions = [
  DiagnosisOption(value: 'male', labelKey: 'Male'),
  DiagnosisOption(value: 'female', labelKey: 'Female'),
];

const List<DiagnosisOption> _familyHistoryOptions = [
  DiagnosisOption(value: 'yes', labelKey: 'Yes'),
  DiagnosisOption(value: 'no', labelKey: 'No'),
  DiagnosisOption(value: 'unknown', labelKey: 'Unknown'),
];

const List<DiagnosisOption> _yesNoOptions = [
  DiagnosisOption(value: 'yes', labelKey: 'Yes'),
  DiagnosisOption(value: 'no', labelKey: 'No'),
];

class DiagnosisPage extends StatefulWidget {
  const DiagnosisPage({super.key});

  @override
  State<DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends State<DiagnosisPage> {
  bool _isValidGenderSelection(String? value) =>
      value == 'male' || value == 'female';

  bool _isApplyingDraftState = false;
  String? patientSelectionError;
  String? patientNameError;
  String? patientPhoneError;
  String? patientAgeError;
  String? patientGenderError;

  // Patient Selection
  String patientMode = 'select'; // 'select' or 'new'
  String? selectedPatientId;
  model.PatientSummary? selectedPatient;
  final TextEditingController patientSearchController = TextEditingController();
  List<model.PatientSummary> patients = [];
  bool isLoadingPatients = true;
  String? patientsLoadError;

  // Patient Information Controllers
  final TextEditingController patientNameController = TextEditingController();
  final TextEditingController patientPhoneController = TextEditingController();
  final TextEditingController patientAgeController = TextEditingController();
  String? selectedGender;

  // Symptoms & Medical History
  final TextEditingController symptomDurationController =
      TextEditingController();
  String? selectedFamilyHistory;
  final TextEditingController previousTreatmentController =
      TextEditingController();
  String? selectedShortnessOfBreath;
  String? selectedCoughingBlood;
  String? selectedChestPain;
  String? selectedFaintingOrSevereDizziness;
  String? selectedRecentWeightLoss;
  String? selectedSmoker;
  final TextEditingController professionController = TextEditingController();
  String? selectedHoarseness;
  final List<SymptomQuestionAnswerEntry> customSymptomQuestions = [
    SymptomQuestionAnswerEntry(),
  ];
  final TextEditingController symptomSectionNotesController =
      TextEditingController();

  // X-Ray Images
  List<XFile> uploadedImages = [];
  final ImagePicker _picker = ImagePicker();

  // Diagnosis Result
  String? diagnosisResult;
  bool isGeneratingReport = false;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
    _registerDraftListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPatients();
    });
  }

  @override
  void dispose() {
    _unregisterDraftListeners();
    patientSearchController.dispose();
    patientNameController.dispose();
    patientPhoneController.dispose();
    patientAgeController.dispose();
    symptomDurationController.dispose();
    previousTreatmentController.dispose();
    professionController.dispose();
    for (final entry in customSymptomQuestions) {
      entry.dispose();
    }
    symptomSectionNotesController.dispose();
    super.dispose();
  }

  void _registerDraftListeners() {
    final controllers = [
      patientSearchController,
      patientNameController,
      patientPhoneController,
      patientAgeController,
      symptomDurationController,
      previousTreatmentController,
      professionController,
      symptomSectionNotesController,
    ];

    for (final controller in controllers) {
      controller.addListener(_saveDraft);
    }

    for (final entry in customSymptomQuestions) {
      _registerQuestionEntryListeners(entry);
    }
  }

  void _unregisterDraftListeners() {
    final controllers = [
      patientSearchController,
      patientNameController,
      patientPhoneController,
      patientAgeController,
      symptomDurationController,
      previousTreatmentController,
      professionController,
      symptomSectionNotesController,
    ];

    for (final controller in controllers) {
      controller.removeListener(_saveDraft);
    }

    for (final entry in customSymptomQuestions) {
      _unregisterQuestionEntryListeners(entry);
    }
  }

  void _registerQuestionEntryListeners(SymptomQuestionAnswerEntry entry) {
    entry.questionController.addListener(_saveDraft);
    entry.answerController.addListener(_saveDraft);
  }

  void _unregisterQuestionEntryListeners(SymptomQuestionAnswerEntry entry) {
    entry.questionController.removeListener(_saveDraft);
    entry.answerController.removeListener(_saveDraft);
  }

  void _restoreDraft() {
    final draft = _diagnosisFormDraft;
    if (draft == null) return;

    _isApplyingDraftState = true;

    patientMode = draft.patientMode;
    selectedPatientId = draft.selectedPatientId;
    patientNameController.text = draft.patientName;
    patientPhoneController.text = draft.patientPhone;
    patientAgeController.text = draft.patientAge;
    selectedGender = _isValidGenderSelection(draft.selectedGender)
        ? draft.selectedGender
        : null;
    symptomDurationController.text = draft.symptomDuration;
    selectedFamilyHistory = draft.selectedFamilyHistory;
    previousTreatmentController.text = draft.previousTreatmentHistory;
    selectedShortnessOfBreath = draft.selectedShortnessOfBreath;
    selectedCoughingBlood = draft.selectedCoughingBlood;
    selectedChestPain = draft.selectedChestPain;
    selectedFaintingOrSevereDizziness = draft.selectedFaintingOrSevereDizziness;
    selectedRecentWeightLoss = draft.selectedRecentWeightLoss;
    selectedSmoker = draft.selectedSmoker;
    professionController.text = draft.profession;
    selectedHoarseness = draft.selectedHoarseness;
    symptomSectionNotesController.text = draft.symptomSectionNotes;
    diagnosisResult = draft.diagnosisResult;
    uploadedImages = draft.uploadedImagePaths
        .map((path) => XFile(path))
        .toList(growable: true);

    for (final entry in customSymptomQuestions) {
      entry.dispose();
    }
    customSymptomQuestions.clear();

    final restoredEntries = draft.customQuestionAnswers.isEmpty
        ? const [_SymptomQuestionAnswerDraft(question: '', answer: '')]
        : draft.customQuestionAnswers;

    for (final draftEntry in restoredEntries) {
      final entry = SymptomQuestionAnswerEntry()
        ..questionController.text = draftEntry.question
        ..answerController.text = draftEntry.answer;
      customSymptomQuestions.add(entry);
    }

    _isApplyingDraftState = false;
  }

  void _saveDraft() {
    if (_isApplyingDraftState) return;

    _diagnosisFormDraft = _DiagnosisFormDraft(
      patientMode: patientMode,
      selectedPatientId: selectedPatientId,
      patientName: patientNameController.text,
      patientPhone: patientPhoneController.text,
      patientAge: patientAgeController.text,
      selectedGender: _isValidGenderSelection(selectedGender)
          ? selectedGender
          : null,
      symptomDuration: symptomDurationController.text,
      selectedFamilyHistory: selectedFamilyHistory,
      previousTreatmentHistory: previousTreatmentController.text,
      selectedShortnessOfBreath: selectedShortnessOfBreath,
      selectedCoughingBlood: selectedCoughingBlood,
      selectedChestPain: selectedChestPain,
      selectedFaintingOrSevereDizziness: selectedFaintingOrSevereDizziness,
      selectedRecentWeightLoss: selectedRecentWeightLoss,
      selectedSmoker: selectedSmoker,
      profession: professionController.text,
      selectedHoarseness: selectedHoarseness,
      symptomSectionNotes: symptomSectionNotesController.text,
      customQuestionAnswers: customSymptomQuestions
          .map(
            (entry) => _SymptomQuestionAnswerDraft(
              question: entry.questionController.text,
              answer: entry.answerController.text,
            ),
          )
          .toList(growable: false),
      uploadedImagePaths: uploadedImages
          .map((image) => image.path)
          .toList(growable: false),
      diagnosisResult: diagnosisResult,
    );
  }

  void _clearForm({bool keepDiagnosisResult = false}) {
    _isApplyingDraftState = true;

    _clearValidationErrors();
    patientMode = 'select';
    selectedPatientId = null;
    selectedPatient = null;
    patientSearchController.clear();
    patientNameController.clear();
    patientPhoneController.clear();
    patientAgeController.clear();
    selectedGender = null;
    symptomDurationController.clear();
    selectedFamilyHistory = null;
    previousTreatmentController.clear();
    selectedShortnessOfBreath = null;
    selectedCoughingBlood = null;
    selectedChestPain = null;
    selectedFaintingOrSevereDizziness = null;
    selectedRecentWeightLoss = null;
    selectedSmoker = null;
    professionController.clear();
    selectedHoarseness = null;
    symptomSectionNotesController.clear();
    uploadedImages = [];
    if (!keepDiagnosisResult) {
      diagnosisResult = null;
    }

    for (final entry in customSymptomQuestions) {
      _unregisterQuestionEntryListeners(entry);
      entry.dispose();
    }
    customSymptomQuestions
      ..clear()
      ..add(SymptomQuestionAnswerEntry());
    _registerQuestionEntryListeners(customSymptomQuestions.first);

    _diagnosisFormDraft = null;
    _isApplyingDraftState = false;
  }

  Future<void> _loadPatients() async {
    if (!mounted) return;

    setState(() {
      isLoadingPatients = true;
      patientsLoadError = null;
    });

    final patientsCubit = context.read<PatientsCubit>();
    final fetchedPatients = await patientsCubit.fetchPatients();
    if (!mounted) return;

    setState(() {
      patients = fetchedPatients;
      isLoadingPatients = false;
      patientsLoadError = patientsCubit.state.errorMessage;
      if (selectedPatientId != null) {
        model.PatientSummary? matchedPatient;
        for (final patient in fetchedPatients) {
          if (patient.id == selectedPatientId) {
            matchedPatient = patient;
            break;
          }
        }
        selectedPatient = matchedPatient;
        if (matchedPatient == null) {
          selectedPatientId = null;
        }
      }
    });
  }

  // Function to auto-fill patient information when a patient is selected
  void autoFillPatientInfo(model.PatientSummary? patient) {
    if (patient != null) {
      patientNameController.text = patient.fullName;
      patientPhoneController.text = patient.phone;
      patientAgeController.text = patient.age.toString();
      selectedGender = _mapSexToGenderKey(patient.sex);
      patientNameError = null;
      patientPhoneError = null;
      patientAgeError = null;
      patientGenderError = null;
    } else {
      // Clear fields if no patient selected
      patientNameController.clear();
      patientPhoneController.clear();
      patientAgeController.clear();
      selectedGender = null;
    }
    _saveDraft();
  }

  // Function to handle patient selection change
  void onPatientSelected(String? patientId) {
    if (patientId != null) {
      model.PatientSummary? patient;
      for (final item in patients) {
        if (item.id == patientId) {
          patient = item;
          break;
        }
      }

      if (patient == null) {
        setState(() {
          selectedPatientId = null;
          selectedPatient = null;
          patientSelectionError = context.tr('Please select a patient');
          // Clear auto-filled information
          autoFillPatientInfo(null);
        });
        _saveDraft();
        return;
      }

      setState(() {
        selectedPatientId = patientId;
        selectedPatient = patient;
        patientSelectionError = null;
        // Auto-fill patient information
        autoFillPatientInfo(patient);
      });
    } else {
      setState(() {
        selectedPatientId = null;
        selectedPatient = null;
        patientSelectionError = context.tr('Please select a patient');
        // Clear auto-filled information
        autoFillPatientInfo(null);
      });
    }
    _saveDraft();
  }

  Future<void> pickImages() async {
    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null) {
      setState(() {
        uploadedImages.addAll(images);
      });
      _saveDraft();
    }
  }

  void removeImage(int index) {
    setState(() {
      uploadedImages.removeAt(index);
    });
    _saveDraft();
  }

  Future<void> handleSubmitDiagnosis() async {
    final messenger = ScaffoldMessenger.of(context);
    final patientsCubit = context.read<PatientsCubit>();
    final medicalHistoryCubit = context.read<MedicalHistoryCubit>();

    final patientName = patientNameController.text.trim();
    final patientPhone = patientPhoneController.text.trim();
    final patientAge = int.tryParse(patientAgeController.text.trim());
    final patientSex = _mapGenderKeyToApiSex(selectedGender);

    if (!_validateRequiredFields(
      patientName: patientName,
      patientPhone: patientPhone,
      patientAge: patientAge,
      patientSex: patientSex,
    )) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Please complete the highlighted required fields'),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final resolvedPatientAge = patientAge!;
    final resolvedPatientSex = patientSex!;

    setState(() {
      isGeneratingReport = true;
    });

    model.PatientSummary? patientForHistory = selectedPatient;

    try {
      if (patientMode == 'new') {
        patientForHistory = await patientsCubit.createPatientAndReturn(
          model.CreatePatientRequest(
            fullName: patientName,
            phone: patientPhone,
            age: resolvedPatientAge,
            sex: resolvedPatientSex,
          ),
        );

        if (!mounted) return;
        if (patientForHistory == null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                patientsCubit.state.errorMessage ??
                    context.tr('Failed to create patient'),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          return;
        }

        setState(() {
          selectedPatientId = patientForHistory!.id;
          selectedPatient = patientForHistory;
          patientMode = 'select';
        });
        autoFillPatientInfo(patientForHistory);
        await _loadPatients();
        if (!mounted) return;
      }

      if (patientForHistory == null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.tr('Please select a patient')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      final imageAttachments = <MedicalHistoryImageAttachment>[];
      for (final image in uploadedImages) {
        imageAttachments.add(
          MedicalHistoryImageAttachment(
            filename: image.name,
            bytes: await image.readAsBytes(),
          ),
        );
      }

      final submitted = await medicalHistoryCubit.createMedicalHistory(
        patientId: patientForHistory.id,
        request: CreateMedicalHistoryRequest(
          patientName: patientName,
          patientPhone: patientPhone,
          patientAge: resolvedPatientAge,
          patientSex: resolvedPatientSex,
          symptomDuration: symptomDurationController.text.trim(),
          familyHistory: selectedFamilyHistory ?? '',
          previousTreatmentHistory: previousTreatmentController.text.trim(),
          shortnessOfBreath: selectedShortnessOfBreath ?? '',
          coughingBlood: selectedCoughingBlood ?? '',
          chestPain: selectedChestPain ?? '',
          faintingOrSevereDizziness: selectedFaintingOrSevereDizziness ?? '',
          recentWeightLoss: selectedRecentWeightLoss ?? '',
          smoker: selectedSmoker ?? '',
          profession: professionController.text.trim(),
          hoarseness: selectedHoarseness ?? '',
          symptomSectionNotes: symptomSectionNotesController.text.trim(),
          customQuestionAnswers: customSymptomQuestions
              .map(
                (entry) => MedicalHistoryQuestionAnswer(
                  question: entry.questionController.text.trim(),
                  answer: entry.answerController.text.trim(),
                ),
              )
              .where(
                (entry) => entry.question.isNotEmpty || entry.answer.isNotEmpty,
              )
              .toList(growable: false),
          images: imageAttachments,
        ),
      );

      if (!mounted) return;
      if (!submitted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              medicalHistoryCubit.state.errorMessage ??
                  context.tr('Failed to create medical history'),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      setState(() {
        _clearForm();
      });
      _saveDraft();
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.tr('Diagnosis report generated successfully!')),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isGeneratingReport = false;
        });
      }
    }
  }

  bool _validateRequiredFields({
    required String patientName,
    required String patientPhone,
    required int? patientAge,
    required String? patientSex,
  }) {
    final requiredFieldMessage = context.tr('This field is required');

    setState(() {
      patientSelectionError = patientMode == 'select' && selectedPatient == null
          ? context.tr('Please select a patient')
          : null;
      patientNameError = patientName.isEmpty ? requiredFieldMessage : null;
      patientPhoneError = patientPhone.isEmpty ? requiredFieldMessage : null;
      patientAgeError = patientAge == null || patientAge <= 0
          ? requiredFieldMessage
          : null;
      patientGenderError = patientSex == null ? requiredFieldMessage : null;
    });

    return patientSelectionError == null &&
        patientNameError == null &&
        patientPhoneError == null &&
        patientAgeError == null &&
        patientGenderError == null;
  }

  void _clearValidationErrors() {
    patientSelectionError = null;
    patientNameError = null;
    patientPhoneError = null;
    patientAgeError = null;
    patientGenderError = null;
  }

  void _setValidationState(VoidCallback update) {
    setState(() {
      update();
    });
  }

  void addCustomSymptomQuestion() {
    setState(() {
      final entry = SymptomQuestionAnswerEntry();
      customSymptomQuestions.add(entry);
      _registerQuestionEntryListeners(entry);
    });
    _saveDraft();
  }

  void removeCustomSymptomQuestion(int index) {
    setState(() {
      final entry = customSymptomQuestions.removeAt(index);
      _unregisterQuestionEntryListeners(entry);
      entry.dispose();
      if (customSymptomQuestions.isEmpty) {
        final replacement = SymptomQuestionAnswerEntry();
        customSymptomQuestions.add(replacement);
        _registerQuestionEntryListeners(replacement);
      }
    });
    _saveDraft();
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
                children: [
                  _buildHeader(theme, cs),
                  const SizedBox(height: 24),
                  _buildPatientSelectionCard(),
                  const SizedBox(height: 24),
                  _buildPatientInformationCard(),
                  const SizedBox(height: 24),
                  _buildSymptomsCard(),
                  const SizedBox(height: 24),
                  _buildStatsCard(),
                  const SizedBox(height: 24),
                  _buildImageUploadCard(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme cs) {
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
              Icons.medical_services,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Cancer Diagnosis'),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    'Complete the diagnostic form and upload X-ray images for analysis',
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

  Widget _buildPatientSelectionCard() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(
              theme.brightness == Brightness.dark ? 0.22 : 0.06,
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainer.withOpacity(0.56),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withOpacity(0.10),
                  cs.secondary.withOpacity(0.04),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.person_search, size: 22, color: cs.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Patient Selection'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr(
                          'Select an existing patient or create a new one',
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 20,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.tr('Choose an option'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildRadioOption(
                        value: 'select',
                        label: context.tr('Select Existing Patient'),
                        icon: Icons.people_alt,
                        description: context.tr(
                          'Search and choose from registered patients',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildRadioOption(
                        value: 'new',
                        label: context.tr('Create New Patient'),
                        icon: Icons.person_add_alt_1,
                        description: context.tr(
                          'Register a new patient in the system',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: patientMode == 'select'
                      ? _buildSelectPatientSection()
                      : _buildNewPatientInfoCard(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption({
    required String value,
    required String label,
    required IconData icon,
    required String description,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = patientMode == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          patientMode = value;
          patientSelectionError = null;
          patientNameError = null;
          patientPhoneError = null;
          patientAgeError = null;
          patientGenderError = null;
          if (value == 'select') {
            selectedPatientId = null;
            selectedPatient = null;
            autoFillPatientInfo(null);
          } else {
            autoFillPatientInfo(null);
          }
        });
        _saveDraft();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer.withOpacity(0.15)
              : cs.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary.withOpacity(0.15)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 1.2,
              child: Radio<String>(
                value: value,
                groupValue: patientMode,
                onChanged: (val) {
                  setState(() {
                    patientMode = val!;
                    patientSelectionError = null;
                    patientNameError = null;
                    patientPhoneError = null;
                    patientAgeError = null;
                    patientGenderError = null;
                    if (patientMode == 'select') {
                      selectedPatientId = null;
                      selectedPatient = null;
                      autoFillPatientInfo(null);
                    } else {
                      autoFillPatientInfo(null);
                    }
                  });
                  _saveDraft();
                },
                activeColor: cs.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectPatientSection() {
    final cs = Theme.of(context).colorScheme;

    if (isLoadingPatients) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 40,
              width: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('Loading patients...'),
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (patientsLoadError != null && patients.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cs.errorContainer.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.errorContainer),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(
              patientsLoadError!,
              style: TextStyle(color: cs.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadPatients,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.tr('Retry')),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.primary,
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
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 14, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                context.tr('Search and select patient'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final dropdownWidth = constraints.maxWidth;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.tr('Select Patient'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '*',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: patientSelectionError != null
                        ? Border.all(color: cs.error, width: 1.5)
                        : null,
                  ),
                  child: DropdownMenu<String>(
                    controller: patientSearchController,
                    width: dropdownWidth,
                    enableFilter: true,
                    enableSearch: true,
                    requestFocusOnTap: true,
                    initialSelection: selectedPatientId,
                    hintText: context.tr('Search by name, phone, or ID'),
                    leadingIcon: const Icon(Icons.search, size: 18),
                    menuHeight: 360,
                    menuStyle: MenuStyle(
                      fixedSize: WidgetStatePropertyAll(
                        Size(dropdownWidth, 360),
                      ),
                      elevation: const WidgetStatePropertyAll(8),
                    ),
                    inputDecorationTheme: InputDecorationTheme(
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    filterCallback: (entries, filter) {
                      final query = filter.trim().toLowerCase();
                      if (query.isEmpty) return entries;

                      return entries.where((entry) {
                        final patient = patients
                            .cast<model.PatientSummary?>()
                            .firstWhere(
                              (item) => item?.id == entry.value,
                              orElse: () => null,
                            );
                        if (patient == null) return false;

                        return patient.fullName.toLowerCase().contains(query) ||
                            patient.phone.toLowerCase().contains(query) ||
                            patient.id.toLowerCase().contains(query) ||
                            patient.age.toString().contains(query);
                      }).toList();
                    },
                    dropdownMenuEntries: patients
                        .map(
                          (patient) => DropdownMenuEntry<String>(
                            value: patient.id,
                            label: patient.fullName,
                            labelWidget: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 4,
                              ),
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
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      _buildPatientInfoChip(
                                        Icons.phone,
                                        patient.phone,
                                        cs,
                                      ),
                                      _buildPatientInfoChip(
                                        Icons.cake,
                                        '${patient.age}',
                                        cs,
                                      ),
                                      _buildPatientInfoChip(
                                        Icons.face,
                                        _genderLabel(
                                          context,
                                          _mapSexToGenderKey(patient.sex),
                                        ),
                                        cs,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onSelected: onPatientSelected,
                  ),
                ),
                if (patientSelectionError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 16, color: cs.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            patientSelectionError!,
                            style: TextStyle(color: cs.error, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (selectedPatientId != null && selectedPatient != null) ...[
                  const SizedBox(height: 24),
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: _buildSelectedPatientCard(),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPatientInfoChip(IconData icon, String label, ColorScheme cs) {
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

  Widget _buildSelectedPatientCard() {
    final cs = Theme.of(context).colorScheme;
    final patient = selectedPatient!;

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
                    context.tr('Patient Selected'),
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
                      child: _buildInfoChip(
                        icon: Icons.person,
                        label: patient.fullName,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoChip(
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
                      child: _buildInfoChip(
                        icon: Icons.cake,
                        label: '${patient.age} ${context.tr('years')}',
                        color: cs.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.face,
                        label: _genderLabel(
                          context,
                          _mapSexToGenderKey(patient.sex),
                        ),
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
                          context.tr(
                            'Patient information auto-filled from selected patient',
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                            fontStyle: FontStyle.normal,
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

  Widget _buildInfoChip({
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

  Widget _buildNewPatientInfoCard() {
    final cs = Theme.of(context).colorScheme;

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.secondaryContainer.withOpacity(0.2),
              cs.secondaryContainer.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.secondaryContainer),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.secondary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.edit_note, size: 28, color: cs.secondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('New Patient Registration'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.secondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'Please fill in the patient information in the form below',
                    ),
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 12, color: cs.primary),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('All fields marked with * are required'),
                          style: TextStyle(fontSize: 11, color: cs.primary),
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
    );
  }

  Widget _buildPatientInformationCard() {
    return _buildFormCard(
      title: context.tr('Patient Information'),
      icon: Icons.person_outline,
      children: [
        _buildResponsivePair(
          _buildTextField(
            controller: patientNameController,
            label: context.tr('Patient Name'),
            hint: context.tr('Enter patient name'),
            enabled: patientMode == 'new',
            isRequired: true,
            errorText: patientMode == 'new' ? patientNameError : null,
            onChanged: (_) {
              if (patientNameError != null) {
                _setValidationState(() {
                  patientNameError = null;
                });
              }
            },
          ),
          _buildTextField(
            controller: patientPhoneController,
            label: context.tr('Phone'),
            hint: context.tr('Enter phone number'),
            keyboardType: TextInputType.phone,
            enabled: patientMode == 'new',
            isRequired: true,
            errorText: patientMode == 'new' ? patientPhoneError : null,
            onChanged: (_) {
              if (patientPhoneError != null) {
                _setValidationState(() {
                  patientPhoneError = null;
                });
              }
            },
          ),
        ),
        const SizedBox(height: 20),
        _buildResponsivePair(
          _buildTextField(
            controller: patientAgeController,
            label: context.tr('Age'),
            hint: context.tr('Enter age'),
            keyboardType: TextInputType.number,
            enabled: patientMode == 'new',
            isRequired: true,
            errorText: patientMode == 'new' ? patientAgeError : null,
            onChanged: (_) {
              if (patientAgeError != null) {
                _setValidationState(() {
                  patientAgeError = null;
                });
              }
            },
          ),
          _buildDropdownField(
            value: selectedGender,
            label: context.tr('Sex'),
            hint: context.tr('Select sex'),
            items: _genderOptions,
            isRequired: true,
            errorText: patientMode == 'new' ? patientGenderError : null,
            onChanged: (value) {
              setState(() {
                selectedGender = value;
                patientGenderError = null;
              });
              _saveDraft();
            },
            enabled: patientMode == 'new',
          ),
        ),
      ],
    );
  }

  Widget _buildSymptomsCard() {
    return _buildFormCard(
      title: context.tr('Symptoms & Medical History'),
      icon: Icons.local_hospital_outlined,
      children: [
        _buildResponsivePair(
          _buildDropdownField(
            value: selectedShortnessOfBreath,
            label: context.tr('Do you suffer from shortness of breath?'),
            hint: context.tr('Select option'),
            items: _yesNoOptions,
            onChanged: (value) {
              setState(() {
                selectedShortnessOfBreath = value;
              });
              _saveDraft();
            },
          ),
          _buildDropdownField(
            value: selectedCoughingBlood,
            label: context.tr('Is there a cough accompanied by blood?'),
            hint: context.tr('Select option'),
            items: _yesNoOptions,
            onChanged: (value) {
              setState(() {
                selectedCoughingBlood = value;
              });
              _saveDraft();
            },
          ),
        ),
        const SizedBox(height: 20),
        _buildResponsivePair(
          _buildDropdownField(
            value: selectedChestPain,
            label: context.tr('Is there chest pain?'),
            hint: context.tr('Select option'),
            items: _yesNoOptions,
            onChanged: (value) {
              setState(() {
                selectedChestPain = value;
              });
              _saveDraft();
            },
          ),
          _buildDropdownField(
            value: selectedFaintingOrSevereDizziness,
            label: context.tr('Has fainting or severe dizziness occurred?'),
            hint: context.tr('Select option'),
            items: _yesNoOptions,
            onChanged: (value) {
              setState(() {
                selectedFaintingOrSevereDizziness = value;
              });
              _saveDraft();
            },
          ),
        ),
        const SizedBox(height: 20),
        _buildResponsivePair(
          _buildDropdownField(
            value: selectedRecentWeightLoss,
            label: context.tr(
              'Has there been weight loss in the recent period?',
            ),
            hint: context.tr('Select option'),
            items: _yesNoOptions,
            onChanged: (value) {
              setState(() {
                selectedRecentWeightLoss = value;
              });
              _saveDraft();
            },
          ),
          _buildDropdownField(
            value: selectedSmoker,
            label: context.tr('Are you a smoker?'),
            hint: context.tr('Select option'),
            items: _yesNoOptions,
            onChanged: (value) {
              setState(() {
                selectedSmoker = value;
              });
              _saveDraft();
            },
          ),
        ),
        const SizedBox(height: 20),
        _buildResponsivePair(
          _buildTextField(
            controller: professionController,
            label: context.tr('What is your profession?'),
            hint: context.tr('Enter profession'),
          ),
          _buildDropdownField(
            value: selectedHoarseness,
            label: context.tr('Is there hoarseness of voice?'),
            hint: context.tr('Select option'),
            items: _yesNoOptions,
            onChanged: (value) {
              setState(() {
                selectedHoarseness = value;
              });
              _saveDraft();
            },
          ),
        ),
        const SizedBox(height: 20),
        _buildDropdownField(
          value: selectedFamilyHistory,
          label: context.tr('Family History of Cancer'),
          hint: context.tr('Select option'),
          items: _familyHistoryOptions,
          onChanged: (value) {
            setState(() {
              selectedFamilyHistory = value;
            });
            _saveDraft();
          },
        ),
        const SizedBox(height: 20),
        _buildTextAreaField(
          controller: previousTreatmentController,
          label: context.tr('Previous Treatment History'),
          hint: context.tr('List previous treatments, surgeries, or therapies'),
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        _buildSectionSubtitle(context.tr('Additional Questions & Answers')),
        const SizedBox(height: 16),
        ...List.generate(customSymptomQuestions.length, (index) {
          final entry = customSymptomQuestions[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == customSymptomQuestions.length - 1 ? 0 : 16,
            ),
            child: _buildCustomSymptomQuestionCard(entry, index),
          );
        }),
        const SizedBox(height: 20),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: addCustomSymptomQuestion,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.tr('Add question and answer')),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildTextAreaField(
          controller: symptomSectionNotesController,
          label: context.tr('Symptoms Section Notes'),
          hint: context.tr('Add notes related to symptoms and medical history'),
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: symptomDurationController,
          label: context.tr('Symptom Duration'),
          hint: context.tr('e.g., 2 weeks, 3 months'),
        ),
      ],
    );
  }

  Widget _buildResponsivePair(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(children: [first, const SizedBox(height: 16), second]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _buildFormCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
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
            color: cs.shadow.withOpacity(
              theme.brightness == Brightness.dark ? 0.22 : 0.06,
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainer.withOpacity(0.56),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUploadCard() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(
              theme.brightness == Brightness.dark ? 0.22 : 0.06,
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainer.withOpacity(0.56),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.cloud_upload, size: 20, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr('X-Ray Image Upload'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                GestureDetector(
                  onTap: pickImages,
                  child: Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.primary.withOpacity(0.24)),
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cs.surfaceContainer.withOpacity(0.72),
                          cs.secondaryContainer.withOpacity(0.28),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 56,
                          color: cs.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('Click to upload X-ray images'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('PNG, JPG, DICOM up to 10MB'),
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 14, color: cs.primary),
                              const SizedBox(width: 4),
                              Text(
                                context.tr('Select Images'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (uploadedImages.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.image, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${context.tr('Uploaded X-Ray Images')} (${uploadedImages.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...uploadedImages.asMap().entries.map((entry) {
                    final index = entry.key;
                    final image = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: cs.outlineVariant),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              File(image.path),
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: () => removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: cs.error,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: cs.onError,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(
              theme.brightness == Brightness.dark ? 0.22 : 0.06,
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainer.withOpacity(0.56),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.analytics, size: 20, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr('Diagnosis Stats'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildStatRow(context.tr('Total Cases'), '342', cs.primary),
                const SizedBox(height: 12),
                _buildStatRow(context.tr('This Month'), '28', cs.secondary),
                const SizedBox(height: 12),
                _buildStatRow(context.tr('Pending Review'), '5', cs.tertiary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [color.withOpacity(0.08), color.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(
              theme.brightness == Brightness.dark ? 0.22 : 0.06,
            ),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 620;

            final generateButton = ElevatedButton(
              onPressed: isGeneratingReport ? null : handleSubmitDiagnosis,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              child: isGeneratingReport
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.description, size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            context.tr('Generate Diagnosis Report'),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
            );

            final clearButton = OutlinedButton.icon(
              onPressed: isGeneratingReport
                  ? null
                  : () {
                      setState(() {
                        _clearForm();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.tr('Fields cleared successfully'),
                          ),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              label: Text(
                context.tr('Clear All Fields'),
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.onSurface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: cs.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  generateButton,
                  const SizedBox(height: 12),
                  clearButton,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: generateButton),
                const SizedBox(width: 16),
                Expanded(child: clearButton),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionSubtitle(String title) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomSymptomQuestionCard(
    SymptomQuestionAnswerEntry entry,
    int index,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${context.tr('Question')} ${index + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (customSymptomQuestions.length > 1)
                IconButton(
                  onPressed: () => removeCustomSymptomQuestion(index),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: context.tr('Remove'),
                  style: IconButton.styleFrom(foregroundColor: cs.error),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: entry.questionController,
            label: context.tr('Question'),
            hint: context.tr('Enter question'),
            showLabel: false,
          ),
          const SizedBox(height: 16),
          _buildTextAreaField(
            controller: entry.answerController,
            label: context.tr('Answer'),
            hint: context.tr('Enter answer'),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    bool showLabel = true,
    bool isRequired = false,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: errorText != null
                      ? cs.error
                      : (enabled ? cs.onSurface : cs.onSurfaceVariant),
                ),
              ),
              if (isRequired) ...[
                const SizedBox(width: 4),
                Text(
                  '*',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: cs.error,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            hintStyle: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant.withOpacity(0.6),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: errorText != null ? cs.error : cs.outline,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: errorText != null ? cs.error : cs.primary,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            fillColor: enabled
                ? cs.surfaceContainer.withOpacity(0.45)
                : cs.surfaceContainerHigh.withOpacity(0.5),
            filled: true,
          ),
        ),
      ],
    );
  }

  Widget _buildTextAreaField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int maxLines,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant.withOpacity(0.6),
            ),
            alignLabelWithHint: true,
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
              horizontal: 14,
              vertical: 14,
            ),
            fillColor: cs.surfaceContainer.withOpacity(0.45),
            filled: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required String hint,
    required List<DiagnosisOption> items,
    required Function(String?) onChanged,
    bool enabled = true,
    bool isRequired = false,
    String? errorText,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                softWrap: true,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: errorText != null
                      ? cs.error
                      : (enabled ? cs.onSurface : cs.onSurfaceVariant),
                ),
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: cs.error,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: errorText != null ? cs.error : cs.outline,
            ),
            borderRadius: BorderRadius.circular(16),
            color: enabled
                ? cs.surfaceContainer.withOpacity(0.45)
                : cs.surfaceContainerHigh.withOpacity(0.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  hint,
                  style: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6)),
                ),
              ),
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              borderRadius: BorderRadius.circular(16),
              dropdownColor: cs.surface,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: cs.primary),
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item.value,
                  child: Text(context.tr(item.labelKey)),
                );
              }).toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              errorText,
              style: TextStyle(color: cs.error, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}

String _genderLabel(BuildContext context, String? genderKey) {
  switch (genderKey) {
    case 'male':
      return context.tr('Male');
    case 'female':
      return context.tr('Female');
    default:
      return context.tr('Unknown');
  }
}

String? _mapSexToGenderKey(String sex) {
  switch (sex.trim().toLowerCase()) {
    case 'male':
      return 'male';
    case 'female':
      return 'female';
    default:
      return null;
  }
}

String? _mapGenderKeyToApiSex(String? genderKey) {
  switch (genderKey) {
    case 'male':
      return 'MALE';
    case 'female':
      return 'FEMALE';
    default:
      return null;
  }
}
