import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/syllabus_data.dart';

// =============================================================================
//  SyllabusStore - Syllabus Tracker ka hisaab: kaun-sa exam chuna aur kaun-se
//  topics poore hue (aur kis din). Sirf phone me (SharedPreferences).
//  Firestore ko 0 reads / 0 writes.
// =============================================================================

/// Agla bacha hua topic (Planner me dikhane ke liye).
class NextTopic {
  final SylSubject subject;
  final SylTopic topic;
  const NextTopic(this.subject, this.topic);
}

class SyllabusStore {
  SyllabusStore._();

  static const _kExam = 'ysh4_syl_exam';
  static const _kDone = 'ysh4_syl_done'; // {topicId: yyyy-MM-dd}

  /// Exam badalne / topic tick karne par badalta hai (Home card, Planner refresh).
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void _bump() => changes.value = changes.value + 1;

  static Map<String, String> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final m = jsonDecode(raw);
      if (m is Map) {
        final out = <String, String>{};
        m.forEach((k, v) => out[k.toString()] = v.toString());
        return out;
      }
    } catch (_) {}
    return <String, String>{};
  }

  /// Student ne jo exam chuna (khali = abhi nahi chuna).
  static Future<String> selectedExamId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kExam) ?? '';
  }

  static Future<SylExam?> selectedExam() async => sylExamById(await selectedExamId());

  static Future<void> setExam(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kExam, id);
    _bump();
  }

  /// {topicId: poora hone ki date}
  static Future<Map<String, String>> doneMap() async {
    final p = await SharedPreferences.getInstance();
    return _decode(p.getString(_kDone));
  }

  static Future<void> setDone(String topicId, bool done) async {
    final p = await SharedPreferences.getInstance();
    final m = _decode(p.getString(_kDone));
    if (done) {
      final n = DateTime.now();
      m[topicId] = '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    } else {
      m.remove(topicId);
    }
    await p.setString(_kDone, jsonEncode(m));
    _bump();
  }

  /// Is exam ke saare topics ka progress hatao.
  static Future<void> resetExam(SylExam exam) async {
    final p = await SharedPreferences.getInstance();
    final m = _decode(p.getString(_kDone));
    for (final t in exam.allTopics) {
      m.remove(t.id);
    }
    await p.setString(_kDone, jsonEncode(m));
    _bump();
  }

  /// Ab tak kul kitne topics poore kiye (Badges ke liye).
  static Future<int> totalDone() async => (await doneMap()).length;

  /// Kisi ek din kitne topics poore kiye.
  static Future<int> doneOnDay(String day) async {
    final m = await doneMap();
    return m.values.where((d) => d == day).length;
  }

  /// Diye gaye dinon me kitne topics poore kiye.
  static Future<int> doneInDays(List<String> days) async {
    final m = await doneMap();
    final set = days.toSet();
    return m.values.where(set.contains).length;
  }

  /// Is exam ke kitne topics poore hue.
  static int doneCount(SylExam exam, Map<String, String> done) {
    var n = 0;
    for (final t in exam.allTopics) {
      if (done.containsKey(t.id)) n++;
    }
    return n;
  }

  /// Exam ka pehla bacha hua topic (syllabus ke kram me). Sab ho gaye to null.
  static NextTopic? nextTopic(SylExam exam, Map<String, String> done) {
    for (final s in exam.subjects) {
      for (final t in s.topics) {
        if (!done.containsKey(t.id)) return NextTopic(s, t);
      }
    }
    return null;
  }
}
