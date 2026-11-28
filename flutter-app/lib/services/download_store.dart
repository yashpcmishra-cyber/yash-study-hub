import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
//  DownloadStore - "Downloads / मेरे डाउनलोड्स" (Web ke Downloads section ka
//  App version).
//
//  * PDF ki asli file App ke PRIVATE folder me save hoti hai
//    (getApplicationDocumentsDirectory/ysh_downloads). Ye phone ki Gallery /
//    File Manager / Downloads folder me NAHI dikhti - sirf is App ke
//    Downloads section me milti hai (Web ki IndexedDB ki tarah).
//  * Index (title, link, size, date...) SharedPreferences me, key 'dl_index_v1'.
//    Key me jaan-bujhkar 'ysh' prefix nahi hai, taaki Cloud Backup me na jaye
//    (file doosre phone par hoti hi nahi).
//  * Firestore ko 0 reads / 0 writes.
//  * Offline padhne ke liye PDF.js (same version jo Web me hai) ek baar
//    download karke App ke folder me rakha jata hai (PdfJsAssets).
// =============================================================================

/// Download fail hone par student ko dikhane layak (Hinglish + Hindi) message.
class DownloadException implements Exception {
  final String message;
  const DownloadException(this.message);
  @override
  String toString() => message;
}

// Server ne 200 diya lekin file PDF nahi thi (jaise Drive ka "virus scan" page).
class _NotPdfException implements Exception {
  const _NotPdfException();
}

/// "1.2 MB" / "340 KB" (0 ya negative = khali string).
String formatBytes(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1048576) return '${math.max(1, (bytes / 1024).round())} KB';
  return '${(bytes / 1048576).toStringAsFixed(1)} MB';
}

class DownloadItem {
  final String id;
  final String title;
  final String url; // PDF ka original link (jahan se khola tha)
  final String mode; // 'file' = App me asli file | 'link' = sirf link (online dekhni hogi)
  final bool paid; // Paid Batch ki PDF
  final int size; // bytes (link mode me 0)
  final int savedMs; // millisecondsSinceEpoch

  const DownloadItem({
    required this.id,
    required this.title,
    required this.url,
    required this.mode,
    required this.paid,
    required this.size,
    required this.savedMs,
  });

  bool get isFile => mode == 'file';

  Map<String, dynamic> toMap() => {
        'id': id,
        't': title,
        'u': url,
        'm': mode,
        'p': paid,
        's': size,
        'at': savedMs,
      };

