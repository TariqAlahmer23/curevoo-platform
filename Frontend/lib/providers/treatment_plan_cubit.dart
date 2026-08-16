import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:curevoo_doctor/repos/main_repo.dart';
import 'package:curevoo_doctor/repos/treatment_plan_repo.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TreatmentPlanState extends Equatable {
  const TreatmentPlanState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;

  @override
  List<Object?> get props => [isSubmitting, isSuccess, errorMessage];

  TreatmentPlanState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TreatmentPlanState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class TreatmentPlanCubit extends Cubit<TreatmentPlanState> {
  TreatmentPlanCubit._(
    this._treatmentPlanRepo,
    this._authCubit,
  ) : super(const TreatmentPlanState());

  final TreatmentPlanRepo _treatmentPlanRepo;
  final AuthCubit _authCubit;

  static TreatmentPlanCubit create({
    required AuthCubit authCubit,
    String baseUrl = AuthCubit.defaultApiBaseUrl,
  }) {
    final repo = TreatmentPlanRepo(mainRepo: MainRepo(baseUrl: baseUrl));
    return TreatmentPlanCubit._(repo, authCubit);
  }

  Future<bool> createTreatmentPlan({
    required CreateTreatmentPlanRequest request,
  }) async {
    if (state.isSubmitting) return false;

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: 'Missing access token.',
        ),
      );
      return false;
    }

    emit(
      state.copyWith(
        isSubmitting: true,
        isSuccess: false,
        clearError: true,
      ),
    );

    try {
      await _withRefreshRetry(
        (accessToken) => _treatmentPlanRepo.createTreatmentPlan(
          accessToken,
          request,
        ),
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: true,
          clearError: true,
        ),
      );
      return true;
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: e.message,
        ),
      );
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: 'Failed to create treatment plan. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<LatestTreatmentPlanRecord> fetchLatestTreatmentPlan({
    required String patientUserId,
  }) async {
    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      throw ApiException(message: 'Missing access token.');
    }

    return _withRefreshRetry(
      (accessToken) => _treatmentPlanRepo.fetchLatestTreatmentPlan(
        accessToken,
        patientUserId: patientUserId,
      ),
    );
  }

  Future<List<LatestTreatmentPlanRecord>> fetchAllTreatmentPlans({
    required String patientUserId,
  }) async {
    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      throw ApiException(message: 'Missing access token.');
    }

    return _withRefreshRetry(
      (accessToken) => _treatmentPlanRepo.fetchAllTreatmentPlans(
        accessToken,
        patientUserId: patientUserId,
      ),
    );
  }

  Future<T> _withRefreshRetry<T>(
    Future<T> Function(String token) action,
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

      return await action(refreshedToken);
    }
  }

  @override
  Future<void> close() {
    _treatmentPlanRepo.close();
    return super.close();
  }
}
