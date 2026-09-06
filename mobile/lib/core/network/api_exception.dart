import 'dart:io';

import 'package:dio/dio.dart';

/// The stable error identifiers the API returns in the `code` property of its problem documents.
///
/// The app branches on these, never on the human-readable message, which is free to change.
enum ApiErrorCode {
  validationError('VALIDATION_ERROR'),
  notFound('NOT_FOUND'),
  unauthorized('UNAUTHORIZED'),
  forbidden('FORBIDDEN'),
  invoiceNotEditable('INVOICE_NOT_EDITABLE'),
  invalidTransition('INVALID_TRANSITION'),
  staleVersion('STALE_VERSION'),
  rateLimited('RATE_LIMITED'),
  internalError('INTERNAL_ERROR'),

  /// The request never reached the server, or the reply was not a problem document.
  network('NETWORK');

  const ApiErrorCode(this.wireName);

  final String wireName;

  static ApiErrorCode fromWire(String? wireName) {
    for (final code in ApiErrorCode.values) {
      if (code.wireName == wireName) {
        return code;
      }
    }
    return ApiErrorCode.internalError;
  }
}

/// One rejected field, from the `errors` array of a validation problem document.
class FieldError {
  const FieldError({required this.field, required this.message});

  final String field;
  final String message;

  @override
  String toString() => '$field $message';
}

/// Every failure the app shows a user, in one shape.
///
/// Built from RFC 9457 problem documents where the server sent one, and from Dio's own failures
/// otherwise. [message] is always safe and meaningful to display; screens that need to react to a
/// specific outcome — a stale version, a barcode that matched nothing — switch on [code].
class ApiException implements Exception {
  ApiException({
    required this.code,
    required this.message,
    this.status,
    this.fieldErrors = const [],
    this.retryAfterSeconds,
  });

  final ApiErrorCode code;
  final String message;
  final int? status;
  final List<FieldError> fieldErrors;
  final int? retryAfterSeconds;

  bool get isUnauthorized => code == ApiErrorCode.unauthorized;
  bool get isNotFound => code == ApiErrorCode.notFound;
  bool get isStaleVersion => code == ApiErrorCode.staleVersion;
  bool get isNetwork => code == ApiErrorCode.network;

  /// Translates a Dio failure into something worth putting in front of a user.
  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    final data = response?.data;

    if (data is Map<String, dynamic> && data['code'] is String) {
      return ApiException(
        code: ApiErrorCode.fromWire(data['code'] as String),
        message: _detailOf(data),
        status: response?.statusCode,
        fieldErrors: _fieldErrorsOf(data),
        retryAfterSeconds: _retryAfterOf(response),
      );
    }

    // No problem document: either the transport failed or something in front of the API
    // answered instead. Neither gives us anything a user can act on beyond "try again".
    return ApiException(
      code: ApiErrorCode.network,
      message: _transportMessage(error),
      status: response?.statusCode,
    );
  }

  static String _detailOf(Map<String, dynamic> problem) {
    final detail = problem['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    final title = problem['title'];
    if (title is String && title.isNotEmpty) {
      return title;
    }
    return 'The server rejected the request.';
  }

  static List<FieldError> _fieldErrorsOf(Map<String, dynamic> problem) {
    final errors = problem['errors'];
    if (errors is! List) {
      return const [];
    }
    return errors
        .whereType<Map<String, dynamic>>()
        .map((entry) => FieldError(
              field: entry['field'] as String? ?? '',
              message: entry['message'] as String? ?? '',
            ))
        .toList(growable: false);
  }

  static int? _retryAfterOf(Response<dynamic>? response) {
    final header = response?.headers.value('retry-after');
    return header == null ? null : int.tryParse(header);
  }

  static String _transportMessage(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout =>
        'The server is taking too long to respond. It may be waking up — try again in a moment.',
      DioExceptionType.receiveTimeout =>
        'The server started replying but did not finish. Try again.',
      DioExceptionType.badCertificate =>
        'The server presented a certificate that could not be verified.',
      DioExceptionType.cancel => 'The request was cancelled.',
      DioExceptionType.badResponse =>
        'The server returned an unexpected response (${error.response?.statusCode}).',
      DioExceptionType.transformTimeout =>
        'The reply was too large to process. Try narrowing the search.',
      DioExceptionType.connectionError || DioExceptionType.unknown => _unreachableMessage(error),
    };
  }

  /// The request never left the device, or nothing answered it.
  ///
  /// A wrong API address is by far the likeliest cause on a reviewer's machine, so the message
  /// points at the Settings screen where it can be corrected.
  static String _unreachableMessage(DioException error) {
    final host = error.requestOptions.uri.host;
    final where = host.isEmpty ? 'the server' : host;
    if (error.error is SocketException) {
      return 'Cannot reach $where. Check your connection, and the API address in Settings.';
    }
    return 'Something went wrong talking to $where. Try again, or check the API address in Settings.';
  }

  @override
  String toString() => 'ApiException(${code.wireName}: $message)';
}
