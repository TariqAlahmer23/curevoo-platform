// ignore_for_file: use_super_parameters

import 'dart:async';

import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:curevoo_doctor/pages/appointment_page.dart';
import 'package:curevoo_doctor/pages/dashboard.dart';
import 'package:curevoo_doctor/pages/diagnosis_page.dart';
import 'package:curevoo_doctor/pages/genomic_target_prioritization.dart';
import 'package:curevoo_doctor/pages/leftsidebar.dart';
import 'package:curevoo_doctor/pages/login.dart';
import 'package:curevoo_doctor/pages/patients_page.dart';
import 'package:curevoo_doctor/pages/profile_page.dart';
import 'package:curevoo_doctor/pages/schedule_page.dart';
import 'package:curevoo_doctor/pages/setting_page.dart';
import 'package:curevoo_doctor/pages/signup.dart';
import 'package:curevoo_doctor/pages/treatment_plan_screen.dart';
import 'package:curevoo_doctor/pages/treatment_resistance.dart';
import 'package:curevoo_doctor/providers/available_times_cubit.dart';
import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:curevoo_doctor/providers/doctor_cubit.dart';
import 'package:curevoo_doctor/providers/dashboard_summary_cubit.dart';
import 'package:curevoo_doctor/providers/genomic_target_prioritization_cubit.dart';
import 'package:curevoo_doctor/providers/language_cubit.dart';
import 'package:curevoo_doctor/providers/medical_history_cubit.dart';
import 'package:curevoo_doctor/providers/patient_appointments_cubit.dart';
import 'package:curevoo_doctor/providers/patients_cubit.dart';
import 'package:curevoo_doctor/providers/treatment_plan_cubit.dart';
import 'package:curevoo_doctor/providers/treatment_resistance_cubit.dart';
import 'package:curevoo_doctor/providers/theme_cubit.dart';
import 'package:curevoo_doctor/providers/theme_style_cubit.dart';
import 'package:curevoo_doctor/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final themeCubit = await ThemeCubit.create();
  final themeStyleCubit = await ThemeStyleCubit.create();
  final languageCubit = await LanguageCubit.create();
  final authCubit = await AuthCubit.create();
  final availableTimesCubit = AvailableTimesCubit.create(authCubit: authCubit);
  final doctorCubit = DoctorCubit.create(authCubit: authCubit);
  final dashboardSummaryCubit = DashboardSummaryCubit.create(
    authCubit: authCubit,
  );
  final patientAppointmentsCubit = await PatientAppointmentsCubit.create(
    authCubit: authCubit,
  );
  final patientsCubit = PatientsCubit.create(authCubit: authCubit);
  final medicalHistoryCubit = MedicalHistoryCubit.create(authCubit: authCubit);
  final treatmentPlanCubit = TreatmentPlanCubit.create(authCubit: authCubit);
  final treatmentResistanceCubit = TreatmentResistanceCubit.create(
    authCubit: authCubit,
  );
  final genomicTargetPrioritizationCubit =
      GenomicTargetPrioritizationCubit.create(authCubit: authCubit);

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: themeCubit),
        BlocProvider.value(value: themeStyleCubit),
        BlocProvider.value(value: languageCubit),
        BlocProvider.value(value: authCubit),
        BlocProvider.value(value: availableTimesCubit),
        BlocProvider.value(value: doctorCubit),
        BlocProvider.value(value: dashboardSummaryCubit),
        BlocProvider.value(value: patientAppointmentsCubit),
        BlocProvider.value(value: patientsCubit),
        BlocProvider.value(value: medicalHistoryCubit),
        BlocProvider.value(value: treatmentPlanCubit),
        BlocProvider.value(value: treatmentResistanceCubit),
        BlocProvider.value(value: genomicTargetPrioritizationCubit),
      ],
      child: const DoctorInfoApp(),
    ),
  );
}

class DoctorInfoApp extends StatefulWidget {
  const DoctorInfoApp({super.key});

  @override
  State<DoctorInfoApp> createState() => _DoctorInfoAppState();
}

class _DoctorInfoAppState extends State<DoctorInfoApp> {
  GoRouter? _router;
  AuthCubit? _authCubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authCubit = context.read<AuthCubit>();
    if (_authCubit == authCubit && _router != null) return;

    _authCubit = authCubit;
    _router?.dispose();
    _router = createAppRouter(authCubit);
  }

  @override
  void dispose() {
    _router?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        return BlocBuilder<ThemeStyleCubit, String>(
          builder: (context, themeStyle) {
            return BlocBuilder<LanguageCubit, Locale>(
              builder: (context, locale) {
                return MaterialApp.router(
                  title: 'CureVoo',
                  theme: MyTheme.getLightTheme(themeStyle),
                  darkTheme: MyTheme.getDarkTheme(themeStyle),
                  themeMode: themeMode,
                  locale: locale,
                  supportedLocales: const [Locale('en'), Locale('ar')],
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  routerConfig: _router!,
                  debugShowCheckedModeBanner: false,
                );
              },
            );
          },
        );
      },
    );
  }
}

