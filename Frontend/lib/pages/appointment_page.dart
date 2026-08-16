// ignore_for_file: deprecated_member_use

import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:curevoo_doctor/models/create_patient_appointment_request.dart';
import 'package:curevoo_doctor/models/doctor_appointment_item.dart';
import 'package:curevoo_doctor/models/patient.dart';
import 'package:curevoo_doctor/providers/available_times_cubit.dart';
import 'package:curevoo_doctor/providers/dashboard_summary_cubit.dart';
import 'package:curevoo_doctor/providers/patients_cubit.dart';
import 'package:curevoo_doctor/providers/patient_appointments_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class AppointmentTypeOption {
  final String key;
  final String labelKey;

  const AppointmentTypeOption({required this.key, required this.labelKey});
}

class AppointmentRecord {
  final String time;
  final String patient;
  final String phone;
  final String typeKey;
  final String statusKey;

  const AppointmentRecord({
    required this.time,
    required this.patient,
    required this.phone,
    required this.typeKey,
    required this.statusKey,
  });
}

class AppointmentFormResult {
  final String patient;
  final String patientId;
  final String patientType;
  final String phone;
  final DateTime date;
  final String time;
  final String typeKey;
  final String notes;
  final String statusKey;

  const AppointmentFormResult({
    required this.patient,
    required this.patientId,
    required this.patientType,
    required this.phone,
    required this.date,
    required this.time,
    required this.typeKey,
    required this.notes,
    this.statusKey = 'pending',
  });
}

const List<AppointmentTypeOption> _appointmentTypeOptions = [
  AppointmentTypeOption(key: 'checkup', labelKey: 'Check-up'),
  AppointmentTypeOption(key: 'followup', labelKey: 'Follow-up'),
  AppointmentTypeOption(key: 'consultation', labelKey: 'Consultation'),
  AppointmentTypeOption(key: 'vaccination', labelKey: 'Vaccination'),
  AppointmentTypeOption(key: 'emergency', labelKey: 'Emergency'),
  AppointmentTypeOption(key: 'routine', labelKey: 'Routine'),
];

typedef AppointmentSubmitCallback =
    Future<String?> Function(AppointmentFormResult result);

Future<AppointmentFormResult?> showCreateAppointmentDialog(
  BuildContext context, {
  DateTime? initialDate,
  String? initialTime,
  AppointmentSubmitCallback? onSubmit,
}) {
  return showDialog<AppointmentFormResult>(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(32),
          child: CreateAppointmentDialog(
            initialDate: initialDate,
            initialTime: initialTime,
            onSubmit: onSubmit,
          ),
        ),
      );
    },
  );
}

class AppointmentPage extends StatefulWidget {
  const AppointmentPage({super.key});

  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  @override
  void initState() {
    super.initState();
    final savedFilter = context
        .read<PatientAppointmentsCubit>()
        .state
        .activeFilter;
    context.read<PatientAppointmentsCubit>().loadAppointments(
      filter: savedFilter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderSection(),
                  SizedBox(height: 24),
                  _AppointmentsSectionCard(),
                  SizedBox(height: 24),
                  _BookingRequestsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 880;

          final titleBlock = Row(
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
                  Icons.event_note_outlined,
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
                      context.tr('Appointment Management'),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('Manage and schedule patient appointments'),
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
          );

          final action = FilledButton.icon(
            onPressed: () async {
              final result = await showCreateAppointmentDialog(
                context,
                onSubmit: (result) async {
                  final appointmentsCubit = context
                      .read<PatientAppointmentsCubit>();
                  final request = CreatePatientAppointmentRequest(
                    patientId: result.patientId,
                    patientType: result.patientType,
                    appointmentDate: DateFormat(
                      'yyyy-MM-dd',
                    ).format(result.date),
                    appointmentTime: _to24HourTime(result.time),
                    reason: _reasonFromTypeKey(result.typeKey),
                    notes: result.notes,
                  );

                  final created = await appointmentsCubit
                      .createAppointmentRequest(request);
                  if (created) return null;

                  return appointmentsCubit.state.errorMessage ??
                      'Failed to create appointment request.';
                },
              );
              if (!context.mounted) return;
              if (result == null) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr('Appointment created successfully')),
                  backgroundColor: cs.secondary,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: Text(context.tr('New Appointment')),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [titleBlock, const SizedBox(height: 16), action],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 16),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _AppointmentsSectionCard extends StatelessWidget {
  const _AppointmentsSectionCard();

  @override
  Widget build(BuildContext context) {
    return const _AppointmentsSectionCardBody();
  }
}

class _AppointmentsSectionCardBody extends StatefulWidget {
  const _AppointmentsSectionCardBody();

  @override
  State<_AppointmentsSectionCardBody> createState() =>
      _AppointmentsSectionCardBodyState();
}

class _AppointmentsSectionCardBodyState
    extends State<_AppointmentsSectionCardBody> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
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
              theme.brightness == Brightness.dark ? 0.2 : 0.06,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AppointmentsHeader(
            onSearchChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _AppointmentsTable(searchQuery: _searchQuery),
          ),
        ],
      ),
    );
  }
}

