import 'dart:convert';
import 'dart:io';

class ReportRedactor {
  ReportRedactor({Map<String, String>? environment})
    : environment = environment ?? Platform.environment;
  final Map<String, String> environment;

  String redact(String input) {
    var value = input.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');
    final home = environment['USERPROFILE'] ?? environment['HOME'];
    if (home != null && home.length > 3) {
      value = value.replaceAll(home, '<HOME>');
    }
    for (final entry in environment.entries) {
      if (RegExp(
            r'(TOKEN|SECRET|PASSWORD|API_KEY|PRIVATE_KEY)',
            caseSensitive: false,
          ).hasMatch(entry.key) &&
          entry.value.length >= 6) {
        value = value.replaceAll(entry.value, '<TOKEN_REDACTED>');
      }
    }
    return value
        .replaceAll(
          RegExp(
            r'authorization\s*[:=]\s*(?:bearer\s+)?[^\s,;]+',
            caseSensitive: false,
          ),
          'Authorization: <TOKEN_REDACTED>',
        )
        .replaceAll(
          RegExp(r'bearer\s+[a-z0-9_.-]{12,}', caseSensitive: false),
          'Bearer <TOKEN_REDACTED>',
        )
        .replaceAll(
          RegExp(
            r'\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b',
            caseSensitive: false,
          ),
          '<TOKEN_REDACTED>',
        )
        .replaceAll(
          RegExp(
            r'(password|passwd|api[_-]?key|secret)\s*[:=]\s*[^\s,;}]+',
            caseSensitive: false,
          ),
          '<TOKEN_REDACTED>',
        )
        .replaceAll(
          RegExp(
            r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
            caseSensitive: false,
          ),
          '<EMAIL>',
        )
        .replaceAll(RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'), '<IP_ADDRESS>')
        .replaceAll(
          RegExp(r'\b(?:[0-9a-f]{2}:){5}[0-9a-f]{2}\b', caseSensitive: false),
          '<MAC_ADDRESS>',
        )
        .replaceAll(RegExp(r'S-1-5-(?:-?\d+)+', caseSensitive: false), '<SID>')
        .replaceAll(
          RegExp(r'serial(?:number)?\s*[:=]\s*[^\s,;}]+', caseSensitive: false),
          'serial=<SERIAL>',
        )
        .replaceAll(
          RegExp(r'hostname\s*[:=]\s*[^\s,;}]+', caseSensitive: false),
          'hostname=<HOSTNAME>',
        )
        .replaceAll(
          RegExp(
            r'(?:C:\\Users\\|/Users/|/home/)[^\\/\s]+',
            caseSensitive: false,
          ),
          '<HOME>',
        );
  }

  Object? redactJson(Object? input) {
    if (input is String) return redact(input);
    if (input is List) return input.map(redactJson).toList();
    if (input is Map) {
      return input.map((key, value) {
        final name = key.toString();
        if (RegExp(
          r'(token|authorization|password|secret|api.?key)',
          caseSensitive: false,
        ).hasMatch(name)) {
          return MapEntry(name, '<TOKEN_REDACTED>');
        }
        return MapEntry(name, redactJson(value));
      });
    }
    return input;
  }

  String prettyJson(Object? input) =>
      const JsonEncoder.withIndent(' ').convert(redactJson(input));
}
