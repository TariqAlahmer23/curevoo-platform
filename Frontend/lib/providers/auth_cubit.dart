import 'package:curevoo_doctor/models/doctor.dart';
import 'package:curevoo_doctor/repos/auth_repo.dart';
import 'package:curevoo_doctor/repos/auth_token_storage.dart';
import 'package:curevoo_doctor/repos/main_repo.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
}

class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.doctor,
    this.token,
    this.isBusy = false,
    this.errorMessage,
  });

  const AuthState.unknown()
      : status = AuthStatus.unknown,
        doctor = null,
        token = null,
        isBusy = false,
        errorMessage = null;

  final AuthStatus status;
  final Doctor? doctor;
  final String? token;
  final bool isBusy;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  @override
  List<Object?> get props => [
    status,
    doctor,
    token,
    isBusy,
    errorMessage,
  ];

  AuthState copyWith({
    AuthStatus? status,
    Doctor? doctor,
    String? token,
    bool? isBusy,
    String? errorMessage,
    bool clearDoctor = false,
    bool clearToken = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      doctor: clearDoctor ? null : (doctor ?? this.doctor),
      token: clearToken ? null : (token ?? this.token),
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit._(
    this._authRepo,
    this._tokenStorage,
  ) : super(const AuthState.unknown());

  // ignore: use_super_parameters
  AuthCubit.testing(AuthState initialState)
      : _authRepo = AuthRepo(
          mainRepo: MainRepo(baseUrl: defaultApiBaseUrl),
        ),
        _tokenStorage = AuthTokenStorage(),
        super(initialState);

  static const String defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://curevoo.talents-we-trust.tech/api',
  );

  final AuthRepo _authRepo;
  final AuthTokenStorage _tokenStorage;

  static Future<AuthCubit> create({String baseUrl = defaultApiBaseUrl}) async {
    final repo = AuthRepo(mainRepo: MainRepo(baseUrl: baseUrl));
    final cubit = AuthCubit._(repo, AuthTokenStorage());
    await cubit.initialize();
    return cubit;
  }

  Future<void> initialize() async {
    emit(state.copyWith(isBusy: true, clearError: true));
    final rememberMe = await _tokenStorage.readRememberMe();
    if (!rememberMe) {
      await _clearSession();
      return;
    }

    final token = await _tokenStorage.readToken();
    final storedDoctor = await _tokenStorage.readDoctor();

    if (token == null || token.isEmpty) {
      await _tokenStorage.clearDoctor();
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          isBusy: false,
          clearDoctor: true,
          clearToken: true,
          clearError: true,
        ),
      );
      return;
    }

    try {
      final response = await _authRepo.validateToken(token);
      final activeToken = response.token ?? token;
      final doctor = _mergeDoctor(response.doctor, storedDoctor);
      await _tokenStorage.saveToken(activeToken);
      await _tokenStorage.saveDoctor(doctor);
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          doctor: doctor,
          token: activeToken,
          isBusy: false,
          clearError: true,
        ),
      );
    } catch (_) {
      final refreshed = await _refreshSession(
        storedDoctor: storedDoctor,
        isBusy: false,
      );
      if (!refreshed) {
        await _clearSession(
          errorMessage: 'Session expired. Please login again.',
        );
      }
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    emit(state.copyWith(isBusy: true, clearError: true));

    try {
      final response = await _authRepo.login(email: email, password: password);
      if (response.token == null || response.token!.isEmpty) {
        throw Exception('No token returned from login.');
      }

      await _tokenStorage.saveRememberMe(rememberMe);
      await _tokenStorage.saveToken(response.token!);
      await _tokenStorage.saveDoctor(response.doctor);
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          doctor: response.doctor,
          token: response.token,
          isBusy: false,
          clearError: true,
        ),
      );
      return true;
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          isBusy: false,
          clearDoctor: true,
          clearToken: true,
          errorMessage: e.message,
        ),
      );
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          isBusy: false,
          clearDoctor: true,
          clearToken: true,
          errorMessage: 'Login failed. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<bool> signup(Map<String, dynamic> payload) async {
    emit(state.copyWith(isBusy: true, clearError: true));

    try {
      final response = await _authRepo.signup(payload);
      final token = response.token;

      if (token != null && token.isNotEmpty) {
        await _tokenStorage.saveToken(token);
        await _tokenStorage.saveDoctor(response.doctor);
        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            doctor: response.doctor,
            token: token,
            isBusy: false,
            clearError: true,
          ),
        );
        return true;
      }

      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          isBusy: false,
          clearDoctor: true,
          clearToken: true,
          clearError: true,
        ),
      );
      return true;
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          isBusy: false,
          clearDoctor: true,
          clearToken: true,
          errorMessage: e.message,
        ),
      );
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          isBusy: false,
          clearDoctor: true,
          clearToken: true,
          errorMessage: 'Signup failed. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<void> logout() async {
    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        isBusy: true,
        clearDoctor: true,
        clearToken: true,
        clearError: true,
      ),
    );
    try {
      await _authRepo.logout();
    } catch (_) {
      // Always clear the local session even if the server-side logout fails.
    }
    await _clearSession();
  }

  Future<bool> readRememberMePreference() async {
    return _tokenStorage.readRememberMe();
  }

  Future<bool> deleteAccount() async {
    final token = state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          isBusy: false,
          clearDoctor: true,
          clearToken: true,
          errorMessage: 'Missing access token.',
        ),
      );
      return false;
    }

    emit(state.copyWith(isBusy: true, clearError: true));

    try {
      await _authRepo.deleteAccount(token);
      await _clearSession();
      return true;
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          isBusy: false,
          errorMessage: e.message,
        ),
      );
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isBusy: false,
          errorMessage: 'Failed to delete account. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          isBusy: false,
          clearDoctor: true,
          clearToken: true,
          errorMessage: 'Missing access token.',
        ),
      );
      return false;
    }

    emit(state.copyWith(isBusy: true, clearError: true));

    try {
      await _authRepo.changePassword(
        token,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      emit(
        state.copyWith(
          isBusy: false,
          clearError: true,
        ),
      );
      return true;
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          isBusy: false,
          errorMessage: e.message,
        ),
      );
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isBusy: false,
          errorMessage: 'Failed to change password. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<void> updateDoctor(Doctor doctor) async {
    await _tokenStorage.saveDoctor(doctor);
    emit(
      state.copyWith(
        doctor: doctor,
        clearError: true,
      ),
    );
  }

  Doctor _mergeDoctor(Doctor remoteDoctor, Doctor? storedDoctor) {
    if (storedDoctor == null) return remoteDoctor;
    if (storedDoctor.id.isEmpty || remoteDoctor.id.isEmpty) return storedDoctor;
    if (storedDoctor.id != remoteDoctor.id) return remoteDoctor;
    return storedDoctor;
  }

  Future<bool> refreshSession() async {
    return _refreshSession(
      storedDoctor: state.doctor ?? await _tokenStorage.readDoctor(),
      isBusy: false,
      clearOnFailure: true,
    );
  }

  Future<bool> _refreshSession({
    required Doctor? storedDoctor,
    required bool isBusy,
    bool clearOnFailure = false,
  }) async {
    try {
      final refreshedToken = await _authRepo.refreshAccessToken();
      final response = await _authRepo.validateToken(refreshedToken);
      final doctor = _mergeDoctor(response.doctor, storedDoctor);
      final activeToken = response.token ?? refreshedToken;

      await _tokenStorage.saveToken(activeToken);
      await _tokenStorage.saveDoctor(doctor);
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          doctor: doctor,
          token: activeToken,
          isBusy: isBusy,
          clearError: true,
        ),
      );
      return true;
    } on ApiException catch (e) {
      if (clearOnFailure || _isSecuritySessionFailure(e)) {
        await _clearSession(
          errorMessage: _isSecuritySessionFailure(e)
              ? 'Session security check failed. Please login again.'
              : 'Session expired. Please login again.',
        );
      }
      return false;
    } catch (_) {
      if (clearOnFailure) {
        await _clearSession(
          errorMessage: 'Session expired. Please login again.',
        );
      }
      return false;
    }
  }

  bool _isSecuritySessionFailure(ApiException e) {
    if (e.statusCode != 403) return false;
    final code = _extractErrorCode(e.data);
    return code == 'CSRF_INVALID' || code == 'CORS_FORBIDDEN';
  }

  String? _extractErrorCode(dynamic data) {
    if (data is! Map) return null;
    final typed = data.map((key, dynamic value) => MapEntry('$key', value));
    final directCode = typed['code'];
    if (directCode is String && directCode.trim().isNotEmpty) {
      return directCode.trim().toUpperCase();
    }
    final nestedError = typed['error'];
    if (nestedError is Map) {
      final nestedTyped = nestedError.map(
        (key, dynamic value) => MapEntry('$key', value),
      );
      final nestedCode = nestedTyped['code'];
      if (nestedCode is String && nestedCode.trim().isNotEmpty) {
        return nestedCode.trim().toUpperCase();
      }
    }
    return null;
  }

  Future<void> _clearSession({String? errorMessage}) async {
    await _tokenStorage.clearToken();
    await _tokenStorage.clearDoctor();
    await MainRepo.clearSessionCookies();
    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        isBusy: false,
        clearDoctor: true,
        clearToken: true,
        clearError: errorMessage == null,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  Future<void> close() {
    _authRepo.close();
    return super.close();
  }
}
