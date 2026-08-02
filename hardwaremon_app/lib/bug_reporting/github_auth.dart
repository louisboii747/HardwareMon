import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

final class GitHubBugReportingConfig {
  const GitHubBugReportingConfig({
    required this.clientId,
    required this.repositoryOwner,
    required this.repositoryName,
    this.apiBaseUrl = 'https://api.github.com',
    this.webBaseUrl = 'https://github.com',
  });

  factory GitHubBugReportingConfig.production() =>
      const GitHubBugReportingConfig(
        clientId: String.fromEnvironment('HARDWAREMON_GITHUB_CLIENT_ID'),
        repositoryOwner: String.fromEnvironment(
          'HARDWAREMON_GITHUB_OWNER',
          defaultValue: 'louisboii747',
        ),
        repositoryName: String.fromEnvironment(
          'HARDWAREMON_GITHUB_REPO',
          defaultValue: 'HardwareMon',
        ),
      );

  final String clientId;
  final String repositoryOwner;
  final String repositoryName;
  final String apiBaseUrl;
  final String webBaseUrl;
  bool get isConfigured => clientId.trim().isNotEmpty;
  String get repositorySlug => '$repositoryOwner/$repositoryName';
  String get configurationMessage => isConfigured
      ? ''
      : kDebugMode
      ? 'Set HARDWAREMON_GITHUB_CLIENT_ID with --dart-define. Owner=$repositoryOwner, repository=$repositoryName.'
      : 'GitHub reporting is not configured in this build.';
}

enum GitHubAuthStatus {
  unknown,
  signedOut,
  requestingDeviceCode,
  waitingForAuthorization,
  signedIn,
  validating,
  expiredOrRevoked,
  failed,
}

class GitHubUser {
  const GitHubUser({required this.login, this.avatarUrl});
  final String login;
  final String? avatarUrl;
  factory GitHubUser.fromJson(Map<String, dynamic> json) => GitHubUser(
    login: json['login'] as String,
    avatarUrl: json['avatar_url'] as String?,
  );
}

class GitHubAuthState {
  const GitHubAuthState(this.status, {this.user, this.message});
  final GitHubAuthStatus status;
  final GitHubUser? user;
  final String? message;
}

class GitHubDeviceAuthorization {
  const GitHubDeviceAuthorization({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresAt,
    required this.interval,
  });
  final String deviceCode;
  final String userCode;
  final Uri verificationUri;
  final DateTime expiresAt;
  final Duration interval;

  factory GitHubDeviceAuthorization.fromJson(
    Map<String, dynamic> json,
    DateTime now,
  ) => GitHubDeviceAuthorization(
    deviceCode: json['device_code'] as String,
    userCode: json['user_code'] as String,
    verificationUri: Uri.parse(json['verification_uri'] as String),
    expiresAt: now.add(Duration(seconds: json['expires_in'] as int)),
    interval: Duration(seconds: json['interval'] as int? ?? 5),
  );
}

class GitHubAuthenticationResult {
  const GitHubAuthenticationResult({required this.user});
  final GitHubUser user;
}

abstract interface class SecureTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class PlatformSecureTokenStore implements SecureTokenStore {
  const PlatformSecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  static const _key = 'hardwaremon.github.oauth_token';
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}

class GitHubApiException implements Exception {
  const GitHubApiException(
    this.message, {
    this.statusCode,
    this.documentationUrl,
    this.retryAt,
    this.ambiguous = false,
  });
  final String message;
  final int? statusCode;
  final String? documentationUrl;
  final DateTime? retryAt;
  final bool ambiguous;
  @override
  String toString() => message;
}

class GitHubApiClient {
  GitHubApiClient({required this.config, http.Client? client})
    : client = client ?? http.Client();
  final GitHubBugReportingConfig config;
  final http.Client client;

