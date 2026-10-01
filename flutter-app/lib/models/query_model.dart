import 'package:cloud_firestore/cloud_firestore.dart';

/// Student doubt: max words, how many unanswered doubts one student may have
/// at a time, and how long (days) Firebase keeps a doubt before the daily
/// cleanup deletes it (see production-app-guide/free-scripts/cleanup-queries.js).
const int kQueryMaxWords = 100;
const int kQueryMaxPending = 5;
const int kQueryRetentionDays = 20;

int countWords(String s) {
  final t = s.trim();
  return t.isEmpty ? 0 : t.split(RegExp(r'\s+')).length;
}

/// Collapses every run of spaces / new lines into ONE space. The Firestore
/// rule counts words by splitting on single spaces, so text is always saved
/// in this form.
String normalizeSpaces(String s) {
  final t = s.trim();
  return t.isEmpty ? '' : t.split(RegExp(r'\s+')).join(' ');
}

class QueryModel {
  final String id;
  final String uid;
  final String studentName;
  final String studentEmail;
  final String text;
  final String reply;
  final DateTime? createdAt;
  final DateTime? repliedAt;

  QueryModel({
    required this.id,
    required this.uid,
    this.studentName = '',
    this.studentEmail = '',
    required this.text,
    this.reply = '',
    this.createdAt,
    this.repliedAt,
  });

  bool get answered => reply.trim().isNotEmpty;

  /// A just-sent doubt has no server time yet (createdAt == null) - it is
  /// treated as "now", so it is never hidden by mistake.
  DateTime get when => createdAt ?? DateTime.now();

  /// Whole days left before the cleanup deletes it (never below 0).
  int get daysLeft {
    final left = kQueryRetentionDays - DateTime.now().difference(when).inDays;
    return left < 0 ? 0 : left;
  }

  /// Older than the retention time = hidden in the app even if the daily
  /// cleanup has not run yet.
  bool get isExpired => DateTime.now().difference(when).inDays >= kQueryRetentionDays;

  factory QueryModel.fromMap(String id, Map<String, dynamic> m) => QueryModel(
        id: id,
        uid: (m['uid'] as String?) ?? '',
        studentName: (m['studentName'] as String?) ?? '',
        studentEmail: (m['studentEmail'] as String?) ?? '',
        text: (m['text'] as String?) ?? '',
        reply: (m['reply'] as String?) ?? '',
        createdAt: m['createdAt'] is Timestamp ? (m['createdAt'] as Timestamp).toDate() : null,
        repliedAt: m['repliedAt'] is Timestamp ? (m['repliedAt'] as Timestamp).toDate() : null,
      );
}
