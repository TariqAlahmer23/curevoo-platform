import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:curevoo_doctor/main.dart';
import 'package:curevoo_doctor/models/doctor.dart';
import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:curevoo_doctor/providers/available_times_cubit.dart';
import 'package:curevoo_doctor/providers/dashboard_summary_cubit.dart';
import 'package:curevoo_doctor/providers/doctor_cubit.dart';
import 'package:curevoo_doctor/providers/language_cubit.dart';
import 'package:curevoo_doctor/providers/medical_history_cubit.dart';
import 'package:curevoo_doctor/providers/patient_appointments_cubit.dart';
import 'package:curevoo_doctor/providers/patients_cubit.dart';
import 'package:curevoo_doctor/providers/theme_cubit.dart';
import 'package:curevoo_doctor/providers/treatment_plan_cubit.dart';
import 'package:curevoo_doctor/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final secureStorageValues = <String, String>{};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      final arguments = Map<String, dynamic>.from(
        call.arguments as Map? ?? const {},
      );
      final key = arguments['key']?.toString();

      switch (call.method) {
        case 'read':
          return key == null ? null : secureStorageValues[key];
        case 'write':
          if (key != null) {
            secureStorageValues[key] = arguments['value']?.toString() ?? '';
          }
          return null;
        case 'delete':
          if (key != null) {
            secureStorageValues.remove(key);
          }
          return null;
        case 'deleteAll':
          secureStorageValues.clear();
          return null;
        case 'readAll':
          return secureStorageValues;
      }

      return null;
    });
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorageValues.clear();
  });

  Future<void> setDesktopViewport(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('unauthenticated users are redirected to login', (tester) async {
    await setDesktopViewport(tester);
    await tester.pumpWidget(
      await _buildTestApp(
        authState: const AuthState(status: AuthStatus.unauthenticated),
        initialLocation: '/patients',
      ),
    );
    await tester.pump();

    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
  });

  testWidgets('authenticated users see the dashboard shell', (tester) async {
    await setDesktopViewport(tester);
    await tester.pumpWidget(
      await _buildTestApp(
        authState: AuthState(
          status: AuthStatus.authenticated,
          doctor: _testDoctor,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('CureVoo'), findsWidgets);
    expect(find.text('Dashboard Overview'), findsOneWidget);
  });

  testWidgets('authenticated users visiting login are sent to dashboard', (
    tester,
  ) async {
    await setDesktopViewport(tester);
    await tester.pumpWidget(
      await _buildTestApp(
        authState: AuthState(
          status: AuthStatus.authenticated,
          doctor: _testDoctor,
        ),
        initialLocation: '/login',
      ),
    );
    await tester.pump();

    expect(find.text('Dashboard Overview'), findsOneWidget);
    expect(find.text('Email Address'), findsNothing);
  });

  testWidgets('authenticated users visiting signup are sent to dashboard', (
    tester,
  ) async {
    await setDesktopViewport(tester);
    await tester.pumpWidget(
      await _buildTestApp(
        authState: AuthState(
          status: AuthStatus.authenticated,
          doctor: _testDoctor,
        ),
        initialLocation: '/signup',
      ),
    );
    await tester.pump();

    expect(find.text('Dashboard Overview'), findsOneWidget);
    expect(find.text('Doctor Registration Portal'), findsNothing);
  });

  testWidgets('direct patient route selects patients and renders the page', (
    tester,
  ) async {
    await setDesktopViewport(tester);
    await tester.pumpWidget(
      await _buildTestApp(
        authState: AuthState(
          status: AuthStatus.authenticated,
          doctor: _testDoctor,
        ),
        initialLocation: '/patients',
      ),
    );
    await tester.pump();

    expect(find.text('Patients'), findsWidgets);
    expect(find.text('Patient Management'), findsOneWidget);
  });

  testWidgets('unknown routes fall back to the authenticated dashboard', (
    tester,
  ) async {
    await setDesktopViewport(tester);
    await tester.pumpWidget(
      await _buildTestApp(
        authState: AuthState(
          status: AuthStatus.authenticated,
          doctor: _testDoctor,
        ),
        initialLocation: '/missing-route',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Dashboard Overview'), findsOneWidget);
  });

  testWidgets('login and signup links switch the auth route content', (
    tester,
  ) async {
    await setDesktopViewport(tester);
    await tester.pumpWidget(
      await _buildTestApp(
        authState: const AuthState(status: AuthStatus.unauthenticated),
        initialLocation: '/login',
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Create Account').last);
    await tester.pumpAndSettle();

    expect(find.text('Doctor Registration Portal'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);

    final signInButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Sign In').last,
    );
    signInButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('Email Address'), findsWidgets);
  });

  testWidgets('logout redirects protected UI back to login', (tester) async {
    await setDesktopViewport(tester);
    final authCubit = AuthCubit.testing(
      AuthState(
        status: AuthStatus.authenticated,
        doctor: _testDoctor,
        token: 'active-token',
      ),
    );
    addTearDown(authCubit.close);

    await tester.pumpWidget(
      await _buildTestApp(
        authState: authCubit.state,
        authCubit: authCubit,
      ),
    );
    await tester.pump();

    await authCubit.logout();
    await tester.pumpAndSettle();

    expect(authCubit.state.status, AuthStatus.unauthenticated);
    expect(find.text('Email Address'), findsWidgets);
    expect(find.text('Dashboard Overview'), findsNothing);
  });

  test('failed refresh expires the local session', () async {
    final authCubit = AuthCubit.testing(
      AuthState(
        status: AuthStatus.authenticated,
        doctor: _testDoctor,
        token: 'expired-token',
      ),
    );
    addTearDown(authCubit.close);

    final refreshed = await authCubit.refreshSession();

    expect(refreshed, isFalse);
    expect(authCubit.state.status, AuthStatus.unauthenticated);
    expect(authCubit.state.token, isNull);
    expect(authCubit.state.errorMessage, 'Session expired. Please login again.');
  });
}

Future<Widget> _buildTestApp({
  required AuthState authState,
  String initialLocation = '/dashboard',
  AuthCubit? authCubit,
}) async {
  final resolvedAuthCubit = authCubit ?? AuthCubit.testing(authState);
  final themeCubit = await ThemeCubit.create();
  final languageCubit = await LanguageCubit.create();

  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthCubit>.value(value: resolvedAuthCubit),
      BlocProvider<ThemeCubit>.value(value: themeCubit),
      BlocProvider<LanguageCubit>.value(value: languageCubit),
      BlocProvider<AvailableTimesCubit>.value(
        value: AvailableTimesCubit.create(authCubit: resolvedAuthCubit),
      ),
      BlocProvider<DoctorCubit>.value(
        value: DoctorCubit.create(authCubit: resolvedAuthCubit),
      ),
      BlocProvider<DashboardSummaryCubit>.value(
        value: DashboardSummaryCubit.create(authCubit: resolvedAuthCubit),
      ),
      BlocProvider<PatientAppointmentsCubit>.value(
        value: await PatientAppointmentsCubit.create(
          authCubit: resolvedAuthCubit,
        ),
      ),
      BlocProvider<PatientsCubit>.value(
        value: PatientsCubit.create(authCubit: resolvedAuthCubit),
      ),
      BlocProvider<MedicalHistoryCubit>.value(
        value: MedicalHistoryCubit.create(authCubit: resolvedAuthCubit),
      ),
      BlocProvider<TreatmentPlanCubit>.value(
        value: TreatmentPlanCubit.create(authCubit: resolvedAuthCubit),
      ),
    ],
    child: _RouterTestApp(
      authCubit: resolvedAuthCubit,
      initialLocation: initialLocation,
    ),
  );
}

class _RouterTestApp extends StatelessWidget {
  const _RouterTestApp({
    required this.authCubit,
    required this.initialLocation,
  });

  final AuthCubit authCubit;
  final String initialLocation;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CureVoo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: createAppRouter(
        authCubit,
        initialLocation: initialLocation,
      ),
    );
  }
}

final _testDoctor = Doctor(
  id: 'doctor-test',
  name: 'Test Doctor',
  email: 'doctor@example.com',
  phoneNumber: '0000000000',
  age: 40,
);