String _reasonFromTypeKey(String typeKey) {
  switch (typeKey) {
    case 'checkup':
      return 'Check-up';
    case 'followup':
      return 'Follow-up';
    case 'consultation':
      return 'Consultation';
    case 'vaccination':
      return 'Vaccination';
    case 'emergency':
      return 'Emergency';
    case 'routine':
      return 'Routine';
    default:
      return typeKey;
  }
}

String _to24HourTime(String displayTime) {
  final parsed = DateFormat('hh:mm a').parse(displayTime);
  return DateFormat('HH:mm').format(parsed);
}

DateTime? _parseAppointmentDate(String rawDate) {
  final trimmed = rawDate.trim();
  if (trimmed.isEmpty) return null;
  final formats = <DateFormat>[
    DateFormat('yyyy-MM-dd'),
    DateFormat('yyyy/MM/dd'),
    DateFormat('MM/dd/yyyy'),
    DateFormat('M/d/yyyy'),
  ];

  for (final format in formats) {
    try {
      return format.parseStrict(trimmed);
    } catch (_) {
      // Try the next known API/display shape.
    }
  }

  return DateTime.tryParse(trimmed);
}

String? _toDisplayTime(String rawTime) {
  final trimmed = rawTime.trim();
  if (trimmed.isEmpty) return null;
  if (RegExp(
    r'^\d{1,2}:\d{2}\s*(AM|PM)$',
    caseSensitive: false,
  ).hasMatch(trimmed)) {
    final parsed = DateFormat('hh:mm a').parse(trimmed.toUpperCase());
    return DateFormat('hh:mm a').format(parsed);
  }
  final parts = trimmed.split(':');
  if (parts.length < 2) return trimmed;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return trimmed;
  final parsed = DateTime(2000, 1, 1, hour, minute);
  return DateFormat('hh:mm a').format(parsed);
}

String _typeKeyFromReason(String reason) {
  final normalized = reason.trim().toLowerCase();
  for (final option in _appointmentTypeOptions) {
    if (option.key.toLowerCase() == normalized ||
        option.labelKey.toLowerCase() == normalized) {
      return option.key;
    }
  }
  return normalized;
}

class CreateAppointmentDialog extends StatefulWidget {
  final DateTime? initialDate;
  final String? initialTime;
  final DoctorAppointmentItem? initialAppointment;
  final AppointmentSubmitCallback? onSubmit;

  const CreateAppointmentDialog({
    super.key,
    this.initialDate,
    this.initialTime,
    this.initialAppointment,
    this.onSubmit,
  });

  @override
  State<CreateAppointmentDialog> createState() =>
      _CreateAppointmentDialogState();
}

