import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:shared_preferences/shared_preferences.dart';
import 'flashcard_store.dart';
import 'notes_store.dart';
import 'speed_math_store.dart';
import 'study_store.dart';
import 'study_time_store.dart';
import 'syllabus_store.dart';

// =============================================================================
//  BackupService - student ki padhai ka data (streak, mistakes, bookmarks,
//  flashcards, revision, timer, syllabus, speed maths, notes ...) cloud me
//  save / wapas laata hai, taaki naya phone ya app reinstall par data na jaye.
//
//  * Data students/{uid} document ke 'backup' field me jaata hai (compressed).
//    Firestore rules me students/{uid} sirf us student ko read/write dene deta
//    hai, isliye rules badalne ki zaroorat NAHI hai.
//  * Sirf student ke button dabane par 1 write (backup) ya 1 read (restore) hota hai.
//  * Quiz / Free-MCQ cache backup me nahi jaate (wo internet se dobara aa jaate hain).
// =============================================================================

class BackupInfo {
  final DateTime? at;
  final int keys;
  const BackupInfo(this.at, this.keys);
}

class BackupResult {
  final bool ok;
  final String message;
  const BackupResult(this.ok, this.message);
}

class BackupService {
  BackupService._();

  static const int _version = 1;
  static const int _maxChars = 700000; // Firestore document limit 1 MB hai
  static const List<String> _prefixes = ['ysh2_', 'ysh3_', 'ysh4_', 'ysh5_'];
  static const Set<String> _extraKeys = {'ysh_fmcq_done_v1'};
  static const Set<String> _skipKeys = {'ysh2_quiz_cache', 'ysh2_quiz_cache7'};

  static bool _wanted(String k) =>
      !_skipKeys.contains(k) && (_extraKeys.contains(k) || _prefixes.any(k.startsWith));

  static User? get _user => FirebaseAuth.instance.currentUser;

  static DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection('students').doc(uid);

  static const String _needLogin = 'Please log in first. / पहले लॉगिन करें।';
  static const String _netErr = "Couldn't reach the server. Check your internet and try again. / सर्वर से जुड़ नहीं सका। इंटरनेट जाँचकर दोबारा कोशिश करें।";

  static String _fail(Object e) {
    if (e is FirebaseException && e.code == 'permission-denied') {
      return "Permission denied. Please log out, log in again and retry. / अनुमति नहीं मिली। लॉगआउट करके दोबारा लॉगिन करें।";
    }
    return _netErr;
  }

  /// Cloud me abhi kaun sa backup hai (1 read). Backup nahi hai to null.
  static Future<BackupInfo?> fetchInfo() async {
    final u = _user;
    if (u == null) return null;
    final snap = await _doc(u.uid).get().timeout(const Duration(seconds: 12));
    final m = snap.data();
    if (m == null || (m['backup'] is! String) || (m['backup'] as String).isEmpty) return null;
    final ts = m['backupAt'];
    return BackupInfo(ts is Timestamp ? ts.toDate() : null, (m['backupKeys'] as num?)?.toInt() ?? 0);
  }

  /// Phone ka padhai-data cloud me save karta hai (1 write).
  static Future<BackupResult> backupNow() async {
    final u = _user;
    if (u == null) return const BackupResult(false, _needLogin);
    try {
      final p = await SharedPreferences.getInstance();
      final data = <String, dynamic>{};
      for (final k in p.getKeys()) {
        if (!_wanted(k)) continue;
        final v = p.get(k);
        if (v is String) {
          data[k] = {'t': 's', 'v': v};
        } else if (v is bool) {
          data[k] = {'t': 'b', 'v': v};
        } else if (v is int) {
          data[k] = {'t': 'i', 'v': v};
        } else if (v is double) {
          data[k] = {'t': 'd', 'v': v};
        } else if (v is List) {
          data[k] = {'t': 'l', 'v': v.map((e) => e.toString()).toList()};
        }
      }
      if (data.isEmpty) {
        return const BackupResult(false, 'Nothing to back up yet. Study a little first! / अभी बैकअप के लिए कुछ नहीं है। पहले थोड़ी पढ़ाई करें!');
      }
      final raw = utf8.encode(jsonEncode({'ver': _version, 'data': data}));
      final packed = base64Encode(gzip.encode(raw));
      if (packed.length > _maxChars) {
        return const BackupResult(false, 'Your data is too big to back up. Delete some old notes and try again. / डेटा बहुत बड़ा है। कुछ पुराने नोट्स हटाकर दोबारा कोशिश करें।');
      }
      await _doc(u.uid).set({
        'backup': packed,
        'backupAt': FieldValue.serverTimestamp(),
        'backupKeys': data.length,
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 20));
      return BackupResult(true, 'Backup saved ✓ (${data.length} items) / बैकअप सेव हो गया ✓');
    } catch (e) {
      return BackupResult(false, _fail(e));
    }
  }

  /// Cloud wala backup phone par wapas laata hai (1 read). Phone ka usi tarah ka
  /// data backup wale data se badal jaata hai.
  static Future<BackupResult> restore() async {
    final u = _user;
    if (u == null) return const BackupResult(false, _needLogin);
    try {
      final snap = await _doc(u.uid).get().timeout(const Duration(seconds: 15));
      final packed = snap.data()?['backup'];
      if (packed is! String || packed.isEmpty) {
        return const BackupResult(false, 'No backup found for this account. / इस अकाउंट का कोई बैकअप नहीं मिला।');
      }
      final json = jsonDecode(utf8.decode(gzip.decode(base64Decode(packed))));
      if (json is! Map || json['ver'] != _version || json['data'] is! Map) {
        return const BackupResult(false, 'This backup is from a newer app version. Please update the app. / यह बैकअप नए ऐप वर्ज़न का है। ऐप अपडेट करें।');
      }
      final data = Map<String, dynamic>.from(json['data'] as Map);
      final p = await SharedPreferences.getInstance();
      var n = 0;
      for (final e in data.entries) {
        final k = e.key;
        if (!_wanted(k) || e.value is! Map) continue; // sirf apni app ki keys
        final t = e.value['t'];
        final v = e.value['v'];
        if (t == 's' && v is String) {
          await p.setString(k, v);
        } else if (t == 'b' && v is bool) {
          await p.setBool(k, v);
        } else if (t == 'i' && v is num) {
          await p.setInt(k, v.toInt());
        } else if (t == 'd' && v is num) {
          await p.setDouble(k, v.toDouble());
        } else if (t == 'l' && v is List) {
          await p.setStringList(k, v.map((x) => x.toString()).toList());
        } else {
          continue;
        }
        n++;
      }
      // Sab screens / cards ko batao ki data badal gaya hai.
      StudyStore.notifyChanged();
      StudyTimeStore.changes.value = StudyTimeStore.changes.value + 1;
      FlashcardStore.changes.value = FlashcardStore.changes.value + 1;
      SyllabusStore.changes.value = SyllabusStore.changes.value + 1;
      SpeedMathStore.changes.value = SpeedMathStore.changes.value + 1;
      NotesStore.changes.value = NotesStore.changes.value + 1;
      return BackupResult(true, 'Restored ✓ ($n items) / डेटा वापस आ गया ✓');
    } catch (e) {
      if (e is FormatException || e is FileSystemException || e is ArgumentError) {
        return const BackupResult(false, 'The backup could not be read. / बैकअप पढ़ा नहीं जा सका।');
      }
      return BackupResult(false, _fail(e));
    }
  }
}
