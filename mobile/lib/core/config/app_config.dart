/// Where the app looks for the API, and how long it is prepared to wait.
///
/// The base URL is resolved in three steps, most specific first:
///
/// 1. an override the user typed on the Settings screen, stored on the device;
/// 2. the value compiled in with `--dart-define=API_BASE_URL=...`;
/// 3. [defaultBaseUrl], which points at the Android emulator's alias for the host machine.
///
/// The override exists so a reviewer can retarget the app without rebuilding it — if the hosted
/// backend is unreachable they can point the app at their own machine and carry on.
abstract final class AppConfig {
  const AppConfig._();

  /// `10.0.2.2` is how the Android emulator reaches `localhost` on the host machine.
  static const String defaultBaseUrl = 'http://10.0.2.2:8080';

  /// Compiled in at build time; empty unless `--dart-define=API_BASE_URL` was passed.
  static const String compiledBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// The base URL to use when the device holds no override.
  static String get buildTimeBaseUrl =>
      compiledBaseUrl.isEmpty ? defaultBaseUrl : compiledBaseUrl;

  /// Ordinary request timeouts.
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Timeout for the start-up health probe.
  ///
  /// Generous on purpose: a free-tier host sleeps after fifteen minutes idle and a JVM cold
  /// start takes the better part of a minute. Failing fast here would show the reviewer an
  /// error for a backend that is merely waking up.
  static const Duration healthCheckTimeout = Duration(seconds: 70);

  /// How many rows a list screen fetches at a time.
  static const int pageSize = 20;

  /// Pause between the last keystroke and a search request.
  static const Duration searchDebounce = Duration(milliseconds: 350);
}
