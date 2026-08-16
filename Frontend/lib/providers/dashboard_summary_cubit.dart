import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:curevoo_doctor/repos/dashboard_repo.dart';
import 'package:curevoo_doctor/repos/main_repo.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DashboardSummaryState extends Equatable {
  const DashboardSummaryState({
    this.isLoading = false,
    this.totalPatients = 0,
    this.upcomingAppointments = 0,
    this.pendingAppointments = 0,
    this.latestAiPredictionAt,
    this.errorMessage,
  });

  final bool isLoading;
  final int totalPatients;
  final int upcomingAppointments;
  final int pendingAppointments;
  final String? latestAiPredictionAt;
  final String? errorMessage;

  @override
  List<Object?> get props => [
    isLoading,
    totalPatients,
    upcomingAppointments,
    pendingAppointments,
    latestAiPredictionAt,
    errorMessage,
  ];

  DashboardSummaryState copyWith({
    bool? isLoading,
    int? totalPatients,
    int? upcomingAppointments,
    int? pendingAppointments,
    String? latestAiPredictionAt,
    String? errorMessage,
    bool clearLatestAiPredictionAt = false,
    bool clearError = false,
  }) {
    return DashboardSummaryState(
      isLoading: isLoading ?? this.isLoading,
      totalPatients: totalPatients ?? this.totalPatients,
      upcomingAppointments: upcomingAppointments ?? this.upcomingAppointments,
      pendingAppointments: pendingAppointments ?? this.pendingAppointments,
      latestAiPredictionAt: clearLatestAiPredictionAt
          ? null
          : (latestAiPredictionAt ?? this.latestAiPredictionAt),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DashboardSummaryCubit extends Cubit<DashboardSummaryState> {
  DashboardSummaryCubit._(this._repo, this._authCubit)
    : super(const DashboardSummaryState());

  final DashboardRepo _repo;
  final AuthCubit _authCubit;

  static DashboardSummaryCubit create({
    required AuthCubit authCubit,
    String baseUrl = AuthCubit.defaultApiBaseUrl,
  }) {
    return DashboardSummaryCubit._(
      DashboardRepo(mainRepo: MainRepo(baseUrl: baseUrl)),
      authCubit,
    );
  }

  void markPendingAppointmentHandled() {
    if (state.pendingAppointments <= 0) return;

    emit(
      state.copyWith(
        pendingAppointments: state.pendingAppointments - 1,
        clearError: true,
      ),
    );
  }

  Future<void> loadSummary() async {
    if (state.isLoading) return;

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(state.copyWith(errorMessage: 'Missing access token.'));
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final summary = await _withRefreshRetry(
        (accessToken) => _repo.fetchSummary(accessToken),
      );
      final data = _extractData(summary);
      emit(
        state.copyWith(
          isLoading: false,
          totalPatients: _readInt(data, const ['totalPatients']) ?? 0,
          upcomingAppointments:
              _readInt(data, const ['upcomingAppointments']) ?? 0,
          pendingAppointments:
              _readInt(data, const ['pendingAppointments']) ?? 0,
          latestAiPredictionAt:
              _readString(data, const ['latestAiPredictionAt']) ?? '-',
          clearError: true,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load dashboard summary.',
        ),
      );
    }
  }

  Map<String, dynamic> _extractData(Map<String, dynamic> source) {
    final nested = source['data'];
    if (nested is Map<String, dynamic>) return nested;
    if (nested is Map) {
      return nested.map(
        (key, dynamic value) => MapEntry(key.toString(), value),
      );
    }
    return source;
  }

  Future<Map<String, dynamic>> _withRefreshRetry(
    Future<Map<String, dynamic>> Function(String token) action,
  ) async {
    final initialToken = _authCubit.state.token;
    if (initialToken == null || initialToken.isEmpty) {
      throw ApiException(message: 'Missing access token.');
    }

    try {
      return await action(initialToken);
    } on ApiException catch (e) {
      if (e.statusCode != 401) rethrow;

      final refreshed = await _authCubit.refreshSession();
      if (!refreshed) rethrow;

      final refreshedToken = _authCubit.state.token;
      if (refreshedToken == null || refreshedToken.isEmpty) {
        throw ApiException(message: 'Missing refreshed access token.');
      }
      return action(refreshedToken);
    }
  }

  @override
  Future<void> close() {
    _repo.close();
    return super.close();
  }
}

String? _readString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
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
