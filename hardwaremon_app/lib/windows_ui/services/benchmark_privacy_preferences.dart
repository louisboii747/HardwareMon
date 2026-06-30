import 'package:shared_preferences/shared_preferences.dart';

class BenchmarkPrivacyPreferences {
  static const _lastPromptedResultKey =
      'benchmark.last_anonymous_submission_prompt_result';
  int? _sessionLastPromptedResult;

  Future<bool> shouldPromptForResult(int resultId) async {
    if (resultId <= 0 || _sessionLastPromptedResult == resultId) return false;
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getInt(_lastPromptedResultKey) != resultId;
    } catch (_) {
      return true;
    }
  }

  Future<void> markPrompted(int resultId) async {
    _sessionLastPromptedResult = resultId;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(_lastPromptedResultKey, resultId);
    } catch (_) {
      // Session memory still prevents repeated prompts if preferences fail.
    }
  }
}
