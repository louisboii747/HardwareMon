import 'dart:io';

class BackendConfig {
  static final String baseUrl = Platform.isLinux
      ? 'http://127.0.0.1:5000'
      : 'http://127.0.0.1:8000';
}
