// Live integration test for the Genomic Target Prioritization page.
//
// It drives the real widget against the running backend, which in turn calls
// the FastAPI AI service. Run it with the full stack up:
//
//   flutter test test/genomic_target_prioritization_test.dart \
//     --dart-define=E2E_API_BASE_URL=http://localhost:3000/api \
//     --dart-define=E2E_ACCESS_TOKEN=<doctor access token>
//
// Without E2E_ACCESS_TOKEN the test is skipped instead of failing, so the
// default `flutter test` run stays offline-safe.

import 'dart:io';

import 'package:curevoo_doctor/localization/app_localization.dart';
import 'package:curevoo_doctor/models/doctor.dart';
import 'package:curevoo_doctor/pages/genomic_target_prioritization.dart';
import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:curevoo_doctor/providers/genomic_target_prioritization_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const String _accessToken = String.fromEnvironment('E2E_ACCESS_TOKEN');
const String _apiBaseUrl = String.fromEnvironment(
  'E2E_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:3000/api',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          return call.method == 'readAll' ? <String, String>{} : null;
        });
  });

  testWidgets(
    'runs an analysis through the backend and renders ranked targets',
    (tester) async {
      // The test binding stubs every HTTP request with a 400 response. This
      // suite deliberately exercises the real backend, so the override is
      // removed for the duration of the test.
      HttpOverrides.global = null;

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 2600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authCubit = AuthCubit.testing(
        AuthState(
          status: AuthStatus.authenticated,
          doctor: _testDoctor,
          token: _accessToken,
        ),
      );
      addTearDown(authCubit.close);

      final cubit = GenomicTargetPrioritizationCubit.create(
        authCubit: authCubit,
        baseUrl: _apiBaseUrl,
      );
      addTearDown(cubit.close);

      await tester.runAsync(() async {
        await tester.pumpWidget(_buildTestApp(authCubit, cubit));

        // The page kicks off its own AI service health check on the first frame.
        await tester.pump();
        if (cubit.state.isServiceAvailable == null) {
          await cubit.stream.firstWhere(
            (state) => state.isServiceAvailable != null,
          );
        }
      });
      await tester.pump();

      expect(
        cubit.state.isServiceAvailable,
        isTrue,
        reason: 'Backend could not reach the FastAPI AI service.',
      );

      // Header, description, and mandatory disclaimer.
      expect(find.text('Genomic Target Prioritization'), findsOneWidget);
      expect(
        find.textContaining('AI-powered research service for ranking'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Research-use only.'),
        findsOneWidget,
      );
      expect(find.text('AI service online'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Run Analysis'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Run Analysis'));
        await cubit.stream.firstWhere(
          (state) =>
              !state.isRunningAnalysis &&
              (state.result != null || state.errorMessage != null),
        );
      });
      await tester.pump();

      expect(
        cubit.state.errorMessage,
        isNull,
        reason: 'Analysis returned an error: ${cubit.state.errorMessage}',
      );

      final result = cubit.state.result;
      expect(result, isNotNull);
      expect(result!.topTargets, isNotEmpty);
      expect(result.disclaimer, contains('Research-use only'));

      // Ranked targets, evidence tiers, safety notes, and explanations render.
      expect(find.text('Top Ranked Targets'), findsOneWidget);
      expect(find.text(result.topTargets.first.gene), findsWidgets);
      expect(find.text('Evidence tier'), findsWidgets);
      expect(find.text('Safety risk'), findsWidgets);
      expect(find.text('Explanation'), findsWidgets);
      expect(find.text('External evidence'), findsWidgets);

      // ML metrics come from the AI service, including accuracy when available.
      expect(find.text('Model Evaluation Metrics'), findsOneWidget);
      expect(find.text('Accuracy'), findsOneWidget);
      expect(find.text('F1-score'), findsOneWidget);
      expect(find.text('MCC'), findsOneWidget);
      expect(find.text('ROC-AUC'), findsOneWidget);
      expect(find.text('PR-AUC'), findsOneWidget);

      final metrics = result.mlMetrics;
      if (metrics.available) {
        expect(metrics.accuracy, isNotNull);
        expect(
          find.text(metrics.accuracy!.toStringAsFixed(4)),
          findsOneWidget,
        );
      } else {
        expect(find.text('Unavailable'), findsWidgets);
      }

      // No treatment recommendations are shown anywhere on the page.
      expect(find.textContaining('Treatment recommendation'), findsNothing);
      expect(find.textContaining('recommended treatment'), findsNothing);
    },
    skip: _accessToken.isEmpty,
  );
}

Widget _buildTestApp(
  AuthCubit authCubit,
  GenomicTargetPrioritizationCubit cubit,
) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthCubit>.value(value: authCubit),
      BlocProvider<GenomicTargetPrioritizationCubit>.value(value: cubit),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      supportedLocales: [Locale('en'), Locale('ar')],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: GenomicTargetPrioritizationPage(),
    ),
  );
}

final _testDoctor = Doctor(
  id: 'doctor-test',
  name: 'Test Doctor',
  email: 'doctor@example.com',
  phoneNumber: '0000000000',
  age: 40,
);