  static DownloadItem? fromMap(dynamic m) {
    try {
      if (m is! Map) return null;
      final id = (m['id'] ?? '').toString();
      if (id.isEmpty) return null;
      final mode = (m['m'] ?? 'file').toString() == 'link' ? 'link' : 'file';
      return DownloadItem(
        id: id,
        title: (m['t'] ?? 'PDF').toString(),
        url: (m['u'] ?? '').toString(),
        mode: mode,
        paid: m['p'] == true,
        size: (m['s'] as num?)?.toInt() ?? 0,
        savedMs: (m['at'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

class DownloadSaveResult {
  final DownloadItem item;
  final bool already; // pehle se Downloads me thi
  const DownloadSaveResult(this.item, this.already);
  bool get offline => item.isFile;
}

class DownloadStore {
  DownloadStore._();

  static const String _kIndex = 'dl_index_v1';
  static const String _dirName = 'ysh_downloads';

  /// Download / delete par badalta hai (Home card aur Downloads screen sun-te hain).
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void _bump() => changes.value = changes.value + 1;

  // Index ke padhne/likhne ek ke baad ek hote hain (do kaam ek saath na ho).
  // NOTE: _sync ke andar kabhi dusra _sync wala function mat bulao (deadlock).
  static Future<void> _tail = Future<void>.value();
  static Future<T> _sync<T>(Future<T> Function() job) {
    final c = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        c.complete(await job());
      } catch (e, s) {
        c.completeError(e, s);
      }
    });
    return c.future;
  }

  static Directory? _dirCache;

  /// App ka private Downloads folder (nahi ho to ban jata hai).
  static Future<Directory> dir() async {
    final cached = _dirCache;
    if (cached != null && await cached.exists()) return cached;
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}${Platform.pathSeparator}$_dirName');
    if (!await d.exists()) await d.create(recursive: true);
    _dirCache = d;
    return d;
  }

  /// Web ke dlIdFor() jaisa hi: same link = same id.
  static String idFor(String url) {
    var h = 5381;
    final s = url;
    for (var i = 0; i < s.length; i++) {
      h = ((h << 5) + h + s.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return 'p${h.toRadixString(36)}_${s.length}';
  }

  static Future<File> _fileForId(String id) async {
    final d = await dir();
    return File('${d.path}${Platform.pathSeparator}$id.pdf');
  }

  /// Is download ki asli PDF file (sirf 'file' mode me maujood hoti hai).
  static Future<File> fileFor(DownloadItem item) => _fileForId(item.id);

  static Future<List<DownloadItem>> _readRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kIndex);
    if (raw == null || raw.isEmpty) return <DownloadItem>[];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return <DownloadItem>[];
      final out = <DownloadItem>[];
      for (final m in list) {
        final it = DownloadItem.fromMap(m);
        if (it != null) out.add(it);
      }
      return out;
    } catch (_) {
      return <DownloadItem>[];
    }
  }

  static Future<void> _write(List<DownloadItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kIndex, jsonEncode(items.map((e) => e.toMap()).toList()));
  }

  /// Saari downloads, sabse nayi upar. Jin ki file gum ho gayi (jaise Clear
  /// Data ke baad) unhe list se hata deta hai.
  static Future<List<DownloadItem>> all() => _sync<List<DownloadItem>>(() async {
        final items = await _readRaw();
        final keep = <DownloadItem>[];
        var changed = false;
        for (final it in items) {
          if (it.isFile) {
            var ok = false;
            try {
              final f = await _fileForId(it.id);
              ok = await f.exists() && await f.length() > 0;
            } catch (_) {
              ok = false;
            }
            if (!ok) {
              changed = true;
              continue;
            }
          }
          keep.add(it);
        }
        if (changed) await _write(keep);
        keep.sort((a, b) => b.savedMs.compareTo(a.savedMs));
        return keep;
      });

  /// Is link ki PDF Downloads me hai? (nahi hai to null)
  static Future<DownloadItem?> find(String url) async {
    final id = idFor(url.trim());
    final list = await all();
    for (final it in list) {
      if (it.id == id) return it;
    }
    return null;
  }

  static Future<int> count() async => (await all()).length;

  /// PDF ko App ke Downloads me save karta hai.
  ///
  /// [url]         = PDF ka original link (isi se pehchan hoti hai)
  /// [downloadUrl] = jahan se asli file aati hai (Drive link ho to direct-download link)
  ///
  /// Asli PDF mil gayi -> 'file' mode (offline khulegi).
  /// Link 200 deta hai par PDF nahi (Drive ka beech ka page) -> 'link' mode
  /// (Web jaisa: Downloads me link save, online dikhegi).
  /// Internet / storage ki dikkat -> [DownloadException] (kuch save nahi hota).
  static Future<DownloadSaveResult> save({
    required String url,
    required String downloadUrl,
    required String title,
    required bool paid,
    void Function(double fraction)? onProgress,
  }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) {
      throw const DownloadException('This PDF link is not valid. / यह PDF लिंक सही नहीं है।');
    }
    final id = idFor(cleanUrl);
    final existing = await find(cleanUrl);
    if (existing != null) return DownloadSaveResult(existing, true);

    final cleanTitle = title.trim().isEmpty ? 'PDF' : title.trim();
    final DownloadItem item = await _fetchItem(
      id: id,
      url: cleanUrl,
      downloadUrl: downloadUrl,
      title: cleanTitle,
      paid: paid,
      onProgress: onProgress,
    );

