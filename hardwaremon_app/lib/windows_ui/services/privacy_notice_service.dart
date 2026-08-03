import 'package:shared_preferences/shared_preferences.dart';

class PrivacyAcknowledgement {
  const PrivacyAcknowledgement({this.acceptedVersion, this.acceptedAtUtc});
  final int? acceptedVersion;
  final DateTime? acceptedAtUtc;
  bool accepts(int version) =>
      acceptedVersion != null && acceptedVersion! >= version;
}

class PrivacyNoticeService {
  PrivacyNoticeService({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  static const int currentVersion = 2;
  static const _versionKey = 'privacy.accepted_notice_version';
  static const _acceptedAtKey = 'privacy.accepted_at_utc';
  final Future<SharedPreferences> Function() _preferences;

  Future<PrivacyAcknowledgement> load() async {
    try {
      final preferences = await _preferences();
      final version = preferences.getInt(_versionKey);
      final rawDate = preferences.getString(_acceptedAtKey);
      return PrivacyAcknowledgement(
        acceptedVersion: version != null && version >= 0 ? version : null,
        acceptedAtUtc: rawDate == null
            ? null
            : DateTime.tryParse(rawDate)?.toUtc(),
      );
    } catch (_) {
      return const PrivacyAcknowledgement();
    }
  }

  Future<bool> shouldShow() async => !(await load()).accepts(currentVersion);

  Future<void> acknowledge() async {
    final preferences = await _preferences();
    await preferences.setInt(_versionKey, currentVersion);
    await preferences.setString(
      _acceptedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  // A general settings reset intentionally preserves privacy acknowledgement.
}