GoRouter createAppRouter(
  AuthCubit authCubit, {
  String initialLocation = '/dashboard',
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) {
      final authState = authCubit.state;
      final path = state.uri.path;
      final isAuthRoute = path == '/login' || path == '/signup';
      final isLoadingRoute = path == '/loading';

      if (authState.status == AuthStatus.unknown) {
        if (isLoadingRoute) return null;
        final from = Uri.encodeComponent(state.uri.toString());
        return '/loading?from=$from';
      }

      if (!authState.isAuthenticated) {
        if (isAuthRoute) return null;
        return '/login';
      }

      if (isLoadingRoute) {
        final from = state.uri.queryParameters['from'];
        if (from == null || from.isEmpty) return '/dashboard';
        final decodedFrom = Uri.decodeComponent(from);
        return decodedFrom == '/login' || decodedFrom == '/signup'
            ? '/dashboard'
            : decodedFrom;
      }

      if (isAuthRoute || path == '/') {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/dashboard'),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const AuthLoadingPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => AuthEntryPage(
          initialMode: AuthEntryMode.login,
          onAuthModeChanged: (mode) {
            context.go(mode == AuthEntryMode.login ? '/login' : '/signup');
          },
        ),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => AuthEntryPage(
          initialMode: AuthEntryMode.signup,
          onAuthModeChanged: (mode) {
            context.go(mode == AuthEntryMode.login ? '/login' : '/signup');
          },
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final doctor = authCubit.state.doctor;
          return Leftsidebar(currentDoctor: doctor, child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => DashboardPage(
              onNavigateToSidebarIndex: (index) {
                context.go(SidebarRoute.items[index].path);
              },
            ),
          ),
          GoRoute(
            path: '/appointments',
            builder: (context, state) => const AppointmentPage(),
          ),
          GoRoute(
            path: '/patients',
            builder: (context, state) => const PatientManagementPage(),
          ),
          GoRoute(
            path: '/diagnosis',
            builder: (context, state) => DiagnosisPage(),
          ),
          GoRoute(
            path: '/treatment-resistance',
            builder: (context, state) => TreatmentResistancePage(),
          ),
          GoRoute(
            path: '/genomic-target-prioritization',
            builder: (context, state) => const GenomicTargetPrioritizationPage(),
          ),
          GoRoute(
            path: '/schedule',
            builder: (context, state) => SchedulePage(),
          ),
          GoRoute(
            path: '/treatment-plan',
            builder: (context, state) => const TreatmentPlanScreen(),
          ),
          GoRoute(path: '/profile', builder: (context, state) => ProfilePage()),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const UnknownRouteRedirectPage(),
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AuthLoadingPage extends StatelessWidget {
  const AuthLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class UnknownRouteRedirectPage extends StatefulWidget {
  const UnknownRouteRedirectPage({super.key});

  @override
  State<UnknownRouteRedirectPage> createState() =>
      _UnknownRouteRedirectPageState();
}

class _UnknownRouteRedirectPageState extends State<UnknownRouteRedirectPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = context.read<AuthCubit>().state;
      context.go(authState.isAuthenticated ? '/dashboard' : '/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const AuthLoadingPage();
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state.status == AuthStatus.unknown) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.isAuthenticated) {
          return Leftsidebar(
            currentDoctor: state.doctor,
            child: DashboardPage(onNavigateToSidebarIndex: (index) {}),
          );
        }

        return const AuthEntryPage();
      },
    );
  }
}

enum AuthEntryMode { login, signup }

class AuthEntryPage extends StatefulWidget {
  const AuthEntryPage({
    super.key,
    this.initialMode = AuthEntryMode.login,
    this.onAuthModeChanged,
  });

  final AuthEntryMode initialMode;
  final ValueChanged<AuthEntryMode>? onAuthModeChanged;

  @override
  State<AuthEntryPage> createState() => _AuthEntryPageState();
}

class _AuthEntryPageState extends State<AuthEntryPage> {
  late AuthEntryMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void didUpdateWidget(covariant AuthEntryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMode != widget.initialMode) {
      _mode = widget.initialMode;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          //  Leftsidebar(
          //   currentDoctor: Doctor(
          //     id: 'doctor-001',
          //     name: 'yazan',
          //     email: 'yazan@gmail.com',
          //     phoneNumber: '0923423432432',
          //     age: 10,
          //   ),
          // ),
          _mode == AuthEntryMode.login
          ? LoginPage(
              onSignUpPressed: () {
                setState(() {
                  _mode = AuthEntryMode.signup;
                });
                widget.onAuthModeChanged?.call(AuthEntryMode.signup);
              },
            )
          : SignUpPage(
              onLoginPressed: () {
                setState(() {
                  _mode = AuthEntryMode.login;
                });
                widget.onAuthModeChanged?.call(AuthEntryMode.login);
              },
            ),
    );
  }
}