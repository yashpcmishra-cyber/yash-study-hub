import 'package:shared_preferences/shared_preferences.dart';
import '../models/query_model.dart';

/// Remembers (on THIS phone only) which admin replies the student has already
/// seen, so the Home "Queries" tile can show a red dot for a new reply.
/// Nothing is written to Firebase, so no extra rules or storage are needed.
class QuerySeenStore {
  static const _key = 'seen_query_replies';

  static Future<Set<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key) ?? const <String>[]).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// Called when the student has the Queries screen open: every reply that is
  /// in the list now counts as seen. Old entries (deleted doubts) drop out
  /// automatically because only the current list is saved.
  static Future<void> markSeen(List<QueryModel> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, list.where((q) => q.answered).map((q) => q.seenKey).toList());
    } catch (_) {
      // not critical - the dot would just show once more
    }
  }

  /// True if at least one reply in [list] is not in [seen] yet.
  static bool hasUnread(List<QueryModel> list, Set<String> seen) =>
      list.any((q) => q.answered && !seen.contains(q.seenKey));
}