class _CreateAppointmentDialogState extends State<CreateAppointmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _patientNameController = TextEditingController();
  final _patientSearchController = TextEditingController();
  final _patientIdController = TextEditingController();
  final _phoneController = TextEditingController(text: '+1 234-567-8900');
  final _dateController = TextEditingController();
  final _notesController = TextEditingController();
  PatientSummary? _selectedPatient;
  List<PatientSummary> _patients = const [];
  bool _isLoadingPatients = false;
  String? _patientsErrorMessage;
  String? _patientSelectionError;
  String? _availableTimesErrorMessage;
  String? _selectedType;
  String? _selectedTime;
  bool _isSubmittingAppointment = false;
  String? _submitErrorMessage;
  // ignore: unused_field
  DateTime? _selectedDate;

  bool get _isEditing => widget.initialAppointment != null;

  @override
  void initState() {
    super.initState();
    _loadPatients();
    final initialAppointment = widget.initialAppointment;
    if (initialAppointment != null) {
      _selectedDate = _parseAppointmentDate(initialAppointment.appointmentDate);
      _selectedTime = _toDisplayTime(initialAppointment.appointmentTime);
      _selectedType = _typeKeyFromReason(initialAppointment.reason);
      _notesController.text = initialAppointment.notes ?? '';
      _patientNameController.text = initialAppointment.patientName;
      _patientSearchController.text = initialAppointment.patientName;
      _phoneController.text = initialAppointment.patientPhone;
      _selectedPatient = PatientSummary(
        id: initialAppointment.patientId ?? '',
        fullName: initialAppointment.patientName,
        age: 0,
        sex: '',
        phone: initialAppointment.patientPhone,
      );
      if (_selectedDate != null) {
        _dateController.text = DateFormat.yMd().format(_selectedDate!);
      }
    } else if (widget.initialDate != null) {
      _selectedDate = widget.initialDate;
      _dateController.text = DateFormat.yMd().format(widget.initialDate!);
    }
    if (widget.initialTime != null) {
      _selectedTime = widget.initialTime;
    }
    if (_selectedDate != null) {
      _loadAvailableTimesForSelectedDay();
    }
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoadingPatients = true;
      _patientsErrorMessage = null;
    });

    final patients = await context.read<PatientsCubit>().fetchPatients();
    if (!mounted) return;

    final error = context.read<PatientsCubit>().state.errorMessage;
    setState(() {
      _isLoadingPatients = false;
      _patients = patients;
      if (_selectedPatient != null) {
        final selectedId = _selectedPatient!.id;
        PatientSummary? refreshed;
        for (final p in patients) {
          if ((selectedId.isNotEmpty && p.id == selectedId) ||
              (selectedId.isEmpty &&
                  p.fullName == _selectedPatient!.fullName &&
                  p.phone == _selectedPatient!.phone)) {
            refreshed = p;
            break;
          }
        }
        _selectedPatient = refreshed ?? _selectedPatient;
      }
      _patientsErrorMessage =
          (patients.isEmpty && error != null && error.trim().isNotEmpty)
          ? error
          : null;
    });
  }

  Future<void> _loadAvailableTimesForSelectedDay() async {
    final selectedDate = _selectedDate;
    if (selectedDate == null) return;

    await context.read<AvailableTimesCubit>().loadAvailableTimesForDay(
      date: DateFormat('yyyy-MM-dd').format(selectedDate),
      forceRefresh: true,
    );
    if (!mounted) return;

    final error = context.read<AvailableTimesCubit>().state.errorMessage;
    setState(() {
      _availableTimesErrorMessage = error != null && error.trim().isNotEmpty
          ? error
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final availableTimesState = context.watch<AvailableTimesCubit>().state;
    final selectedDateKey = _selectedDate == null
        ? null
        : DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final availableTimeSlots =
        availableTimesState.loadedDayDate == selectedDateKey
        ? availableTimesState.dayAvailableTimes.toList(growable: true)
        : <String>[];
    if (_selectedTime != null &&
        _selectedTime!.trim().isNotEmpty &&
        !availableTimeSlots.contains(_selectedTime)) {
      availableTimeSlots.add(_selectedTime!);
    }
    final selectedTimeValue = availableTimeSlots.contains(_selectedTime)
        ? _selectedTime
        : null;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        _isEditing ? 'Edit Appointment' : 'New Appointment',
                      ),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(
                        _isEditing
                            ? 'Update appointment details'
                            : 'Create a new appointment for a patient',
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Form Fields
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Patient Name
                      Text(
                        context.tr('Patient Name'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return DropdownMenu<String>(
                            width: constraints.maxWidth,
                            controller: _patientSearchController,
                            initialSelection: _selectedPatient?.id,
                            enabled: !_isEditing,
                            enableSearch: true,
                            enableFilter: true,
                            hintText: _isLoadingPatients
                                ? context.tr('Loading...')
                                : context.tr('Search and select patient'),
                            inputDecorationTheme: InputDecorationTheme(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: cs.outline),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: cs.outline),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: cs.primary),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            trailingIcon: _isLoadingPatients
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.expand_more),
                            filterCallback: (entries, filter) {
                              final query = filter.trim().toLowerCase();
                              if (query.isEmpty) return entries;
                              return entries
                                  .where((entry) {
                                    PatientSummary? patient;
                                    for (final p in _patients) {
                                      if (p.id == entry.value) {
                                        patient = p;
                                        break;
                                      }
                                    }
                                    if (patient == null) return false;
                                    return patient.fullName
                                            .toLowerCase()
                                            .contains(query) ||
                                        patient.phone.toLowerCase().contains(
                                          query,
                                        ) ||
                                        patient.id.toLowerCase().contains(
                                          query,
                                        );
                                  })
                                  .toList(growable: false);
                            },
                            dropdownMenuEntries: _patients
                                .map(
                                  (patient) => DropdownMenuEntry<String>(
                                    value: patient.id,
                                    label: patient.fullName,
                                    labelWidget: Align(
                                      alignment:
                                          AlignmentDirectional.centerStart,
                                      child: Text(
                                        patient.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.start,
                                      ),
                                    ),
                                    trailingIcon: Text(
                                      patient.phone,
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            onSelected: (patientId) {
                              PatientSummary? selected;
                              if (patientId != null) {
                                for (final patient in _patients) {
                                  if (patient.id == patientId) {
                                    selected = patient;
                                    break;
                                  }
                                }
                              }

                              setState(() {
                                _selectedPatient = selected;
                                _patientSelectionError = selected == null
                                    ? context.tr('Please select a patient')
                                    : null;
                                _patientNameController.text =
                                    selected?.fullName ?? '';
                                _patientIdController.text = selected?.id ?? '';
                                _phoneController.text = selected?.phone ?? '';
                              });
                            },
                          );
                        },
                      ),
                      if (_patientSelectionError != null) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _patientSelectionError!,
                            style: TextStyle(color: cs.error, fontSize: 12),
                          ),
                        ),
                      ],
                      if (_patientsErrorMessage != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _patientsErrorMessage!,
                                style: TextStyle(color: cs.error, fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadPatients,
                              child: Text(context.tr('Retry')),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Phone Number
                      Text(
                        context.tr('Phone Number'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        readOnly: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: cs.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: cs.outline),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Right Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date
                      Text(
                        context.tr('Date'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: context.tr('Select date'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: cs.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: cs.outline),
                          ),
                          suffixIcon: const Icon(
                            Icons.calendar_today,
                            size: 18,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              _selectedDate = pickedDate;
                              _selectedTime = null;
                              _dateController.text = DateFormat.yMd(
                                Localizations.localeOf(context).toLanguageTag(),
                              ).format(pickedDate);
                            });
                            await _loadAvailableTimesForSelectedDay();
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return context.tr('Please select a date');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Text(
                        context.tr('Time'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedTimeValue,
                        hint: Text(
                          _selectedDate == null
                              ? context.tr('Please select a date')
                              : availableTimesState.isLoadingDayTimes
                              ? context.tr('Loading...')
                              : context.tr('Select time'),
                        ),
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: cs.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: cs.outline),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: availableTimeSlots.map((time) {
                          return DropdownMenuItem(
                            value: time,
                            child: Text(time),
                          );
                        }).toList(),
                        onChanged:
                            (_selectedDate == null ||
                                availableTimesState.isLoadingDayTimes ||
                                availableTimeSlots.isEmpty)
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedTime = value;
                                });
                              },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return context.tr('Please select time');
                          }
                          return null;
                        },
                      ),
                      if (_selectedDate != null &&
                          availableTimeSlots.isEmpty &&
                          !availableTimesState.isLoadingDayTimes)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _availableTimesErrorMessage ??
                                context.tr('No available times found'),
                            style: TextStyle(color: cs.error, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Appointment Type
                      Text(
                        context.tr('Appointment Type'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          // border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          hint: Text(context.tr('Select appointment type')),
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                          items: _appointmentTypeOptions.map((type) {
                            return DropdownMenuItem(
                              value: type.key,
                              child: Text(context.tr(type.labelKey)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return context.tr(
                                'Please select appointment type',
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Additional Notes (Full Width)
            Text(
              context.tr('Additional Notes'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: context.tr('Add notes'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.outline),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            if (_submitErrorMessage != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _submitErrorMessage!,
                  style: TextStyle(
                    color: cs.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    foregroundColor: cs.onSurfaceVariant,
                  ),
                  child: Text(context.tr('Cancel')),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _isSubmittingAppointment
                      ? null
                      : () async {
                          final isFormValid = _formKey.currentState!.validate();
                          if (_selectedPatient == null && _isEditing) {
                            _selectedPatient = PatientSummary(
                              id: widget.initialAppointment?.patientId ?? '',
                              fullName:
                                  widget.initialAppointment?.patientName ?? '',
                              age: 0,
                              sex: '',
                              phone:
                                  widget.initialAppointment?.patientPhone ?? '',
                            );
                          }
                          if (_selectedPatient == null) {
                            setState(() {
                              _patientSelectionError = context.tr(
                                'Please select a patient',
                              );
                            });
                            return;
                          }
                          if (!isFormValid) return;

                          setState(() {
                            _patientSelectionError = null;
                            _submitErrorMessage = null;
                          });

                          final payload = AppointmentFormResult(
                            patient: _selectedPatient!.fullName,
                            patientId: _selectedPatient!.id,
                            patientType:
                                widget.initialAppointment?.patientType ??
                                'NORMAL',
                            phone: _phoneController.text.trim(),
                            date: _selectedDate!,
                            time: _selectedTime!,
                            typeKey: _selectedType!,
                            notes: _notesController.text.trim(),
                          );

                          if (widget.onSubmit == null) {
                            Navigator.of(context).pop(payload);
                            return;
                          }

                          setState(() {
                            _isSubmittingAppointment = true;
                          });

                          String? errorMessage;
                          try {
                            errorMessage = await widget.onSubmit!(payload);
                          } catch (_) {
                            errorMessage = _isEditing
                                ? 'Failed to update appointment.'
                                : 'Failed to create appointment request.';
                          }
                          if (!context.mounted) return;

                          if (errorMessage == null ||
                              errorMessage.trim().isEmpty) {
                            Navigator.of(context).pop(payload);
                            return;
                          }

                          setState(() {
                            _isSubmittingAppointment = false;
                            _submitErrorMessage = errorMessage;
                          });
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _isSubmittingAppointment
                        ? context.tr('Loading...')
                        : context.tr(
                            _isEditing
                                ? 'Update Appointment'
                                : 'Save Appointment',
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _patientSearchController.dispose();
    _patientIdController.dispose();
    _phoneController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

class _AppointmentsHeader extends StatelessWidget {
  const _AppointmentsHeader({required this.onSearchChanged});

  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appointmentsState = context.watch<PatientAppointmentsCubit>().state;
    final selectedFilter = appointmentsState.activeFilter;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainer.withOpacity(0.56),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.table_chart_outlined,
                  color: cs.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                context.tr('All Appointments'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 620;

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        hintText: context.tr('Search appointments...'),
                        hintStyle: TextStyle(color: cs.onSurfaceVariant),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: cs.primary, width: 1.5),
                        ),
                        filled: true,
                        fillColor: cs.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: DropdownButtonFormField<String>(
                              value: selectedFilter,
                              isExpanded: true,
                              borderRadius: BorderRadius.circular(14),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: cs.surface,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: cs.outlineVariant,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: cs.outlineVariant,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: cs.primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'ALL',
                                  child: Text(
                                    'ALL',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'PENDING',
                                  child: Text(
                                    'PENDING',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'CREATED',
                                  child: Text(
                                    'CREATED',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'CONFIRMED',
                                  child: Text(
                                    'CONFIRMED',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'CANCELED',
                                  child: Text(
                                    'CANCELED',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'UPCOMING',
                                  child: Text(
                                    'UPCOMING',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                context
                                    .read<PatientAppointmentsCubit>()
                                    .loadAppointments(
                                      filter: value,
                                      forceRefresh: true,
                                    );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: appointmentsState.isLoading
                              ? null
                              : () {
                                  context
                                      .read<PatientAppointmentsCubit>()
                                      .loadAppointments(
                                        filter: selectedFilter,
                                        forceRefresh: true,
                                      );
                                },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(
                            appointmentsState.isLoading
                                ? context.tr('Loading...')
                                : context.tr('Refresh'),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            side: BorderSide(color: cs.outlineVariant),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            foregroundColor: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      onChanged: onSearchChanged,
                      decoration: InputDecoration(
                        hintText: context.tr('Search appointments...'),
                        hintStyle: TextStyle(color: cs.onSurfaceVariant),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: cs.primary, width: 1.5),
                        ),
                        filled: true,
                        fillColor: cs.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 190,
                    height: 50,
                    child: DropdownButtonFormField<String>(
                      value: selectedFilter,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: cs.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: cs.primary, width: 1.5),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ALL',
                          child: Text('ALL', style: TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: 'PENDING',
                          child: Text(
                            'PENDING',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'CREATED',
                          child: Text(
                            'CREATED',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'CONFIRMED',
                          child: Text(
                            'CONFIRMED',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'CANCELED',
                          child: Text(
                            'CANCELED',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'UPCOMING',
                          child: Text(
                            'UPCOMING',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        context
                            .read<PatientAppointmentsCubit>()
                            .loadAppointments(
                              filter: value,
                              forceRefresh: true,
                            );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: appointmentsState.isLoading
                        ? null
                        : () {
                            context
                                .read<PatientAppointmentsCubit>()
                                .loadAppointments(
                                  filter: selectedFilter,
                                  forceRefresh: true,
                                );
                          },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      appointmentsState.isLoading
                          ? context.tr('Loading...')
                          : context.tr('Refresh'),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      side: BorderSide(color: cs.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      foregroundColor: cs.onSurface,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BookingRequestsSection extends StatefulWidget {
  const _BookingRequestsSection();

  @override
  State<_BookingRequestsSection> createState() =>
      _BookingRequestsSectionState();
}

class _BookingRequestsSectionState extends State<_BookingRequestsSection> {
  final Set<String> _processingRequestIds = <String>{};

  Future<void> _handleDecision(
    DoctorAppointmentItem request, {
    required bool accept,
  }) async {
    if (_processingRequestIds.contains(request.id)) return;

    setState(() {
      _processingRequestIds.add(request.id);
    });

    final cubit = context.read<PatientAppointmentsCubit>();
    final success = await cubit.respondToPendingAppointment(
      appointmentId: request.id,
      action: accept ? 'approve' : 'reject',
    );

    if (!mounted) return;
    if (success) {
      context.read<DashboardSummaryCubit>().markPendingAppointmentHandled();
    }

    setState(() {
      _processingRequestIds.remove(request.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (accept
                    ? context.tr('Request accepted successfully')
                    : context.tr('Request rejected successfully'))
              : (cubit.state.errorMessage ?? context.tr('Request failed.')),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              theme.brightness == Brightness.dark ? 0.2 : 0.06,
            ),
            blurRadius: 22,
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
              color: cs.surfaceContainer.withOpacity(0.56),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.book_online, color: cs.primary, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('Booking Appointment Requests'),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          BlocBuilder<PatientAppointmentsCubit, PatientAppointmentsState>(
            builder: (context, state) {
              final pendingRequests = state.appointments
                  .where(
                    (appointment) =>
                        appointment.status.toUpperCase() == 'PENDING',
                  )
                  .toList(growable: false);

              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pendingRequests.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainer.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Text(
                          context.tr('No booking requests for now'),
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      )
                    else
                      ...pendingRequests.map((request) {
                        final isProcessing = _processingRequestIds.contains(
                          request.id,
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainer.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.patientName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 16,
                                runSpacing: 6,
                                children: [
                                  _requestMetaText(
                                    context,
                                    '${context.tr('Date')}: ${_formatAppointmentDateForRequest(context, request.appointmentDate)}',
                                  ),
                                  _requestMetaText(
                                    context,
                                    '${context.tr('Time')}: ${request.appointmentTime}',
                                  ),
                                  _requestMetaText(
                                    context,
                                    '${context.tr('Appointment Type')}: ${request.reason}',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${context.tr('Notice')}: ${request.notes ?? '-'}',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: isProcessing
                                        ? null
                                        : () => _handleDecision(
                                            request,
                                            accept: false,
                                          ),
                                    icon: isProcessing
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: cs.error,
                                            ),
                                          )
                                        : const Icon(Icons.close, size: 18),
                                    label: Text(context.tr('Reject')),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: cs.error,
                                      side: BorderSide(
                                        color: cs.error.withOpacity(0.45),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  FilledButton.icon(
                                    onPressed: isProcessing
                                        ? null
                                        : () => _handleDecision(
                                            request,
                                            accept: true,
                                          ),
                                    icon: isProcessing
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: cs.onPrimary,
                                            ),
                                          )
                                        : const Icon(Icons.check, size: 18),
                                    label: Text(context.tr('Accept')),
                                    style: FilledButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

Widget _requestMetaText(BuildContext context, String text) {
  return Text(
    text,
    style: TextStyle(
      fontSize: 13,
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w500,
    ),
  );
}

Future<AppointmentFormResult?> showEditAppointmentDialog(
  BuildContext context, {
  required DoctorAppointmentItem appointment,
  AppointmentSubmitCallback? onSubmit,
}) {
  return showDialog<AppointmentFormResult>(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(32),
          child: CreateAppointmentDialog(
            initialAppointment: appointment,
            onSubmit: onSubmit,
          ),
        ),
      );
    },
  );
}

String _formatAppointmentDateForRequest(BuildContext context, String rawDate) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final formats = <DateFormat>[
    DateFormat('yyyy-MM-dd'),
    DateFormat('yyyy/MM/dd'),
    DateFormat('MM/dd/yyyy'),
    DateFormat('dd/MM/yyyy'),
  ];

  for (final format in formats) {
    try {
      final parsed = format.parseStrict(rawDate);
      return DateFormat.yMd(locale).format(parsed);
    } catch (_) {
      // Try the next known backend date format.
    }
  }

  return rawDate;
}

class _AppointmentsTable extends StatelessWidget {
  const _AppointmentsTable({required this.searchQuery});

  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return BlocBuilder<PatientAppointmentsCubit, PatientAppointmentsState>(
      builder: (context, state) {
        final normalizedSearch = searchQuery.trim().toLowerCase();
        final filteredAppointments = normalizedSearch.isEmpty
            ? state.appointments
            : state.appointments
                  .where((appointment) {
                    return appointment.patientName.toLowerCase().contains(
                          normalizedSearch,
                        ) ||
                        appointment.patientPhone.toLowerCase().contains(
                          normalizedSearch,
                        ) ||
                        appointment.reason.toLowerCase().contains(
                          normalizedSearch,
                        ) ||
                        appointment.status.toLowerCase().contains(
                          normalizedSearch,
                        ) ||
                        appointment.appointmentDate.toLowerCase().contains(
                          normalizedSearch,
                        ) ||
                        appointment.appointmentTime.toLowerCase().contains(
                          normalizedSearch,
                        );
                  })
                  .toList(growable: false);

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Theme(
                    data: theme.copyWith(
                      dataTableTheme: DataTableThemeData(
                        headingRowHeight: 56,
                        dataRowHeight: 64,
                        headingTextStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                        dataTextStyle: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    child: DataTable(
                      showCheckboxColumn: false,
                      columnSpacing: 24,
                      horizontalMargin: 24,
                      headingRowColor: WidgetStateProperty.all(
                        cs.surfaceContainer,
                      ),
                      border: TableBorder(
                        horizontalInside: BorderSide(
                          color: cs.outlineVariant,
                          width: 1,
                        ),
                        verticalInside: BorderSide.none,
                      ),
                      columns: [
                        DataColumn(
                          label: Text(
                            context.tr('Time'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            context.tr('Patient'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            context.tr('Phone'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            context.tr('Type'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            context.tr('Status'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            context.tr('Actions'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: filteredAppointments.isEmpty
                          ? [
                              DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      state.isLoading
                                          ? context.tr('Loading...')
                                          : context.tr('No appointments found'),
                                    ),
                                  ),
                                  const DataCell(Text('')),
                                  const DataCell(Text('')),
                                  const DataCell(Text('')),
                                  const DataCell(Text('')),
                                  const DataCell(Text('')),
                                ],
                              ),
                            ]
                          : filteredAppointments
                                .map(
                                  (appointment) =>
                                      _buildDataRow(context, appointment),
                                )
                                .toList(),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    DoctorAppointmentItem appointment,
  ) {
    final cs = Theme.of(context).colorScheme;

    return DataRow(
      onSelectChanged: (_) => _showAppointmentDetails(context, appointment),
      cells: [
        DataCell(
          Text(
            _formatTableDateTime(
              appointment.appointmentDate,
              appointment.appointmentTime,
            ),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        DataCell(Text(appointment.patientName)),
        DataCell(Text(appointment.patientPhone)),
        DataCell(Text(appointment.reason)),
        DataCell(_StatusChip(statusKey: appointment.status)),
        DataCell(
          Row(
            children: [
              TextButton(
                onPressed: () => _editAppointment(context, appointment),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: cs.primary,
                ),
                child: Text(context.tr('Edit')),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _showAppointmentDetails(context, appointment),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: cs.primary,
                ),
                child: Text(context.tr('View')),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _deleteAppointment(context, appointment),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: cs.error,
                ),
                child: Text(context.tr('Delete')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editAppointment(
    BuildContext context,
    DoctorAppointmentItem appointment,
  ) async {
    final result = await showEditAppointmentDialog(
      context,
      appointment: appointment,
      onSubmit: (result) async {
        final appointmentsCubit = context.read<PatientAppointmentsCubit>();
        final request = UpdatePatientAppointmentRequest(
          appointmentDate: DateFormat('yyyy-MM-dd').format(result.date),
          appointmentTime: _to24HourTime(result.time),
          reason: _reasonFromTypeKey(result.typeKey),
          notes: result.notes,
        );

        final updated = await appointmentsCubit.updateAppointment(
          appointmentId: appointment.id,
          request: request,
        );
        if (updated) return null;

        return appointmentsCubit.state.errorMessage ??
            'Failed to update appointment.';
      },
    );
    if (!context.mounted || result == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('Appointment updated successfully')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteAppointment(
    BuildContext context,
    DoctorAppointmentItem appointment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.tr('Delete Appointment')),
          content: Text(
            context.tr('Are you sure you want to delete this appointment?'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(context.tr('Delete')),
            ),
          ],
        );
      },
    );
    if (!context.mounted || confirmed != true) return;

    final cubit = context.read<PatientAppointmentsCubit>();
    final deleted = await cubit.deleteAppointment(
      appointmentId: appointment.id,
    );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? context.tr('Appointment deleted successfully')
              : (cubit.state.errorMessage ??
                    context.tr('Failed to delete appointment.')),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAppointmentDetails(
    BuildContext context,
    DoctorAppointmentItem appointment,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final cs = theme.colorScheme;
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final inset = EdgeInsets.all(screenWidth < 600 ? 12 : 20);
        final dialogWidth = (screenWidth - inset.horizontal)
            .clamp(320.0, 600.0)
            .toDouble();
        final compact = dialogWidth < 560;

        return Dialog(
          insetPadding: inset,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: dialogWidth,
            padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Appointment Details'),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.tr(
                                'Review appointment information and notes',
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: cs.surfaceContainerHighest
                              .withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cs.primary.withOpacity(0.05),
                          cs.primary.withOpacity(0.02),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cs.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [cs.primary, cs.primaryContainer],
                            ),
                          ),
                          child: Icon(
                            Icons.event_note_outlined,
                            color: cs.onPrimary,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appointment.patientName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _StatusChip(statusKey: appointment.status),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (compact)
                    Column(
                      children: [
                        _AppointmentDetailLine(
                          icon: Icons.phone_outlined,
                          label: context.tr('Phone'),
                          value: appointment.patientPhone,
                        ),
                        const SizedBox(height: 12),
                        _AppointmentDetailLine(
                          icon: Icons.calendar_today_outlined,
                          label: context.tr('Date'),
                          value: appointment.appointmentDate,
                        ),
                        const SizedBox(height: 12),
                        _AppointmentDetailLine(
                          icon: Icons.access_time_outlined,
                          label: context.tr('Time'),
                          value: appointment.appointmentTime,
                        ),
                        const SizedBox(height: 12),
                        _AppointmentDetailLine(
                          icon: Icons.medical_services_outlined,
                          label: context.tr('Appointment Type'),
                          value: appointment.reason,
                        ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _AppointmentDetailLine(
                                icon: Icons.phone_outlined,
                                label: context.tr('Phone'),
                                value: appointment.patientPhone,
                              ),
                              const SizedBox(height: 12),
                              _AppointmentDetailLine(
                                icon: Icons.calendar_today_outlined,
                                label: context.tr('Date'),
                                value: appointment.appointmentDate,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              _AppointmentDetailLine(
                                icon: Icons.access_time_outlined,
                                label: context.tr('Time'),
                                value: appointment.appointmentTime,
                              ),
                              const SizedBox(height: 12),
                              _AppointmentDetailLine(
                                icon: Icons.medical_services_outlined,
                                label: context.tr('Appointment Type'),
                                value: appointment.reason,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  _AppointmentDetailLine(
                    icon: Icons.notes_outlined,
                    label: context.tr('Additional Notes'),
                    value: appointment.notes?.trim().isNotEmpty == true
                        ? appointment.notes!
                        : '-',
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          foregroundColor: cs.onSurfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(context.tr('Close')),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _deleteAppointment(context, appointment);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text(context.tr('Delete')),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error.withOpacity(0.35)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _editAppointment(context, appointment);
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(context.tr('Edit')),
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AppointmentDetailLine extends StatelessWidget {
  const _AppointmentDetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTableDateTime(String date, String time) {
  if (date.trim().isEmpty && time.trim().isEmpty) return '-';
  if (date.trim().isEmpty) return time;
  if (time.trim().isEmpty) return date;
  return '$date $time';
}

class _StatusChip extends StatelessWidget {
  final String statusKey;

  const _StatusChip({required this.statusKey});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normalized = statusKey.trim().toUpperCase();

    late final Color backgroundColor;
    late final Color textColor;
    late final String labelKey;

    switch (normalized) {
      case 'CONFIRMED':
        backgroundColor = Colors.green.withOpacity(isDark ? 0.25 : 0.12);
        textColor = Colors.green.shade700;
        labelKey = 'Confirmed';
        break;
      case 'PENDING':
        backgroundColor = Colors.orange.withOpacity(isDark ? 0.25 : 0.12);
        textColor = Colors.orange.shade700;
        labelKey = 'Pending';
        break;
      case 'CREATED':
        backgroundColor = Colors.blue.withOpacity(isDark ? 0.25 : 0.12);
        textColor = Colors.blue.shade700;
        labelKey = 'Created';
        break;
      case 'CANCELED':
      case 'CANCELLED':
        backgroundColor = Colors.red.withOpacity(isDark ? 0.25 : 0.12);
        textColor = Colors.red.shade700;
        labelKey = 'Cancelled';
        break;
      default:
        backgroundColor = cs.surfaceContainer;
        textColor = cs.onSurfaceVariant;
        labelKey = normalized;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        context.tr(labelKey),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
