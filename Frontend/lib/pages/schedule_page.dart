// ignore_for_file: deprecated_member_use, unnecessary_to_list_in_spreads

import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:curevoo_doctor/models/create_patient_appointment_request.dart';
import 'package:curevoo_doctor/models/doctor_available_time.dart';
import 'package:curevoo_doctor/models/doctor_booked_slot.dart';
import 'package:curevoo_doctor/pages/appointment_page.dart';
import 'package:curevoo_doctor/providers/available_times_cubit.dart';
import 'package:curevoo_doctor/providers/patient_appointments_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late DateTime _weekStartDate;
  final ScrollController _scheduleHorizontalController = ScrollController();

  static const List<int> _orderedDays = [1, 2, 3, 4, 5, 6, 0];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStartDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    context.read<AvailableTimesCubit>().loadAvailableTimes();
    _loadBookedSlotsForCurrentWeek();
  }

  @override
  void dispose() {
    _scheduleHorizontalController.dispose();
    super.dispose();
  }

  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isToday(DateTime date) {
    final today = _startOfDay(DateTime.now());
    return _startOfDay(date) == today;
  }

  bool _isPastDay(DateTime date) {
    final today = _startOfDay(DateTime.now());
    return _startOfDay(date).isBefore(today);
  }

  Future<void> _onScheduleCellPressed(int dayOfWeek, String time) async {
    final selectedDate = _dateForDay(dayOfWeek);
    if (_isPastDay(selectedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('You cannot add appointments to past days')),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await showCreateAppointmentDialog(
      context,
      initialDate: selectedDate,
      initialTime: time,
      onSubmit: (result) async {
        final appointmentsCubit = context.read<PatientAppointmentsCubit>();
        final request = CreatePatientAppointmentRequest(
          patientId: result.patientId,
          patientType: result.patientType,
          appointmentDate: DateFormat('yyyy-MM-dd').format(result.date),
          appointmentTime: _to24HourTime(result.time),
          reason: _reasonFromTypeKey(result.typeKey),
          notes: result.notes,
        );

        final created = await appointmentsCubit.createAppointmentRequest(
          request,
        );
        if (created) return null;

        return appointmentsCubit.state.errorMessage ??
            'Failed to create appointment request.';
      },
    );

    if (!mounted || result == null) return;

    await _loadBookedSlotsForCurrentWeek();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('Appointment created successfully')),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  DateTime _dateForDay(int dayOfWeek) {
    final offsetFromMonday = dayOfWeek == 0 ? 6 : dayOfWeek - 1;
    return _weekStartDate.add(Duration(days: offsetFromMonday));
  }

  void _goToPreviousWeek() {
    setState(() {
      _weekStartDate = _weekStartDate.subtract(const Duration(days: 7));
    });
    _loadBookedSlotsForCurrentWeek();
  }

  void _goToNextWeek() {
    setState(() {
      _weekStartDate = _weekStartDate.add(const Duration(days: 7));
    });
    _loadBookedSlotsForCurrentWeek();
  }

  String _weekRangeLabel(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final weekEndDate = _weekStartDate.add(const Duration(days: 6));
    final startLabel = DateFormat('MMM d', localeTag).format(_weekStartDate);
    final endLabel = DateFormat('MMM d, yyyy', localeTag).format(weekEndDate);
    return '$startLabel - $endLabel';
  }

  String _appointmentTypeLabel(BuildContext context, String typeKey) {
    switch (typeKey) {
      case 'checkup':
        return context.tr('Check-up');
      case 'followup':
        return context.tr('Follow-up');
      case 'consultation':
        return context.tr('Consultation');
      case 'vaccination':
        return context.tr('Vaccination');
      case 'emergency':
        return context.tr('Emergency');
      case 'routine':
        return context.tr('Routine');
      default:
        return typeKey;
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

  String _typeKeyFromReason(String? reason) {
    final normalized = reason?.trim().toLowerCase() ?? '';
    switch (normalized) {
      case 'check-up':
      case 'check up':
      case 'checkup':
        return 'checkup';
      case 'follow-up':
      case 'follow up':
      case 'followup':
        return 'followup';
      case 'consultation':
        return 'consultation';
      case 'vaccination':
        return 'vaccination';
      case 'emergency':
        return 'emergency';
      case 'routine':
        return 'routine';
      default:
        return 'consultation';
    }
  }

  String _to24HourTime(String displayTime) {
    final parsed = DateFormat('hh:mm a').parse(displayTime);
    return DateFormat('HH:mm').format(parsed);
  }

  String _toIsoDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _loadBookedSlotsForCurrentWeek() {
    final from = _toIsoDate(_weekStartDate);
    final to = _toIsoDate(_weekStartDate.add(const Duration(days: 6)));
    return context.read<PatientAppointmentsCubit>().loadBookedSlotsForRange(
      fromDate: from,
      toDate: to,
    );
  }

  int? _parseTimeToMinutes(String? value) {
    if (value == null) return null;
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour * 60) + minute;
  }

  String _formatMinutesToDisplay(int minutes) {
    final hour = (minutes ~/ 60) % 24;
    final minute = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String _formatMinutesTo24h(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  List<int> _buildTimeSlots(List<DoctorAvailableTime> availableTimes) {
    final activeTimes = availableTimes.where((item) => item.isOn).toList();
    if (activeTimes.isEmpty) {
      return List<int>.generate(9, (index) => 9 * 60 + (index * 60));
    }

    int? minFrom;
    int? maxTo;
    for (final day in activeTimes) {
      final from = _parseTimeToMinutes(day.from);
      final to = _parseTimeToMinutes(day.to);
      if (from == null || to == null || from >= to) continue;
      minFrom = minFrom == null ? from : (from < minFrom ? from : minFrom);
      maxTo = maxTo == null ? to : (to > maxTo ? to : maxTo);
    }

    if (minFrom == null || maxTo == null || minFrom >= maxTo) {
      return List<int>.generate(9, (index) => 9 * 60 + (index * 60));
    }

    final slots = <int>[];
    for (int t = minFrom; t < maxTo; t += 60) {
      slots.add(t);
    }
    return slots;
  }

  bool _isSlotAvailable(DoctorAvailableTime? daySchedule, int slotMinutes) {
    if (daySchedule == null || !daySchedule.isOn) return false;
    final from = _parseTimeToMinutes(daySchedule.from);
    final to = _parseTimeToMinutes(daySchedule.to);
    if (from == null || to == null || from >= to) return false;
    return slotMinutes >= from && slotMinutes < to;
  }

  bool _isSlotBooked(
    DateTime dayDate,
    int slotMinutes,
    Set<String> bookedSlotKeys,
  ) {
    final key = '${_toIsoDate(dayDate)}|${_formatMinutesTo24h(slotMinutes)}';
    return bookedSlotKeys.contains(key);
  }

  Set<String> _buildBookedSlotKeySet(List<DoctorBookedSlot> bookedSlots) {
    final keys = <String>{};
    for (final slot in bookedSlots) {
      final date = slot.appointmentDate.trim();
      final time = slot.appointmentTime.trim();
      if (date.isEmpty || time.isEmpty) continue;
      final normalizedTime = time.length >= 5 ? time.substring(0, 5) : time;
      keys.add('$date|$normalizedTime');
    }
    return keys;
  }

  Map<String, DoctorBookedSlot> _buildBookedSlotMap(
    List<DoctorBookedSlot> bookedSlots,
  ) {
    final map = <String, DoctorBookedSlot>{};
    for (final slot in bookedSlots) {
      final date = slot.appointmentDate.trim();
      final time = slot.appointmentTime.trim();
      if (date.isEmpty || time.isEmpty) continue;
      final normalizedTime = time.length >= 5 ? time.substring(0, 5) : time;
      map['$date|$normalizedTime'] = slot;
    }
    return map;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  _buildWeekNavigatorCard(context),
                  const SizedBox(height: 24),
                  _buildScheduleCard(context),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final icon = Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Icon(
              Icons.calendar_today_outlined,
              color: Colors.white,
              size: 30,
            ),
          );
          final textBlock = Column(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Weekly Schedule'),
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontSize: compact ? 26 : 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('View and manage your weekly appointments'),
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              children: [icon, const SizedBox(height: 12), textBlock],
            );
          }

          return Row(
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(child: textBlock),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWeekNavigatorCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.2 : 0.05,
            ),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;
            final info = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.date_range, size: 20, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Current Week'),
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _weekRangeLabel(context),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ],
            );
            final actions = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNavButton(context, Icons.chevron_left, _goToPreviousWeek),
                const SizedBox(width: 8),
                _buildNavButton(context, Icons.chevron_right, _goToNextWeek),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [info, const SizedBox(height: 12), actions],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [info, actions],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Icon(icon, size: 24, color: cs.onSurface),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return BlocBuilder<PatientAppointmentsCubit, PatientAppointmentsState>(
      builder: (context, appointmentsState) {
        return BlocBuilder<AvailableTimesCubit, AvailableTimesState>(
          builder: (context, state) {
            final times = state.times;
            final timeSlots = _buildTimeSlots(times);
            final availableByDay = <int, DoctorAvailableTime>{
              for (final day in times) day.dayOfWeek: day,
            };
            final bookedSlotKeys = _buildBookedSlotKeySet(
              appointmentsState.bookedSlots,
            );
            final bookedSlotMap = _buildBookedSlotMap(
              appointmentsState.bookedSlots,
            );

            return Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cs.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 20,
                    color: Colors.black.withOpacity(
                      theme.brightness == Brightness.dark ? 0.2 : 0.05,
                    ),
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: cs.outlineVariant, width: 1),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 650;
                        final isLoading =
                            state.isLoading ||
                            appointmentsState.isLoadingBookedSlots;

                        final hintChip = Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.tr('Tap any cell to add appointment'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );

                        if (isNarrow) {
                          return Column(
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
                                    child: Icon(
                                      Icons.schedule,
                                      size: 20,
                                      color: cs.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      context.tr('Appointment Schedule'),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSurface,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                  if (isLoading)
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: cs.primary,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              hintChip,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.schedule,
                                size: 20,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              context.tr('Appointment Schedule'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const Spacer(),
                            if (isLoading)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.primary,
                                ),
                              ),
                            const SizedBox(width: 8),
                            hintChip,
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Scrollbar(
                      controller: _scheduleHorizontalController,
                      thumbVisibility: true,
                      interactive: true,
                      child: SingleChildScrollView(
                        controller: _scheduleHorizontalController,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTimeColumn(context, timeSlots),
                            ..._orderedDays.map(
                              (dayOfWeek) => _buildDayColumn(
                                context,
                                dayOfWeek,
                                availableByDay[dayOfWeek],
                                timeSlots,
                                bookedSlotKeys,
                                bookedSlotMap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimeColumn(BuildContext context, List<int> timeSlots) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: 100,
          height: 60,
          margin: const EdgeInsets.all(4),
          alignment: Alignment.center,
          child: Text(
            context.tr('Time'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        ...timeSlots.asMap().entries.map((entry) {
          final index = entry.key;
          final time = _formatMinutesToDisplay(entry.value);
          return Container(
            width: 100,
            height: 90,
            margin: const EdgeInsets.all(4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: index % 2 == 0
                  ? cs.surfaceContainerHighest.withOpacity(0.3)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              time,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildDayColumn(
    BuildContext context,
    int dayOfWeek,
    DoctorAvailableTime? daySchedule,
    List<int> timeSlots,
    Set<String> bookedSlotKeys,
    Map<String, DoctorBookedSlot> bookedSlotMap,
  ) {
    final cs = Theme.of(context).colorScheme;
    final dayDate = _dateForDay(dayOfWeek);
    final dayLabel = DateFormat(
      'EEE',
      Localizations.localeOf(context).toLanguageTag(),
    ).format(dayDate);
    final isToday = _isToday(dayDate);
    final isPastDay = _isPastDay(dayDate);
    final isOffDay =
        !_isSlotAvailable(
          daySchedule,
          timeSlots.isNotEmpty ? timeSlots.first : 0,
        ) &&
        (daySchedule == null || !daySchedule.isOn);

    return Column(
      children: [
        Container(
          width: 150,
          height: 60,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: isToday
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primaryContainer,
                      cs.primaryContainer.withOpacity(0.7),
                    ],
                  )
                : null,
            color: isToday ? null : cs.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isToday ? cs.primary : cs.outlineVariant,
              width: isToday ? 2 : 1,
            ),
            boxShadow: isToday
                ? [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dayLabel,
                style: TextStyle(
                  color: isToday ? cs.primary : cs.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM d').format(dayDate),
                style: TextStyle(
                  color: isToday ? cs.primary : cs.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        ...timeSlots.map((slotMinutes) {
          final time = _formatMinutesToDisplay(slotMinutes);
          final isUnavailable = !_isSlotAvailable(daySchedule, slotMinutes);
          final isBooked = _isSlotBooked(dayDate, slotMinutes, bookedSlotKeys);
          final slotKey =
              '${_toIsoDate(dayDate)}|${_formatMinutesTo24h(slotMinutes)}';
          final bookedSlot = bookedSlotMap[slotKey];
          final appointment = isBooked
              ? <String, String>{
                  'time': time,
                  'patient': bookedSlot?.patientName ?? context.tr('Booked'),
                  'typeKey': _typeKeyFromReason(bookedSlot?.reason),
                }
              : null;
          return ScheduleCell(
            appointment: appointment,
            displayTypeBuilder: (typeKey) =>
                _appointmentTypeLabel(context, typeKey),
            onTap: () => _onScheduleCellPressed(dayOfWeek, time),
            isPastDay: isPastDay,
            isUnavailable: isUnavailable || isOffDay || isBooked,
          );
        }).toList(),
      ],
    );
  }
}

class ScheduleCell extends StatelessWidget {
  final Map<String, String>? appointment;
  final VoidCallback onTap;
  final String Function(String typeKey) displayTypeBuilder;
  final bool isPastDay;
  final bool isUnavailable;

  const ScheduleCell({
    super.key,
    this.appointment,
    required this.onTap,
    required this.displayTypeBuilder,
    this.isPastDay = false,
    this.isUnavailable = false,
  });

  Color _getTypeColor(BuildContext context, String typeKey, ColorScheme cs) {
    switch (typeKey) {
      case 'checkup':
        return cs.primary;
      case 'followup':
        return cs.secondary;
      case 'consultation':
        return Colors.purple.shade400;
      case 'vaccination':
        return Colors.green.shade600;
      case 'emergency':
        return cs.error;
      case 'routine':
        return Colors.orange.shade600;
      default:
        return cs.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasData = appointment != null && appointment!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (isPastDay || isUnavailable) ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 150,
            height: 90,
            decoration: BoxDecoration(
              gradient: hasData && !isPastDay
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getTypeColor(
                          context,
                          appointment!['typeKey'] ?? '',
                          cs,
                        ).withOpacity(0.12),
                        _getTypeColor(
                          context,
                          appointment!['typeKey'] ?? '',
                          cs,
                        ).withOpacity(0.06),
                      ],
                    )
                  : null,
              color: hasData && !isPastDay
                  ? null
                  : ((isPastDay || isUnavailable)
                        ? cs.surfaceContainerHighest.withOpacity(0.3)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasData && !isPastDay
                    ? _getTypeColor(
                        context,
                        appointment!['typeKey'] ?? '',
                        cs,
                      ).withOpacity(0.5)
                    : cs.outlineVariant,
                width: hasData && !isPastDay ? 2 : 1.5,
              ),
              boxShadow: hasData && !isPastDay
                  ? [
                      BoxShadow(
                        color: _getTypeColor(
                          context,
                          appointment!['typeKey'] ?? '',
                          cs,
                        ).withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: hasData
                ? Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _getTypeColor(
                                      context,
                                      appointment!['typeKey'] ?? '',
                                      cs,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    appointment!['patient'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isPastDay
                                          ? cs.onSurfaceVariant
                                          : cs.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _getTypeColor(
                                  context,
                                  appointment!['typeKey'] ?? '',
                                  cs,
                                ).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                displayTypeBuilder(
                                  appointment!['typeKey'] ?? '',
                                ),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _getTypeColor(
                                    context,
                                    appointment!['typeKey'] ?? '',
                                    cs,
                                  ),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isPastDay)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.lock_outline,
                                size: 20,
                                color: cs.onSurfaceVariant.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : ((isPastDay || isUnavailable)
                      ? Center(
                          child: Icon(
                            isUnavailable
                                ? Icons.bedtime_outlined
                                : Icons.block_outlined,
                            size: 24,
                            color: cs.onSurfaceVariant.withOpacity(0.3),
                          ),
                        )
                      : Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.add, size: 22, color: cs.primary),
                          ),
                        )),
          ),
        ),
      ),
    );
  }
}