    try {
      await _sync<void>(() async {
        final items = await _readRaw();
        items.removeWhere((e) => e.id == id);
        items.add(item);
        await _write(items);
      });
    } catch (e) {
      // Index likh nahi paye -> adhoori file ko bhi hata do.
      try {
        final f = await _fileForId(id);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      throw DownloadException(_friendly(e));
    }
    _bump();
    // Offline viewer (PDF.js) ab hi tayyar kar lo, jab internet hai.
    unawaited(PdfJsAssets.ensure());
    return DownloadSaveResult(item, false);
  }

  // Asli PDF utarta hai ('file' mode); Drive jaisa beech ka page mila to
  // sirf link save hota hai ('link' mode). Internet / storage ki dikkat = DownloadException.
  static Future<DownloadItem> _fetchItem({
    required String id,
    required String url,
    required String downloadUrl,
    required String title,
    required bool paid,
    void Function(double fraction)? onProgress,
  }) async {
    try {
      final size = await _fetchToFile(downloadUrl, id, onProgress);
      return DownloadItem(
        id: id,
        title: title,
        url: url,
        mode: 'file',
        paid: paid,
        size: size,
        savedMs: DateTime.now().millisecondsSinceEpoch,
      );
    } on _NotPdfException {
      return DownloadItem(
        id: id,
        title: title,
        url: url,
        mode: 'link',
        paid: paid,
        size: 0,
        savedMs: DateTime.now().millisecondsSinceEpoch,
      );
    } on DownloadException {
      rethrow;
    } catch (e) {
      throw DownloadException(_friendly(e));
    }
  }

  static String _friendly(Object e) {
    if (e is FileSystemException) {
      return 'Phone storage is full or not available. / फ़ोन की स्टोरेज भरी है या उपलब्ध नहीं है।';
    }
    if (e is TimeoutException || e is SocketException || e is HttpException || e is http.ClientException || e is TlsException) {
      return 'Internet problem. Check your connection and try again. / इंटरनेट में दिक्कत है। कनेक्शन जाँचकर दोबारा कोशिश करें।';
    }
    return 'Could not download this PDF. Try again. / PDF डाउनलोड नहीं हुई। दोबारा कोशिश करें।';
  }

  static bool _isPdfHead(List<int> h) => h.length >= 4 && h[0] == 0x25 && h[1] == 0x50 && h[2] == 0x44 && h[3] == 0x46; // "%PDF"

