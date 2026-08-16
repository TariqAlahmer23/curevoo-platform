// ignore_for_file: deprecated_member_use, library_private_types_in_public_api, unused_element, use_build_context_synchronously

import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:curevoo_doctor/models/doctor.dart';
import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:curevoo_doctor/providers/dashboard_summary_cubit.dart';
import 'package:curevoo_doctor/providers/doctor_cubit.dart';
import 'package:curevoo_doctor/providers/patients_cubit.dart';
import 'package:curevoo_doctor/providers/theme_cubit.dart';
import 'package:go_router/go_router.dart';

class Leftsidebar extends StatefulWidget {
  final Doctor? currentDoctor;
  final Widget child;

  const Leftsidebar({super.key, this.currentDoctor, required this.child});

  @override
  State<Leftsidebar> createState() => _LeftsidebarState();
}

class _LeftsidebarState extends State<Leftsidebar>
    with SingleTickerProviderStateMixin {
  bool _isSidebarExpanded = true;
  late AnimationController _hoverController;
  int _hoveredIndex = -1;

  // Medical-specific sidebar items with Profile and Treatment Plan added
  final List<SidebarItem> _sidebarItems = [
    const SidebarItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      title: 'Dashboard',
      path: '/dashboard',
    ),
    const SidebarItem(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
      title: 'Appointments',
      path: '/appointments',
    ),
    const SidebarItem(
      icon: Icons.people_outlined,
      activeIcon: Icons.people,
      title: 'Patients',
      path: '/patients',
    ),
    const SidebarItem(
      icon: Icons.receipt_long_rounded,
      activeIcon: Icons.receipt_long_rounded,
      title: 'Diagnosis',
      path: '/diagnosis',
    ),
    const SidebarItem(
      icon: Icons.medical_services_outlined,
      activeIcon: Icons.medical_services,
      title: 'Treatment Resistance',
      path: '/treatment-resistance',
    ),
    const SidebarItem(
      icon: Icons.biotech_outlined,
      activeIcon: Icons.biotech,
      title: 'Genomic Target Prioritization',
      path: '/genomic-target-prioritization',
    ),
    const SidebarItem(
      icon: Icons.access_time_rounded,
      activeIcon: Icons.access_time_filled_rounded,
      title: 'Schedule',
      path: '/schedule',
    ),
    const SidebarItem(
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment,
      title: 'Treatment Plan',
      path: '/treatment-plan',
    ),
    const SidebarItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      title: 'Profile',
      path: '/profile',
    ),
    const SidebarItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      title: 'Settings',
      path: '/settings',
    ),
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final doctorCubit = context.read<DoctorCubit>();
      doctorCubit.syncFromAuthDoctor(context.read<AuthCubit>().state.doctor);
      doctorCubit.loadProfile(forceRefresh: true);
      context.read<DashboardSummaryCubit>().loadSummary();
      context.read<PatientsCubit>().fetchConnectRequests();
    });
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isLargeScreen = MediaQuery.of(context).size.width >= 1024;
    final selectedIndex = _selectedIndexForPath(
      GoRouterState.of(context).uri.path,
    );
    final pendingBookingRequests = context.select(
      (DashboardSummaryCubit cubit) => cubit.state.pendingAppointments,
    );
    final pendingPatientConnectRequests = context.select(
      (PatientsCubit cubit) => cubit.state.pendingConnectRequestsCount,
    );

    return Scaffold(
      key: _scaffoldKey,
      appBar: isLargeScreen
          ? null
          : AppBar(
              title: Text(
                context.tr(_sidebarItems[selectedIndex].title),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.menu, color: theme.colorScheme.onPrimary),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Icon(
                      theme.brightness == Brightness.dark
                          ? Icons.light_mode
                          : Icons.dark_mode,
                      color: theme.colorScheme.onPrimary,
                    ),
                    onPressed: _toggleTheme,
                    tooltip: theme.brightness == Brightness.dark
                        ? context.tr('Light mode')
                        : context.tr('Dark mode'),
                  ),
                ),
              ],
            ),
      drawer: !isLargeScreen
          ? _buildMobileDrawer(
              theme,
              pendingBookingRequests,
              pendingPatientConnectRequests,
            )
          : null,
      body: isLargeScreen
          ? Row(
              children: [
                // Permanent collapsible sidebar for desktop
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: _isSidebarExpanded ? 280 : 70,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border(
                      right: BorderSide(
                        color: cs.outlineVariant.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withOpacity(
                          theme.brightness == Brightness.dark ? 0.2 : 0.08,
                        ),
                        blurRadius: 20,
                        offset: const Offset(8, 0),
                      ),
                    ],
                  ),
                  child: _buildDesktopSidebar(
                    theme,
                    isLargeScreen,
                    pendingBookingRequests,
                    pendingPatientConnectRequests,
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.surface,
                          theme.colorScheme.surfaceContainerLowest,
                        ],
                      ),
                    ),
                    child: widget.child,
                  ),
                ),
              ],
            )
          : Column(children: [Expanded(child: widget.child)]),
    );
  }

  Widget _buildDesktopSidebar(
    ThemeData theme,
    bool isLargeScreen,
    int pendingBookingRequests,
    int pendingPatientConnectRequests,
  ) {
    final cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.surface, cs.surfaceContainer.withOpacity(0.35)],
        ),
      ),
      child: Column(
        children: [
          _buildLogoSection(theme),
          Divider(height: 1, color: cs.outlineVariant.withOpacity(0.55)),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
              itemCount: _sidebarItems.length,
              itemBuilder: (context, index) {
                return MouseRegion(
                  onEnter: (_) => setState(() => _hoveredIndex = index),
                  onExit: (_) => setState(() => _hoveredIndex = -1),
                  child: _buildSidebarItem(
                    theme,
                    _sidebarItems[index],
                    index,
                    pendingBookingRequests: pendingBookingRequests,
                    pendingPatientConnectRequests:
                        pendingPatientConnectRequests,
                  ),
                );
              },
            ),
          ),
          _buildDoctorProfileSection(theme),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildMobileDrawer(
    ThemeData theme,
    int pendingBookingRequests,
    int pendingPatientConnectRequests,
  ) {
    final cs = theme.colorScheme;

    return Drawer(
      width: 280,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          _buildLogoSection(theme),
          Divider(height: 1, color: cs.outlineVariant.withOpacity(0.55)),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
              itemCount: _sidebarItems.length,
              itemBuilder: (context, index) {
                return _buildSidebarItem(
                  theme,
                  _sidebarItems[index],
                  index,
                  isMobile: true,
                  pendingBookingRequests: pendingBookingRequests,
                  pendingPatientConnectRequests:
                      pendingPatientConnectRequests,
                );
              },
            ),
          ),
          _buildDoctorProfileSection(theme),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLogoSection(ThemeData theme) {
    final cs = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final logoSize = _isSidebarExpanded ? 54.0 : 32.0;

    if (!_isSidebarExpanded && isDesktop) {
      return Container(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: logoSize,
              height: logoSize,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.secondary.withOpacity(0.22),
                    cs.primary.withOpacity(0.16),
                  ],
                ),
                border: Border.all(color: cs.primary.withOpacity(0.18)),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  "lib/images/curvoo.png",
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.medical_services,
                      color: cs.primary,
                      size: 20,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
              ),
              child: IconButton(
                icon: AnimatedRotation(
                  duration: const Duration(milliseconds: 300),
                  turns: 0.5,
                  child: Icon(
                    Icons.chevron_left,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 14,
                  ),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () {
                  setState(() {
                    _isSidebarExpanded = true;
                  });
                },
                tooltip: context.tr('Expand sidebar'),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool useExpandedHeader =
            _isSidebarExpanded && (!isDesktop || constraints.maxWidth >= 208);
        final bool isNarrowCompactDesktop =
            isDesktop && !useExpandedHeader && constraints.maxWidth < 74;
        final double compactHorizontalPadding = isNarrowCompactDesktop ? 6 : 8;
        final double effectiveLogoSize = useExpandedHeader
            ? logoSize
            : (isNarrowCompactDesktop ? 30 : 32);

        return Container(
          padding: EdgeInsets.fromLTRB(
            useExpandedHeader ? 14 : compactHorizontalPadding,
            16,
            useExpandedHeader ? 12 : compactHorizontalPadding,
            14,
          ),
          child: Row(
            mainAxisAlignment: useExpandedHeader
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: effectiveLogoSize,
                height: effectiveLogoSize,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    useExpandedHeader ? 18 : 14,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.secondary.withOpacity(0.22),
                      cs.primary.withOpacity(0.16),
                    ],
                  ),
                  border: Border.all(color: cs.primary.withOpacity(0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    useExpandedHeader ? 14 : 10,
                  ),
                  child: Image.asset(
                    "lib/images/curvoo.png",
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.medical_services,
                        color: cs.primary,
                        size: useExpandedHeader ? 26 : 20,
                      );
                    },
                  ),
                ),
              ),
              if (useExpandedHeader) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CureVoo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          overflow: TextOverflow.ellipsis,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.secondary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: cs.secondary.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          context.tr('Doctor'),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (isDesktop)
                if (!isNarrowCompactDesktop)
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    child: IconButton(
                      icon: AnimatedRotation(
                        duration: const Duration(milliseconds: 300),
                        turns: _isSidebarExpanded ? 0.0 : 0.5,
                        child: Icon(
                          Icons.chevron_left,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: useExpandedHeader ? 16 : 13,
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: useExpandedHeader ? 28 : 22,
                        minHeight: useExpandedHeader ? 28 : 22,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSidebarExpanded = !_isSidebarExpanded;
                        });
                      },
                      tooltip: _isSidebarExpanded
                          ? context.tr('Collapse sidebar')
                          : context.tr('Expand sidebar'),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebarItem(
    ThemeData theme,
    SidebarItem item,
    int index, {
    bool isMobile = false,
    required int pendingBookingRequests,
    required int pendingPatientConnectRequests,
  }) {
    final selectedIndex = _selectedIndexForPath(
      GoRouterState.of(context).uri.path,
    );
    final bool isSelected = selectedIndex == index;
    final bool showExpanded = isMobile ? true : _isSidebarExpanded;
    final bool isHovered = _hoveredIndex == index && !isSelected && !isMobile;
    final cs = theme.colorScheme;
    final isAppointmentsItem = item.path == '/appointments';
    final isPatientsItem = item.path == '/patients';
    final shouldShowBookingCount =
        isAppointmentsItem && pendingBookingRequests > 0;
    final shouldShowPatientsCount =
        isPatientsItem && pendingPatientConnectRequests > 0;
    final shouldShowCount = shouldShowBookingCount || shouldShowPatientsCount;
    final notificationCount = shouldShowBookingCount
        ? pendingBookingRequests
        : pendingPatientConnectRequests;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool effectiveShowExpanded =
            showExpanded && constraints.maxWidth >= 170;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Tooltip(
            message: !effectiveShowExpanded ? context.tr(item.title) : '',
            waitDuration: const Duration(milliseconds: 500),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (isMobile) {
                    Navigator.pop(context);
                  }
                  context.go(item.path);
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: effectiveShowExpanded ? 14 : 0,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primary.withOpacity(0.12)
                        : isHovered
                        ? cs.primary.withOpacity(0.07)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected
                        ? Border.all(
                            color: cs.primary.withOpacity(0.28),
                            width: 1,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: cs.primary.withOpacity(0.12),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: effectiveShowExpanded
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: effectiveShowExpanded ? null : 44,
                        height: effectiveShowExpanded ? null : 44,
                        decoration: effectiveShowExpanded
                            ? null
                            : BoxDecoration(
                                color: isSelected
                                    ? cs.primary.withOpacity(0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                        transform: Matrix4.identity()
                          ..scale(isSelected ? 1.05 : 1.0),
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              isSelected ? item.activeIcon : item.icon,
                              color: isSelected
                                  ? cs.primary
                                  : isHovered
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                              size: 22,
                            ),
                            if (!effectiveShowExpanded && shouldShowCount)
                              Positioned(
                                right: -6,
                                top: -8,
                                child: _buildBookingRequestsBadge(
                                  theme: theme,
                                  count: notificationCount,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (effectiveShowExpanded) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.tr(item.title),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              color: isSelected
                                  ? cs.primary
                                  : isHovered
                                  ? cs.primary
                                  : cs.onSurface,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (effectiveShowExpanded && shouldShowCount) ...[
                          _buildBookingRequestsBadge(
                            theme: theme,
                            count: notificationCount,
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (isSelected)
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: cs.primary,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookingRequestsBadge({
    required ThemeData theme,
    required int count,
  }) {
    final cs = theme.colorScheme;
    final displayCount = count > 99 ? '99+' : '$count';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      constraints: const BoxConstraints(minWidth: 22),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.surface, width: 1),
      ),
      child: Text(
        displayCount,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: cs.onError,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildDoctorProfileSection(ThemeData theme) {
    final doctor =
        context.select((DoctorCubit cubit) => cubit.state.doctor) ??
        context.select((AuthCubit cubit) => cubit.state.doctor) ??
        widget.currentDoctor;
    final doctorName = doctor?.name ?? 'Dr. User';
    final doctorSpecialty =
        doctor?.profile.specialization ?? 'General Physician';
    final isDarkMode = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    final showExpanded = MediaQuery.of(context).size.width >= 1024
        ? _isSidebarExpanded
        : true;

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surfaceContainerHigh.withOpacity(0.88),
            cs.surfaceContainerHighest.withOpacity(0.74),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.55),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(
              theme.brightness == Brightness.dark ? 0.18 : 0.06,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool effectiveShowExpanded =
              showExpanded && constraints.maxWidth >= 210;
          return effectiveShowExpanded
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Animated Doctor Avatar
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [cs.primary, cs.secondary],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withOpacity(0.24),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          doctorName.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: cs.onPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctorName.split(' ').first,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: cs.onSurface,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: cs.primary.withOpacity(0.16),
                              ),
                            ),
                            child: Text(
                              doctorSpecialty,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: cs.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withOpacity(
                          0.1,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.error.withOpacity(0.14)),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.logout_rounded,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () => _handleLogout(context),
                        tooltip: context.tr('Logout'),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                      child: IconButton(
                        icon: AnimatedRotation(
                          duration: const Duration(milliseconds: 300),
                          turns: isDarkMode ? 0.5 : 0.0,
                          child: Icon(
                            isDarkMode
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: _toggleTheme,
                        tooltip: context.tr('Toggle theme'),
                      ),
                    ),
                  ],
                )
              : Center(
                  // Collapsed view - only show avatar with tooltips
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: doctorName,
                        waitDuration: const Duration(milliseconds: 500),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.secondary,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.3,
                                ),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              doctorName.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Tooltip(
                        message: context.tr('Logout'),
                        waitDuration: const Duration(milliseconds: 500),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer.withOpacity(
                              0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.logout_rounded,
                              size: 16,
                              color: theme.colorScheme.error,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: () => _handleLogout(context),
                            tooltip: context.tr('Logout'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Tooltip(
                        message: context.tr('Toggle theme'),
                        waitDuration: const Duration(milliseconds: 500),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: AnimatedRotation(
                              duration: const Duration(milliseconds: 300),
                              turns: isDarkMode ? 0.5 : 0.0,
                              child: Icon(
                                isDarkMode
                                    ? Icons.light_mode_rounded
                                    : Icons.dark_mode_rounded,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: _toggleTheme,
                            tooltip: context.tr('Toggle theme'),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
        },
      ),
    );
  }

  int _selectedIndexForPath(String path) {
    final index = _sidebarItems.indexWhere((item) => item.path == path);
    return index == -1 ? 0 : index;
  }

  void _toggleTheme() {
    context.read<ThemeCubit>().toggleTheme();
  }

  Future<void> _handleLogout(BuildContext context) async {
    await context.read<AuthCubit>().logout();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Logged out successfully')),
          behavior: SnackBarBehavior.floating,
          width: 400,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }
}

// Supporting Class
class SidebarItem {
  final IconData icon;
  final IconData activeIcon;
  final String title;
  final String path;

  const SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.title,
    required this.path,
  });
}

class SidebarRoute {
  const SidebarRoute._();

  static const List<SidebarItem> items = [
    SidebarItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      title: 'Dashboard',
      path: '/dashboard',
    ),
    SidebarItem(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
      title: 'Appointments',
      path: '/appointments',
    ),
    SidebarItem(
      icon: Icons.people_outlined,
      activeIcon: Icons.people,
      title: 'Patients',
      path: '/patients',
    ),
    SidebarItem(
      icon: Icons.receipt_long_rounded,
      activeIcon: Icons.receipt_long_rounded,
      title: 'Diagnosis',
      path: '/diagnosis',
    ),
    SidebarItem(
      icon: Icons.medical_services_outlined,
      activeIcon: Icons.medical_services,
      title: 'Treatment Resistance',
      path: '/treatment-resistance',
    ),
    SidebarItem(
      icon: Icons.biotech_outlined,
      activeIcon: Icons.biotech,
      title: 'Genomic Target Prioritization',
      path: '/genomic-target-prioritization',
    ),
    SidebarItem(
      icon: Icons.access_time_rounded,
      activeIcon: Icons.access_time_filled_rounded,
      title: 'Schedule',
      path: '/schedule',
    ),
    SidebarItem(
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment,
      title: 'Treatment Plan',
      path: '/treatment-plan',
    ),
    SidebarItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      title: 'Profile',
      path: '/profile',
    ),
    SidebarItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      title: 'Settings',
      path: '/settings',
    ),
  ];
}
