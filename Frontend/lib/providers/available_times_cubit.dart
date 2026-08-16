import 'package:curevoo_doctor/models/doctor_available_time.dart';
import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:curevoo_doctor/repos/doctor_available_times_repo.dart';
import 'package:curevoo_doctor/repos/main_repo.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AvailableTimesState extends Equatable {
  const AvailableTimesState({
    this.times = const [],
    this.isLoading = false,
    this.isLoadingDayTimes = false,
    this.isSaving = false,
    this.hasLoaded = false,
    this.dayAvailableTimes = const [],
    this.loadedDayDate,
    this.errorMessage,
  });

  final List<DoctorAvailableTime> times;
  final bool isLoading;
  final bool isLoadingDayTimes;
  final bool isSaving;
  final bool hasLoaded;
  final List<String> dayAvailableTimes;
  final String? loadedDayDate;
  final String? errorMessage;

  @override
  List<Object?> get props => [
    times,
    isLoading,
    isLoadingDayTimes,
    isSaving,
    hasLoaded,
    dayAvailableTimes,
    loadedDayDate,
    errorMessage,
  ];

  AvailableTimesState copyWith({
    List<DoctorAvailableTime>? times,
    bool? isLoading,
    bool? isLoadingDayTimes,
    bool? isSaving,
    bool? hasLoaded,
    List<String>? dayAvailableTimes,
    String? loadedDayDate,
    String? errorMessage,
    bool clearError = false,
    bool clearLoadedDayDate = false,
  }) {
    return AvailableTimesState(
      times: times ?? this.times,
      isLoading: isLoading ?? this.isLoading,
      isLoadingDayTimes: isLoadingDayTimes ?? this.isLoadingDayTimes,
      isSaving: isSaving ?? this.isSaving,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      dayAvailableTimes: dayAvailableTimes ?? this.dayAvailableTimes,
      loadedDayDate: clearLoadedDayDate
          ? null
          : (loadedDayDate ?? this.loadedDayDate),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AvailableTimesCubit extends Cubit<AvailableTimesState> {
  AvailableTimesCubit._(this._repo, this._authCubit)
    : super(AvailableTimesState(times: _defaultWeek));

  final DoctorAvailableTimesRepo _repo;
  final AuthCubit _authCubit;

  static AvailableTimesCubit create({
    required AuthCubit authCubit,
    String baseUrl = AuthCubit.defaultApiBaseUrl,
  }) {
    final repo = DoctorAvailableTimesRepo(mainRepo: MainRepo(baseUrl: baseUrl));
    return AvailableTimesCubit._(repo, authCubit);
  }

  static const List<DoctorAvailableTime> _defaultWeek = [
    DoctorAvailableTime(dayOfWeek: 0, from: null, to: null, isOn: false),
    DoctorAvailableTime(dayOfWeek: 1, from: '09:00', to: '17:00', isOn: true),
    DoctorAvailableTime(dayOfWeek: 2, from: '09:00', to: '17:00', isOn: true),
    DoctorAvailableTime(dayOfWeek: 3, from: '09:00', to: '17:00', isOn: true),
    DoctorAvailableTime(dayOfWeek: 4, from: '09:00', to: '17:00', isOn: true),
    DoctorAvailableTime(dayOfWeek: 5, from: '09:00', to: '17:00', isOn: true),
    DoctorAvailableTime(dayOfWeek: 6, from: null, to: null, isOn: false),
  ];

  Future<void> loadAvailableTimes({bool forceRefresh = false}) async {
    if (state.isLoading) return;
    if (state.hasLoaded && !forceRefresh) return;

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          isLoading: false,
          hasLoaded: false,
          errorMessage: 'Missing access token.',
        ),
      );
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final fetched = await _withRefreshRetry(_repo.fetchAvailableTimes);
      emit(
        state.copyWith(
          times: _normalizeWeek(fetched),
          isLoading: false,
          hasLoaded: true,
          clearError: true,
        ),
      );
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          hasLoaded: false,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          hasLoaded: false,
          errorMessage: 'Failed to load available times.',
        ),
      );
    }
  }

  Future<void> loadAvailableTimesForDay({
    required String date,
    bool forceRefresh = false,
  }) async {
    if (state.isLoadingDayTimes) return;
    if (!forceRefresh &&
        state.loadedDayDate == date &&
        state.dayAvailableTimes.isNotEmpty) {
      return;
    }

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          isLoadingDayTimes: false,
          dayAvailableTimes: const [],
          loadedDayDate: date,
          errorMessage: 'Missing access token.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        isLoadingDayTimes: true,
        dayAvailableTimes: const [],
        loadedDayDate: date,
        clearError: true,
      ),
    );

    try {
      final fetched = await _withRefreshRetry(
        (accessToken) =>
            _repo.fetchAvailableTimesForDay(accessToken, date: date),
      );
      emit(
        state.copyWith(
          dayAvailableTimes: fetched,
          isLoadingDayTimes: false,
          loadedDayDate: date,
          clearError: true,
        ),
      );
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          dayAvailableTimes: const [],
          isLoadingDayTimes: false,
          loadedDayDate: date,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          dayAvailableTimes: const [],
          isLoadingDayTimes: false,
          loadedDayDate: date,
          errorMessage: 'Failed to load available times for selected day.',
        ),
      );
    }
  }

  void updateWorkingDay(DoctorAvailableTime day) {
    final current = [...state.times];
    final index = current.indexWhere((item) => item.dayOfWeek == day.dayOfWeek);
    if (index >= 0) {
      current[index] = day;
    } else {
      current.add(day);
    }
    emit(state.copyWith(times: _normalizeWeek(current), clearError: true));
  }

  Future<bool> saveAvailableTimes() async {
    if (state.isSaving) return false;

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(isSaving: false, errorMessage: 'Missing access token.'),
      );
      return false;
    }

    emit(state.copyWith(isSaving: true, clearError: true));

    try {
      final timesToSave = _normalizeWeek(state.times);
      final prepared = <DoctorAvailableTime>[];

      for (final day in timesToSave) {
        final validationError = _validateDay(day);
        if (validationError != null) {
          emit(state.copyWith(isSaving: false, errorMessage: validationError));
          return false;
        }
        prepared.add(_normalizeForRequest(day));
      }

      for (final day in prepared) {
        await _withRefreshRetry(
          (accessToken) => _repo.updateAvailableTime(accessToken, day),
        );
      }

      emit(
        state.copyWith(
          times: prepared,
          isSaving: false,
          hasLoaded: true,
          clearError: true,
        ),
      );
      return true;
    } on ApiException catch (e) {
      emit(state.copyWith(isSaving: false, errorMessage: e.message));
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: 'Failed to save available times.',
        ),
      );
      return false;
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

  List<DoctorAvailableTime> _normalizeWeek(List<DoctorAvailableTime> input) {
    final byDay = <int, DoctorAvailableTime>{
      for (final day in _defaultWeek) day.dayOfWeek: day,
    };
    for (final day in input) {
      if (day.dayOfWeek < 0 || day.dayOfWeek > 6) continue;
      byDay[day.dayOfWeek] = day;
    }

    return List<DoctorAvailableTime>.generate(
      7,
      (day) => byDay[day] ?? _defaultWeek[day],
      growable: false,
    );
  }

  String? _validateDay(DoctorAvailableTime day) {
    if (day.dayOfWeek < 0 || day.dayOfWeek > 6) {
      return 'dayOfWeek must be between 0 and 6.';
    }

    if (!day.isOn) return null;

    final from = day.from?.trim() ?? '';
    final to = day.to?.trim() ?? '';

    if (from.isEmpty || to.isEmpty) {
      return 'from and to are required when isOn is true (dayOfWeek: ${day.dayOfWeek}).';
    }

    if (!_isValidTimeFormat(from) || !_isValidTimeFormat(to)) {
      return 'Time format must be HH:mm (dayOfWeek: ${day.dayOfWeek}).';
    }

    if (!_isFromBeforeTo(from, to)) {
      return 'from must be before to (dayOfWeek: ${day.dayOfWeek}).';
    }

    return null;
  }

  DoctorAvailableTime _normalizeForRequest(DoctorAvailableTime day) {
    final normalizedFrom = _normalizeTime(day.from);
    final normalizedTo = _normalizeTime(day.to);
    return day.copyWith(
      from: normalizedFrom ?? '09:00',
      to: normalizedTo ?? '17:00',
    );
  }

  String? _normalizeTime(String? time) {
    final raw = time?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (_isValidTimeFormat(raw)) return raw;
    return null;
  }

  bool _isValidTimeFormat(String value) {
    return RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);
  }

  bool _isFromBeforeTo(String from, String to) {
    final fromParts = from.split(':');
    final toParts = to.split(':');
    final fromMinutes =
        (int.parse(fromParts[0]) * 60) + int.parse(fromParts[1]);
    final toMinutes = (int.parse(toParts[0]) * 60) + int.parse(toParts[1]);
    return fromMinutes < toMinutes;
  }

  @override
  Future<void> close() {
    _repo.close();
    return super.close();
  }
}