  // PDF ko seedha file me utarta hai (RAM me poori file nahi rakhta).
  static Future<int> _fetchToFile(String downloadUrl, String id, void Function(double)? onProgress) async {
    final uri = Uri.tryParse(downloadUrl.trim());
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const DownloadException('This PDF link is not valid. / यह PDF लिंक सही नहीं है।');
    }
    final d = await dir();
    final finalFile = File('${d.path}${Platform.pathSeparator}$id.pdf');
    final part = File('${d.path}${Platform.pathSeparator}$id.part');
    final client = http.Client();
    IOSink? sink;
    try {
      final resp = await client.send(http.Request('GET', uri)).timeout(const Duration(seconds: 45));
      if (resp.statusCode != 200) {
        throw DownloadException('Could not download this PDF (server error ${resp.statusCode}). / PDF डाउनलोड नहीं हुई (सर्वर एरर ${resp.statusCode})।');
      }
      final total = resp.contentLength ?? 0;
      var received = 0;
      final head = <int>[];
      var headChecked = false;
      if (await part.exists()) await part.delete();
      final out = part.openWrite();
      sink = out;
      await for (final chunk in resp.stream.timeout(const Duration(seconds: 45))) {
        if (!headChecked) {
          for (final b in chunk) {
            if (head.length >= 5) break;
            head.add(b);
          }
          if (head.length >= 4) {
            if (!_isPdfHead(head)) throw const _NotPdfException();
            headChecked = true;
          }
        }
        out.add(chunk);
        received += chunk.length;
        if (onProgress != null && total > 0) onProgress((received / total).clamp(0.0, 1.0).toDouble());
      }
      if (!headChecked || received < 100) throw const _NotPdfException();
      await out.flush();
      await out.close();
      sink = null;
      if (await finalFile.exists()) await finalFile.delete();
      await part.rename(finalFile.path);
      return received;
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {}
      try {
        if (await part.exists()) await part.delete();
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Ek PDF Downloads se hatata hai (file bhi delete).
  static Future<void> remove(String id) => _sync<void>(() async {
        final items = await _readRaw();
        items.removeWhere((e) => e.id == id);
        await _write(items);
        try {
          final f = await _fileForId(id);
          if (await f.exists()) await f.delete();
        } catch (_) {}
        _bump();
      });

  /// Sab kuch hata deta hai ("Delete Account" ke time). Offline viewer
  /// (PDF.js) ki files rehne dete hain - unme koi personal data nahi.
  static Future<void> clearAll() => _sync<void>(() async {
        try {
          final d = await dir();
          final entries = await d.list(followLinks: false).toList();
          for (final e in entries) {
            if (e is File) {
              try {
                await e.delete();
              } catch (_) {}
            }
          }
        } catch (_) {}
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_kIndex);
        } catch (_) {}
        _bump();
      });
}

// =============================================================================
//  PdfJsAssets - offline PDF dekhne ke liye PDF.js ki 2 files (Web me bhi yahi
//  version use hota hai). Pehli baar (internet ke saath) jsDelivr se aati hain
//  aur App ke private folder me rehti hain; uske baad bina internet chalti hain.
// =============================================================================
class PdfJsAssets {
  PdfJsAssets._();

  static const String version = '3.11.174';
  static const String libName = 'pdf.min.js';
  static const String workerName = 'pdf.worker.min.js';
  static const String _base = 'https://cdn.jsdelivr.net/npm/pdfjs-dist@$version/build/';

  static Future<bool>? _inflight;

  static Future<File> _file(String name) async {
    final d = await DownloadStore.dir();
    final sub = Directory('${d.path}${Platform.pathSeparator}_pdfjs');
    if (!await sub.exists()) await sub.create(recursive: true);
    return File('${sub.path}${Platform.pathSeparator}$version-$name');
  }

  // Adhoori / kharab file ko pehchanne ke liye size + andar ka ek pakka shabd.
  static bool _valid(String name, Uint8List b) {
    if (name == libName) {
      return b.length > 150000 && latin1.decode(b, allowInvalid: true).contains('getDocument');
    }
    return b.length > 400000 && latin1.decode(b, allowInvalid: true).contains('WorkerMessageHandler');
  }

  /// Saved file ke bytes (nahi ho ya kharab ho to null).
  static Future<Uint8List?> read(String name) async {
    try {
      final f = await _file(name);
      if (!await f.exists()) return null;
      final b = await f.readAsBytes();
      return _valid(name, b) ? b : null;
    } catch (_) {
      return null;
    }
  }

  /// Dono files maujood hain? Nahi to download karta hai. true = tayyar.
  static Future<bool> ensure() {
    return _inflight ??= _ensure().whenComplete(() {
      _inflight = null;
    });
  }

  static Future<bool> _ensure() async {
    try {
      for (final name in const [libName, workerName]) {
        if (await read(name) != null) continue;
        final res = await http.get(Uri.parse('$_base$name')).timeout(const Duration(seconds: 90));
        if (res.statusCode != 200 || !_valid(name, res.bodyBytes)) return false;
        final f = await _file(name);
        final part = File('${f.path}.part');
        await part.writeAsBytes(res.bodyBytes, flush: true);
        if (await f.exists()) await f.delete();
        await part.rename(f.path);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
