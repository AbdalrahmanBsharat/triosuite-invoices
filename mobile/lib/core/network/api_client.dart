import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import '../storage/secure_store.dart';
import 'api_exception.dart';

/// The single HTTP entry point for the whole app.
///
/// Two things are worth knowing about it.
///
/// **The access token is attached here, once.** No screen or repository ever builds an
/// `Authorization` header, so there is exactly one place a token can leak from or be forgotten.
///
/// **A `401` triggers one single-flight refresh.** If five requests are in the air when the access
/// token expires, they do not each start their own refresh — the first one starts it, the rest wait
/// for the same future, and all five are then retried with the new token. Rotating refresh tokens
/// make that ordering matter: a second concurrent refresh would present a token the first had
/// already revoked and log the user out for no reason.
class ApiClient {
  ApiClient(this._store, {required String baseUrl})
      : _dio = Dio(_optionsFor(baseUrl)),
        _refreshDio = Dio(_optionsFor(baseUrl)) {
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );

    if (kDebugMode) {
      // Debug builds only: the logger prints headers, and one of them is a bearer token.
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: false,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          compact: true,
          maxWidth: 100,
        ),
      );
    }
  }

  /// Marks a request that has already been retried after a refresh, so a second `401` gives up
  /// rather than looping.
  static const String _retriedKey = 'triosuite.retried';

  final SecureStore _store;

  /// Invoked when a refresh fails and the session is genuinely over.
  ///
  /// Set by the auth controller once it exists, rather than injected here: the controller needs a
  /// client to make requests with, so passing itself to the constructor would be circular.
  Future<void> Function()? onSessionExpired;

  final Dio _dio;

  /// A bare client with no interceptors, used only to call the refresh endpoint. Sending that
  /// request through [_dio] would let its own `401` re-enter the refresh logic.
  final Dio _refreshDio;

  Future<bool>? _refreshInFlight;

  static BaseOptions _optionsFor(String baseUrl) => BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: Headers.jsonContentType,
        // Let every status through to the error handler so problem documents are parsed by
        // ApiException rather than swallowed by Dio's default validation.
        validateStatus: (status) => status != null && status < 500,
      );

  String get baseUrl => _dio.options.baseUrl;

  /// Retargets the client, for the API address override on the Settings screen.
  void setBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
    _refreshDio.options.baseUrl = baseUrl;
  }

  // -------------------------------------------------------------------------------------
  // Verbs
  // -------------------------------------------------------------------------------------

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) =>
      _send(() => _dio.post<dynamic>(path, data: body));

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _dio.put<dynamic>(path, data: body));

  /// Probes `/actuator/health` with a long timeout, tolerating a backend that is still waking up.
  ///
  /// Returns true only for a reported status of `UP`. Never throws: the caller wants a yes or no,
  /// not an exception to translate.
  Future<bool> checkHealth({String? baseUrlOverride}) async {
    final probe = Dio(BaseOptions(
      baseUrl: baseUrlOverride ?? baseUrl,
      connectTimeout: AppConfig.healthCheckTimeout,
      receiveTimeout: AppConfig.healthCheckTimeout,
      validateStatus: (status) => status != null && status < 500,
    ));
    try {
      final response = await probe.get<dynamic>('/actuator/health');
      final data = response.data;
      return response.statusCode == 200 &&
          data is Map &&
          data['status'] == 'UP';
    } on DioException {
      return false;
    } finally {
      probe.close(force: true);
    }
  }

  /// Runs a request and converts anything that goes wrong into an [ApiException].
  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return response.data;
      }
      throw ApiException.fromDio(DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      ));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  // -------------------------------------------------------------------------------------
  // Interceptors
  // -------------------------------------------------------------------------------------

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isAuthEndpoint(options.path)) {
      final token = await _store.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final options = error.requestOptions;
    final isRetryable = error.response?.statusCode == 401 &&
        !_isAuthEndpoint(options.path) &&
        options.extra[_retriedKey] != true;

    if (!isRetryable) {
      handler.next(error);
      return;
    }

    final refreshed = await _refreshOnce();
    if (!refreshed) {
      await onSessionExpired?.call();
      handler.next(error);
      return;
    }

    try {
      options.extra[_retriedKey] = true;
      final token = await _store.readAccessToken();
      options.headers['Authorization'] = 'Bearer $token';
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Refreshes the token pair, collapsing concurrent callers onto one request.
  Future<bool> _refreshOnce() {
    return _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _store.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _refreshDio.post<dynamic>(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data;
      if (response.statusCode != 200 || data is! Map<String, dynamic>) {
        return false;
      }

      await _store.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } on DioException {
      return false;
    }
  }

  /// Login and refresh must never carry a bearer token, and must never trigger a refresh.
  static bool _isAuthEndpoint(String path) =>
      path.endsWith('/api/auth/login') || path.endsWith('/api/auth/refresh');
}
