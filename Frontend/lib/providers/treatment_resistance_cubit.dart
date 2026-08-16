import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:curevoo_doctor/repos/main_repo.dart';
import 'package:curevoo_doctor/repos/treatment_resistance_repo.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TreatmentResistanceState extends Equatable {
  const TreatmentResistanceState({
    this.isRunningPrediction = false,
    this.response,
    this.errorMessage,
  });

  final bool isRunningPrediction;
  final dynamic response;
  final String? errorMessage;

  @override
  List<Object?> get props => [isRunningPrediction, response, errorMessage];

  TreatmentResistanceState copyWith({
    bool? isRunningPrediction,
    dynamic response,
    String? errorMessage,
    bool clearResponse = false,
    bool clearError = false,
  }) {
    return TreatmentResistanceState(
      isRunningPrediction: isRunningPrediction ?? this.isRunningPrediction,
      response: clearResponse ? null : (response ?? this.response),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class TreatmentResistanceCubit extends Cubit<TreatmentResistanceState> {
  TreatmentResistanceCubit._(this._repo, this._authCubit)
    : super(const TreatmentResistanceState());

  final TreatmentResistanceRepo _repo;
  final AuthCubit _authCubit;

  static TreatmentResistanceCubit create({
    required AuthCubit authCubit,
    String baseUrl = AuthCubit.defaultApiBaseUrl,
  }) {
    final repo = TreatmentResistanceRepo(mainRepo: MainRepo(baseUrl: baseUrl));
    return TreatmentResistanceCubit._(repo, authCubit);
  }

  void clearResult() {
    emit(const TreatmentResistanceState());
  }

  void setValidationError(String message) {
    emit(
      state.copyWith(
        isRunningPrediction: false,
        errorMessage: message,
        clearResponse: true,
      ),
    );
  }

  Future<dynamic> predictNsclc({required Map<String, dynamic> body}) async {
    if (state.isRunningPrediction) return null;

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          isRunningPrediction: false,
          errorMessage: 'Missing access token.',
          clearResponse: true,
        ),
      );
      return null;
    }

    emit(
      state.copyWith(
        isRunningPrediction: true,
        clearError: true,
        clearResponse: true,
      ),
    );

    try {
      final response = await _withRefreshRetry(
        (accessToken) => _repo.predictNsclc(accessToken, body: body),
      );
      emit(
        state.copyWith(
          isRunningPrediction: false,
          response: response,
          clearError: true,
        ),
      );
      return response;
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          isRunningPrediction: false,
          errorMessage: e.statusCode == 503
              ? 'AI service is temporarily unavailable. Please try again later.'
              : _formatPredictionError(e),
          clearResponse: true,
        ),
      );
      return null;
    } catch (_) {
      emit(
        state.copyWith(
          isRunningPrediction: false,
          errorMessage:
              'AI service is temporarily unavailable. Please try again later.',
          clearResponse: true,
        ),
      );
      return null;
    }
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

      return action(refreshedToken);
    }
  }

  String _formatPredictionError(ApiException exception) {
    final data = exception.data;
    if (data is Map) {
      final typed = data.map(
        (key, dynamic value) => MapEntry(key.toString(), value),
      );
      final error = typed['error'];
      if (error is Map) {
        final typedError = error.map(
          (key, dynamic value) => MapEntry(key.toString(), value),
        );
        final code = typedError['code']?.toString().trim();
        final message = typedError['message']?.toString().trim();
        if (code != null && code.isNotEmpty) {
          if (message != null && message.isNotEmpty) {
            return '$code: $message';
          }
          return code;
        }
      }

      final code = typed['code']?.toString().trim();
      if (code != null && code.isNotEmpty) {
        return '$code: ${exception.message}';
      }
    }

    return exception.message;
  }

  @override
  Future<void> close() {
    _repo.close();
    return super.close();
  }
}
