import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/query_model.dart';

/// Everything about the `queries` collection (student doubts + admin reply).
/// Kept in its own file so firestore_service.dart stays untouched.
class QueriesService {
  final _col = FirebaseFirestore.instance.collection('queries');

  /// Student sends a doubt. The field list matches the Firestore rule exactly
  /// (QUERIES_RULES.txt) - do not add fields here without updating the rule.
  Future<void> submit({required String uid, required String name, required String email, required String text}) {
    return _col.add({
      'uid': uid,
      'studentName': name,
      'studentEmail': email,
      'text': normalizeSpaces(text),
      'reply': '',
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'repliedAt': null,
    });
  }

  /// The student's OWN doubts only (the rule allows exactly this query).
  /// Sorted here, not in Firestore, so no extra index is needed.
  Stream<List<QueryModel>> streamMine(String uid) => _col.where('uid', isEqualTo: uid).snapshots().map((snap) {
        final list = snap.docs.map((d) => QueryModel.fromMap(d.id, d.data())).where((q) => !q.isExpired).toList();
        list.sort((a, b) => b.when.compareTo(a.when));
        return list;
      });

  /// Admin: every doubt, newest first.
  Stream<List<QueryModel>> streamAll() => _col.orderBy('createdAt', descending: true).limit(300).snapshots().map((snap) =>
      snap.docs.map((d) => QueryModel.fromMap(d.id, d.data())).where((q) => !q.isExpired).toList());

  /// Admin: write (or edit) the reply.
  Future<void> reply(String id, String text) => _col.doc(id).update({
        'reply': text.trim(),
        'status': 'answered',
        'repliedAt': FieldValue.serverTimestamp(),
      });

  Future<void> delete(String id) => _col.doc(id).delete();
}