  Map<String, String> headers([String? token]) => {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'HardwareMon-Bug-Reporter',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Uri apiUri(String path, [Map<String, String>? query]) =>
      Uri.parse(config.apiBaseUrl).replace(path: path, queryParameters: query);

  Future<Map<String, dynamic>> getJson(String path, String token) async {
    try {
      final response = await client
          .get(apiUri(path), headers: headers(token))
          .timeout(const Duration(seconds: 20));
      return parseObject(response);
    } on TimeoutException {
      throw const GitHubApiException('GitHub did not respond in time.');
    }
  }

  Map<String, dynamic> parseObject(http.Response response) {
    Map<String, dynamic> body = {};
    try {
      body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {}
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    final reset = int.tryParse(response.headers['x-ratelimit-reset'] ?? '');
    throw GitHubApiException(
      _safeMessage(response.statusCode, body['message']?.toString()),
      statusCode: response.statusCode,
      documentationUrl: body['documentation_url']?.toString(),
      retryAt: reset == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(reset * 1000, isUtc: true),
    );
  }

  String _safeMessage(int status, String? apiMessage) => switch (status) {
    401 => 'GitHub authorization expired or was revoked.',
    403 => 'GitHub denied this request or the API rate limit was reached.',
    404 => 'The configured repository was not found or is not accessible.',
    410 => 'GitHub Issues are disabled for this repository.',
    422 => 'GitHub rejected the issue content.',
    429 => 'GitHub rate limited this request.',
    >= 500 => 'GitHub is temporarily unavailable.',
    _ =>
      apiMessage == null
          ? 'GitHub request failed ($status).'
          : 'GitHub request failed: $apiMessage',
  };
}

abstract interface class GitHubAuthService {
  Future<GitHubAuthState> getAuthState();
  Stream<GitHubAuthState> watchAuthState();
  Future<GitHubDeviceAuthorization> beginDeviceAuthorization();
  Future<GitHubAuthenticationResult> waitForAuthorization(
    GitHubDeviceAuthorization authorization,
  );
  Future<GitHubUser> getAuthenticatedUser();
  Future<String?> getValidAccessToken();
  Future<void> signOut();
  void cancelAuthorization();
}

class GitHubDeviceFlowAuthService implements GitHubAuthService {
  GitHubDeviceFlowAuthService({
    required this.config,
    required this.api,
    SecureTokenStore? tokenStore,
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  }) : tokenStore = tokenStore ?? const PlatformSecureTokenStore(),
       now = now ?? DateTime.now,
       delay = delay ?? Future.delayed;

  final GitHubBugReportingConfig config;
  final GitHubApiClient api;
  final SecureTokenStore tokenStore;
  final DateTime Function() now;
  final Future<void> Function(Duration) delay;
  final _states = StreamController<GitHubAuthState>.broadcast();
  GitHubAuthState _state = const GitHubAuthState(GitHubAuthStatus.unknown);
  bool _cancelled = false;

  void _emit(GitHubAuthState state) {
    _state = state;
    _states.add(state);
  }

  @override
  Stream<GitHubAuthState> watchAuthState() => _states.stream;

  @override
  Future<GitHubAuthState> getAuthState() async {
    final token = await tokenStore.read();
    if (token == null) {
      _emit(const GitHubAuthState(GitHubAuthStatus.signedOut));
      return _state;
    }
    _emit(const GitHubAuthState(GitHubAuthStatus.validating));
    try {
      final user = await getAuthenticatedUser();
      _emit(GitHubAuthState(GitHubAuthStatus.signedIn, user: user));
    } on GitHubApiException catch (error) {
      if (error.statusCode == 401) {
        await tokenStore.delete();
        _emit(
          GitHubAuthState(
            GitHubAuthStatus.expiredOrRevoked,
            message: error.message,
          ),
        );
      } else {
        _emit(GitHubAuthState(GitHubAuthStatus.failed, message: error.message));
      }
    }
    return _state;
  }

  @override
  Future<GitHubDeviceAuthorization> beginDeviceAuthorization() async {
    if (!config.isConfigured) {
      throw GitHubApiException(config.configurationMessage);
    }
    _cancelled = false;
    _emit(const GitHubAuthState(GitHubAuthStatus.requestingDeviceCode));
    final response = await api.client
        .post(
          Uri.parse('${config.webBaseUrl}/login/device/code'),
          headers: api.headers()..['Content-Type'] = 'application/json',
          body: jsonEncode({
            'client_id': config.clientId,
            'scope': 'public_repo',
          }),
        )
        .timeout(const Duration(seconds: 20));
    final data = api.parseObject(response);
    final authorization = GitHubDeviceAuthorization.fromJson(data, now());
    _emit(const GitHubAuthState(GitHubAuthStatus.waitingForAuthorization));
    return authorization;
  }

  @override
  Future<GitHubAuthenticationResult> waitForAuthorization(
    GitHubDeviceAuthorization authorization,
  ) async {
    var interval = authorization.interval;
    while (!_cancelled && now().isBefore(authorization.expiresAt)) {
      await delay(interval);
      if (_cancelled) {
        throw const GitHubApiException('GitHub sign-in was cancelled.');
      }
      final response = await api.client
          .post(
            Uri.parse('${config.webBaseUrl}/login/oauth/access_token'),
            headers: api.headers()..['Content-Type'] = 'application/json',
            body: jsonEncode({
              'client_id': config.clientId,
              'device_code': authorization.deviceCode,
              'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
            }),
          )
          .timeout(const Duration(seconds: 20));
      final data = api.parseObject(response);
      final error = data['error']?.toString();
      if (error == 'authorization_pending') continue;
      if (error == 'slow_down') {
        interval += const Duration(seconds: 5);
        continue;
      }
      if (error == 'expired_token') {
        throw const GitHubApiException('The GitHub device code expired.');
      }
      if (error == 'access_denied') {
        throw const GitHubApiException('GitHub sign-in was denied.');
      }
      final token = data['access_token']?.toString();
      if (token == null || token.isEmpty) {
        throw const GitHubApiException(
          'GitHub returned an invalid authorization response.',
        );
      }
      await tokenStore.write(token);
      final user = await getAuthenticatedUser();
      _emit(GitHubAuthState(GitHubAuthStatus.signedIn, user: user));
      return GitHubAuthenticationResult(user: user);
    }
    throw const GitHubApiException('The GitHub device code expired.');
  }

  @override
  Future<GitHubUser> getAuthenticatedUser() async {
    final token = await tokenStore.read();
    if (token == null) {
      throw const GitHubApiException(
        'GitHub sign-in is required.',
        statusCode: 401,
      );
    }
    return GitHubUser.fromJson(await api.getJson('/user', token));
  }

  @override
  Future<String?> getValidAccessToken() async {
    final state = await getAuthState();
    return state.status == GitHubAuthStatus.signedIn ? tokenStore.read() : null;
  }

  @override
  Future<void> signOut() async {
    await tokenStore.delete();
    _emit(const GitHubAuthState(GitHubAuthStatus.signedOut));
  }

  @override
  void cancelAuthorization() => _cancelled = true;
}
