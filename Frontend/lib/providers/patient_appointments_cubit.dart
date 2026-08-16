import 'package:curevoo_doctor/models/create_patient_appointment_request.dart';
import 'package:curevoo_doctor/models/doctor_appointment_item.dart';
import 'package:curevoo_doctor/models/doctor_booked_slot.dart';
import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:curevoo_doctor/repos/main_repo.dart';
import 'package:curevoo_doctor/repos/patient_appointments_repo.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatientAppointmentsState extends Equatable {
  const PatientAppointmentsState({
    this.appointments = const [],
    this.bookedSlots = const [],
    this.activeFilter = 'ALL',
    this.isLoading = false,
    this.isLoadingBookedSlots = false,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final List<DoctorAppointmentItem> appointments;
  final List<DoctorBookedSlot> bookedSlots;
  final String activeFilter;
  final bool isLoading;
  final bool isLoadingBookedSlots;
  final bool isSubmitting;
  final String? errorMessage;

  @override
  List<Object?> get props => [
    appointments,
    bookedSlots,
    activeFilter,
    isLoading,
    isLoadingBookedSlots,
    isSubmitting,
    errorMessage,
  ];

  PatientAppointmentsState copyWith({
    List<DoctorAppointmentItem>? appointments,
    List<DoctorBookedSlot>? bookedSlots,
    String? activeFilter,
    bool? isLoading,
    bool? isLoadingBookedSlots,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PatientAppointmentsState(
      appointments: appointments ?? this.appointments,
      bookedSlots: bookedSlots ?? this.bookedSlots,
      activeFilter: activeFilter ?? this.activeFilter,
      isLoading: isLoading ?? this.isLoading,
      isLoadingBookedSlots: isLoadingBookedSlots ?? this.isLoadingBookedSlots,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PatientAppointmentsCubit extends Cubit<PatientAppointmentsState> {
  PatientAppointmentsCubit._(
    this._repo,
    this._authCubit,
    this._preferences,
    String initialFilter,
  ) : super(PatientAppointmentsState(activeFilter: initialFilter));

  final PatientAppointmentsRepo _repo;
  final AuthCubit _authCubit;
  final SharedPreferences _preferences;

  static const String _appointmentsFilterPreferenceKey =
      'appointments_active_filter';

  static Future<PatientAppointmentsCubit> create({
    required AuthCubit authCubit,
    String baseUrl = AuthCubit.defaultApiBaseUrl,
  }) async {
    final repo = PatientAppointmentsRepo(mainRepo: MainRepo(baseUrl: baseUrl));
    final preferences = await SharedPreferences.getInstance();
    final savedFilter = preferences
        .getString(_appointmentsFilterPreferenceKey)
        ?.toUpperCase();
    final initialFilter = supportedFilters.contains(savedFilter)
        ? savedFilter!
        : 'ALL';
    return PatientAppointmentsCubit._(
      repo,
      authCubit,
      preferences,
      initialFilter,
    );
  }

  static const List<String> supportedFilters = [
    'ALL',
    'PENDING',
    'CREATED',
    'CONFIRMED',
    'CANCELED',
    'UPCOMING',
    'ACCEPTED',
  ];

  Future<bool> createAppointmentRequest(
    CreatePatientAppointmentRequest request,
  ) async {
    if (state.isSubmitting) return false;

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Missing access token.',
        ),
      );
      return false;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      await _withRefreshRetry(
        (accessToken) => _repo.createAppointmentRequest(accessToken, request),
      );
      emit(state.copyWith(isSubmitting: false, clearError: true));
      await loadAppointments(filter: state.activeFilter, forceRefresh: true);
      return true;
    } on ApiException catch (e) {
      final message = e.statusCode == 409
          ? 'Selected time is already booked'
          : e.message;
      emit(state.copyWith(isSubmitting: false, errorMessage: message));
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Failed to create appointment request.',
        ),
      );
      return false;
    }
  }

  Future<bool> updateAppointment({
    required String appointmentId,
    required UpdatePatientAppointmentRequest request,
  }) async {
    if (state.isSubmitting) return false;

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Missing access token.',
        ),
      );
      return false;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      await _withRefreshRetry(
        (accessToken) => _repo.updateAppointment(
          accessToken,
          appointmentId: appointmentId,
          request: request,
        ),
      );
      emit(state.copyWith(isSubmitting: false, clearError: true));
      await loadAppointments(filter: state.activeFilter, forceRefresh: true);
      return true;
    } on ApiException catch (e) {
      final message = e.statusCode == 409
          ? 'Selected time is already booked'
          : e.message;
      emit(state.copyWith(isSubmitting: false, errorMessage: message));
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Failed to update appointment.',
        ),
      );
      return false;
    }
  }

  Future<bool> deleteAppointment({required String appointmentId}) async {
    if (state.isSubmitting) return false;

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Missing access token.',
        ),
      );
      return false;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      await _withRefreshRetry(
        (accessToken) =>
            _repo.deleteAppointment(accessToken, appointmentId: appointmentId),
      );
      emit(state.copyWith(isSubmitting: false, clearError: true));
      await loadAppointments(filter: state.activeFilter, forceRefresh: true);
      return true;
    } on ApiException catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Failed to delete appointment.',
        ),
      );
      return false;
    }
  }

  Future<bool> respondToPendingAppointment({
    required String appointmentId,
    required String action,
  }) async {
    if (state.isSubmitting) return false;

    final normalizedAction = action.toLowerCase();
    if (normalizedAction != 'approve' && normalizedAction != 'reject') {
      emit(
        state.copyWith(errorMessage: 'Invalid action. Use approve or reject.'),
      );
      return false;
    }

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Missing access token.',
        ),
      );
      return false;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      await _withRefreshRetry(
        (accessToken) => _repo.respondToPendingAppointment(
          accessToken,
          appointmentId: appointmentId,
          action: normalizedAction,
        ),
      );
      emit(state.copyWith(isSubmitting: false, clearError: true));
      await loadAppointments(filter: state.activeFilter, forceRefresh: true);
      return true;
    } on ApiException catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Failed to submit appointment response.',
        ),
      );
      return false;
    }
  }

  Future<void> loadAppointments({
    String filter = 'ALL',
    bool forceRefresh = false,
  }) async {
    final normalizedFilter = filter.toUpperCase();
    if (!supportedFilters.contains(normalizedFilter)) return;
    if (state.isLoading && !forceRefresh) return;

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(isLoading: false, errorMessage: 'Missing access token.'),
      );
      return;
    }

    emit(
      state.copyWith(
        isLoading: true,
        activeFilter: normalizedFilter,
        clearError: true,
      ),
    );
    await _preferences.setString(
      _appointmentsFilterPreferenceKey,
      normalizedFilter,
    );

    try {
      final appointments = await _withRefreshRetry((accessToken) {
        switch (normalizedFilter) {
          case 'ACCEPTED':
          case 'CONFIRMED':
            return _repo.fetchAcceptedAppointments(accessToken);
          case 'CREATED':
            return _repo.fetchCreatedAppointments(accessToken);
          case 'CANCELED':
            return _repo.fetchCanceledAppointments(accessToken);
          case 'PENDING':
            return _repo.fetchPendingAppointments(accessToken);
          case 'UPCOMING':
            return _repo.fetchUpcomingAppointments(accessToken);
          case 'ALL':
          default:
            return _repo.fetchAppointments(accessToken, status: 'ALL');
        }
      });

      emit(
        state.copyWith(
          appointments: appointments,
          isLoading: false,
          activeFilter: normalizedFilter,
          clearError: true,
        ),
      );
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          activeFilter: normalizedFilter,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          activeFilter: normalizedFilter,
          errorMessage: 'Failed to load appointments.',
        ),
      );
    }
  }

  Future<void> loadBookedSlotsForRange({
    required String fromDate,
    required String toDate,
  }) async {
    if (state.isLoadingBookedSlots) return;

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          isLoadingBookedSlots: false,
          errorMessage: 'Missing access token.',
        ),
      );
      return;
    }

    emit(state.copyWith(isLoadingBookedSlots: true, clearError: true));

    try {
      final slots = await _withRefreshRetry(
        (accessToken) => _repo.fetchBookedSlotsByRange(
          accessToken,
          fromDate: fromDate,
          toDate: toDate,
        ),
      );

      emit(
        state.copyWith(
          bookedSlots: slots,
          isLoadingBookedSlots: false,
          clearError: true,
        ),
      );
    } on ApiException catch (e) {
      emit(
        state.copyWith(isLoadingBookedSlots: false, errorMessage: e.message),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoadingBookedSlots: false,
          errorMessage: 'Failed to load booked slots.',
        ),
      );
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

  @override
  Future<void> close() {
    _repo.close();
    return super.close();
  }
}
