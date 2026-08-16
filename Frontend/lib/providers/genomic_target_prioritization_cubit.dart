import 'package:curevoo_doctor/models/genomic_target_prioritization_result.dart';
import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:curevoo_doctor/repos/genomic_target_prioritization_repo.dart';
import 'package:curevoo_doctor/repos/main_repo.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GenomicTargetPrioritizationState extends Equatable {
  const GenomicTargetPrioritizationState({
    this.isRunningAnalysis = false,
    this.isCheckingHealth = false,
    this.isServiceAvailable,
    this.result,
    this.reportMarkdown,
    this.errorMessage,
  });

  final bool isRunningAnalysis;
  final bool isCheckingHealth;
  final bool? isServiceAvailable;
  final GenomicTargetPrioritizationResult? result;
  final String? reportMarkdown;
  final String? errorMessage;

  @override
  List<Object?> get props => [
    isRunningAnalysis,
    isCheckingHealth,
    isServiceAvailable,
    result,
    reportMarkdown,
    errorMessage,
  ];

  GenomicTargetPrioritizationState copyWith({
    bool? isRunningAnalysis,
    bool? isCheckingHealth,
    bool? isServiceAvailable,
    GenomicTargetPrioritizationResult? result,
    String? reportMarkdown,
    String? errorMessage,
    bool clearResult = false,
    bool clearReport = false,
    bool clearError = false,
  }) {
    return GenomicTargetPrioritizationState(
      isRunningAnalysis: isRunningAnalysis ?? this.isRunningAnalysis,
      isCheckingHealth: isCheckingHealth ?? this.isCheckingHealth,
      isServiceAvailable: isServiceAvailable ?? this.isServiceAvailable,
      result: clearResult ? null : (result ?? this.result),
      reportMarkdown: clearReport ? null : (reportMarkdown ?? this.reportMarkdown),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class GenomicTargetPrioritizationCubit
    extends Cubit<GenomicTargetPrioritizationState> {
  GenomicTargetPrioritizationCubit._(this._repo, this._authCubit)
    : super(const GenomicTargetPrioritizationState());

  final GenomicTargetPrioritizationRepo _repo;
  final AuthCubit _authCubit;

  static const String _serviceUnavailableMessage =
      'AI service is temporarily unavailable. Please try again later.';

  static GenomicTargetPrioritizationCubit create({
    required AuthCubit authCubit,
    String baseUrl = AuthCubit.defaultApiBaseUrl,
  }) {
    final repo = GenomicTargetPrioritizationRepo(
      // Whole-cohort ranking and pipeline runs take longer than a standard request.
      mainRepo: MainRepo(baseUrl: baseUrl, timeout: const Duration(minutes: 4)),
    );
    return GenomicTargetPrioritizationCubit._(repo, authCubit);
  }

  void clearResult() {
    emit(const GenomicTargetPrioritizationState());
  }

  void setValidationError(String message) {
    emit(
      state.copyWith(
        isRunningAnalysis: false,
        errorMessage: message,
        clearResult: true,
        clearReport: true,
      ),
    );
  }

  Future<bool> checkServiceHealth() async {
    if (state.isCheckingHealth) return state.isServiceAvailable ?? false;

    emit(state.copyWith(isCheckingHealth: true, clearError: true));

    try {
      final response = await _withRefreshRetry(
        (token) => _repo.checkHealth(token),
      );
      final isAvailable =
          response is Map && response['available'] == true;
      emit(
        state.copyWith(
          isCheckingHealth: false,
          isServiceAvailable: isAvailable,
        ),
      );
      return isAvailable;
    } catch (_) {
      emit(
        state.copyWith(isCheckingHealth: false, isServiceAvailable: false),
      );
      return false;
    }
  }

  Future<GenomicTargetPrioritizationResult?> runAnalysis({
    int topN = 20,
    MultipartFileData? mutationsFile,
    MultipartFileData? expressionFile,
  }) async {
    if (state.isRunningAnalysis) return null;

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          isRunningAnalysis: false,
          errorMessage: 'Missing access token.',
          clearResult: true,
          clearReport: true,
        ),
      );
      return null;
    }

    emit(
      state.copyWith(
        isRunningAnalysis: true,
        clearError: true,
        clearResult: true,
        clearReport: true,
      ),
    );

    try {
      final response = await _withRefreshRetry(
        (accessToken) => _repo.analyze(
          accessToken,
          topN: topN,
          mutationsFile: mutationsFile,
          expressionFile: expressionFile,
        ),
      );

      if (response is! Map) {
        emit(
          state.copyWith(
            isRunningAnalysis: false,
            errorMessage: _serviceUnavailableMessage,
            clearResult: true,
          ),
        );
        return null;
      }

      final result = GenomicTargetPrioritizationResult.fromMap(
        response.map((key, dynamic value) => MapEntry(key.toString(), value)),
      );
      emit(
        state.copyWith(
          isRunningAnalysis: false,
          isServiceAvailable: true,
          result: result,
          clearError: true,
        ),
      );
      return result;
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          isRunningAnalysis: false,
          isServiceAvailable: e.statusCode == 503 ? false : null,
          errorMessage: _formatAnalysisError(e),
          clearResult: true,
        ),
      );
      return null;
    } catch (_) {
      emit(
        state.copyWith(
          isRunningAnalysis: false,
          errorMessage: _serviceUnavailableMessage,
          clearResult: true,
        ),
      );
      return null;
    }
  }

  Future<String?> loadReport() async {
    final runId = state.result?.runId;
    if (runId == null || runId.isEmpty) return null;
    if (state.reportMarkdown != null) return state.reportMarkdown;

    try {
      final response = await _withRefreshRetry(
        (token) => _repo.fetchReport(token, runId: runId),
      );
      final markdown = response is String ? response : response?.toString();
      if (markdown == null || markdown.trim().isEmpty) return null;

      emit(state.copyWith(reportMarkdown: markdown, clearError: true));
      return markdown;
    } on ApiException catch (e) {
      emit(state.copyWith(errorMessage: _formatAnalysisError(e)));
      return null;
    } catch (_) {
      emit(state.copyWith(errorMessage: _serviceUnavailableMessage));
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

  String _formatAnalysisError(ApiException exception) {
    if (exception.statusCode == 503 || exception.statusCode == 504) {
      return _serviceUnavailableMessage;
    }

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
        final message = typedError['message']?.toString().trim();
        if (message != null && message.isNotEmpty) return message;
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
