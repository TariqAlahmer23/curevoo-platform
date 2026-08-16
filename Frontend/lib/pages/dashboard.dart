// ignore_for_file: deprecated_member_use

import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:curevoo_doctor/models/patient.dart';
import 'package:curevoo_doctor/providers/dashboard_summary_cubit.dart';
import 'package:curevoo_doctor/providers/doctor_cubit.dart';
import 'package:curevoo_doctor/providers/patient_appointments_cubit.dart';
import 'package:curevoo_doctor/providers/patients_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.onNavigateToSidebarIndex});

  final ValueChanged<int>? onNavigateToSidebarIndex;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DashboardSummaryCubit>().loadSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final doctorName =
        context.select(
          (DoctorCubit cubit) => cubit.state.doctor?.name.trim(),
        ) ??
        '';
    final welcomeName = doctorName.isEmpty ? context.tr('Doctor') : doctorName;

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
                  _DashboardHeader(welcomeName: welcomeName),
                  const SizedBox(height: 24),
                  BlocBuilder<DashboardSummaryCubit, DashboardSummaryState>(
                    builder: (context, summaryState) {
                      final latestPrediction = _formatLatestPrediction(
                        summaryState.latestAiPredictionAt,
                      );
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: _getCrossAxisCount(context),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.5,
                        children: [
                          _StatCard(
                            title: context.tr('Total Patients'),
                            value: '${summaryState.totalPatients}',
                            icon: Icons.people,
                            accent: cs.primary,
                          ),
                          _StatCard(
                            title: context.tr('Upcoming Appointments'),
                            value: '${summaryState.upcomingAppointments}',
                            icon: Icons.calendar_today,
                            accent: cs.secondary,
                          ),
                          _StatCard(
                            title: context.tr('Pending Appointments'),
                            value: '${summaryState.pendingAppointments}',
                            icon: Icons.pending_actions_outlined,
                            accent: cs.tertiary,
                          ),
                          _StatCard(
                            title: context.tr('Latest AI Prediction'),
                            value: latestPrediction,
                            icon: Icons.psychology_outlined,
                            accent: const Color(0xFF3438F2),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 800) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _AppointmentsCard(
                                onViewAllAppointments: () =>
                                    widget.onNavigateToSidebarIndex?.call(1),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _PatientsCard(
                                onViewAllPatients: () =>
                                    widget.onNavigateToSidebarIndex?.call(2),
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          _AppointmentsCard(
                            onViewAllAppointments: () =>
                                widget.onNavigateToSidebarIndex?.call(1),
                          ),
                          const SizedBox(height: 24),
                          _PatientsCard(
                            onViewAllPatients: () =>
                                widget.onNavigateToSidebarIndex?.call(2),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 600) return 2;
    return 1;
  }

  String _formatLatestPrediction(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty || rawValue == '-') {
      return '-';
    }
    final parsed = DateTime.tryParse(rawValue);
    if (parsed == null) return rawValue;
    final y = parsed.year.toString().padLeft(4, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.welcomeName});

  final String welcomeName;

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
          final compact = constraints.maxWidth < 700;
          final title = Column(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Dashboard Overview'),
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontSize: compact ? 26 : 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${context.tr('Welcome back, Dr.')} $welcomeName! ${context.tr("Here's what's happening today.")}',
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          );

          final icon = Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Icon(
              Icons.dashboard_outlined,
              color: Colors.white,
              size: 30,
            ),
          );

          if (compact) {
            return Column(children: [icon, const SizedBox(height: 12), title]);
          }

          return Row(
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(child: title),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardBackground = Color.alphaBlend(
      accent.withOpacity(isDark ? 0.22 : 0.08),
      cs.surface,
    );

    return Semantics(
      label: '$title: $value',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(isDark ? 0.22 : 0.18),
              blurRadius: 30,
              spreadRadius: -8,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(
                theme.brightness == Brightness.dark ? 0.2 : 0.05,
              ),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.alphaBlend(
                        accent.withOpacity(isDark ? 0.34 : 0.2),
                        cs.surface,
                      ),
                      cardBackground,
                      Color.alphaBlend(
                        accent.withOpacity(isDark ? 0.18 : 0.1),
                        cs.surface,
                      ),
                    ],
                  ),
                  border: Border.all(
                    color: Color.alphaBlend(
                      accent.withOpacity(isDark ? 0.35 : 0.24),
                      cs.outlineVariant,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -24,
                left: -10,
                right: 36,
                child: IgnorePointer(
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(isDark ? 0.16 : 0.28),
                          Colors.white.withOpacity(isDark ? 0.06 : 0.12),
                          Colors.white.withOpacity(0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -32,
                top: 18,
                child: IgnorePointer(
                  child: Transform.rotate(
                    angle: -0.7,
                    child: Container(
                      width: 110,
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0),
                            Colors.white.withOpacity(isDark ? 0.08 : 0.18),
                            Colors.white.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1.2,
                  color: Colors.white.withOpacity(isDark ? 0.18 : 0.45),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(isDark ? 0.14 : 0.3),
                            accent.withOpacity(0.16),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(
                            isDark ? 0.12 : 0.35,
                          ),
                        ),
                      ),
                      child: Icon(icon, size: 24, color: accent),
                    ),
                    const Spacer(),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
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
}

class _AppointmentsCard extends StatefulWidget {
  const _AppointmentsCard({required this.onViewAllAppointments});

  final VoidCallback onViewAllAppointments;

  @override
  State<_AppointmentsCard> createState() => _AppointmentsCardState();
}

class _AppointmentsCardState extends State<_AppointmentsCard> {
  @override
  void initState() {
    super.initState();
    context.read<PatientAppointmentsCubit>().loadAppointments(
      filter: 'UPCOMING',
      forceRefresh: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return BlocBuilder<PatientAppointmentsCubit, PatientAppointmentsState>(
      builder: (context, state) {
        final upcoming = state.appointments.take(5).toList(growable: false);

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
              _CardHeaderWithAction(
                title: context.tr('Upcoming Appointments'),
                icon: Icons.event_available_outlined,
                actionLabel: context.tr('View all'),
                onActionTap: widget.onViewAllAppointments,
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : upcoming.isEmpty
                    ? Center(
                        child: Text(
                          context.tr('No appointments found'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Column(
                        children: upcoming.map((item) {
                          final confirmed = item.status == 'CONFIRMED';
                          final timeLabel =
                              '${item.appointmentDate} ${item.appointmentTime}';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainer.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: cs.outlineVariant.withOpacity(0.55),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: cs.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.schedule,
                                    color: cs.primary,
                                    size: 21,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        timeLabel,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: cs.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.patientName,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      Text(
                                        item.reason,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (confirmed ? cs.secondary : cs.tertiary)
                                            .withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    item.status,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: confirmed
                                          ? cs.secondary
                                          : cs.tertiary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PatientsCard extends StatefulWidget {
  const _PatientsCard({required this.onViewAllPatients});

  final VoidCallback onViewAllPatients;

  @override
  State<_PatientsCard> createState() => _PatientsCardState();
}

class _PatientsCardState extends State<_PatientsCard> {
  List<PatientSummary> _recentPatients = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecentPatients();
  }

  Future<void> _loadRecentPatients() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final patientsCubit = context.read<PatientsCubit>();
    final patients = await patientsCubit.fetchPatients();
    if (!mounted) return;

    setState(() {
      _recentPatients = patients.take(5).toList(growable: false);
      _isLoading = false;
      _errorMessage = patientsCubit.state.errorMessage;
    });
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
          _CardHeaderWithAction(
            title: context.tr('Recent Patients'),
            icon: Icons.person_search_outlined,
            actionLabel: context.tr('View all'),
            onActionTap: widget.onViewAllPatients,
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_recentPatients.isEmpty
                      ? Text(
                          _errorMessage?.trim().isNotEmpty == true
                              ? _errorMessage!
                              : context.tr('No appointments found'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        )
                      : Column(
                          children: _recentPatients.map((patient) {
                            final name = patient.fullName.trim();
                            final firstLetter = name.isEmpty
                                ? '?'
                                : name[0].toUpperCase();
                            final phone = patient.phone.trim().isEmpty
                                ? context.tr('No phone')
                                : patient.phone;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainer.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: cs.outlineVariant.withOpacity(0.55),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [cs.primary, cs.secondary],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        firstLetter,
                                        style: TextStyle(
                                          color: cs.onPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.person_outline_rounded,
                                              size: 15,
                                              color: cs.primary,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                patient.fullName,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.call_outlined,
                                              size: 14,
                                              color: cs.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                phone,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          cs.onSurfaceVariant,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.cake_outlined,
                                          size: 14,
                                          color: cs.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${patient.age}${context.tr('y')}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: cs.primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        )),
          ),
        ],
      ),
    );
  }
}

class _CardHeaderWithAction extends StatelessWidget {
  const _CardHeaderWithAction({
    required this.title,
    required this.icon,
    required this.actionLabel,
    required this.onActionTap,
  });

  final String title;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainer.withOpacity(0.56),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
            child: Icon(icon, color: cs.primary, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(onPressed: onActionTap, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
