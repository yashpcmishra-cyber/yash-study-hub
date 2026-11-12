import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'content_seen_store.dart';
import 'free_mcq_service.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ---- Fewer Firestore reads: "cache-first" list reads for STUDENT screens ----
  // A live listener (snapshots()) is billed again for every document each time
  // the screen is opened after a while. For lists that rarely change, the
  // student screens call these methods with `cache: true` instead:
  //   * the list is downloaded ONCE and kept in Firestore's own offline cache;
  //   * for the next [ttl] it is served from that cache (0 reads);
  //   * it is downloaded again when the TTL is over, when the admin added new
  //     content (the "new content" time stamps in appConfig/main, which the Home
  //     screen already listens to, so checking them costs nothing), or when the
  //     student pulls to refresh (`force: true`).
  // The Admin Panel never passes `cache`, so it always stays live.
  static final Map<String, Future<QuerySnapshot<Map<String, dynamic>>>> _inflight = {};

  // Newest "new content" time stamp among [fields], read from the local copy of
  // appConfig/main (no billed read). 0 = unknown.
  Future<int> _marker(List<String> fields) async {
    if (fields.isEmpty) return 0;
    try {
      final d = await _db.collection('appConfig').doc('main').get(GetOptions(source: Source.cache));
      final data = d.data();
      if (data == null) return 0;
      var best = 0;
      for (final f in fields) {
        final v = data[f];
        if (v is Timestamp && v.millisecondsSinceEpoch > best) best = v.millisecondsSinceEpoch;
      }
      return best;
    } catch (_) {
      return 0;
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _cachedGet(
    String key,
    Query<Map<String, dynamic>> q, {
    Duration ttl = const Duration(hours: 2),
    List<String> markers = const [],
    bool force = false,
  }) {
    final k = 'ysh_fq_$key';
    final running = _inflight[k];
    if (running != null) return running;
    // NOTE: the callback must NOT return a value. remove() returns this very future, and
    // whenComplete() waits for a returned future, so it would wait for itself forever.
    final f = _cachedGetRun(k, q, ttl, markers, force).whenComplete(() {
      _inflight.remove(k);
    });
    _inflight[k] = f;
    return f;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _cachedGetRun(
    String k,
    Query<Map<String, dynamic>> q,
    Duration ttl,
    List<String> markers,
    bool force,
  ) async {
    SharedPreferences? p;
    try {
      p = await SharedPreferences.getInstance();
    } catch (_) {
      p = null;
    }
    final marker = await _marker(markers);
    if (!force && p != null) {
      try {
        final raw = p.getString(k);
        if (raw != null) {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          final age = DateTime.now().millisecondsSinceEpoch - ((m['t'] as num?)?.toInt() ?? 0);
          final seen = (m['m'] as num?)?.toInt() ?? 0;
          if (age >= 0 && age < ttl.inMilliseconds && marker <= seen) {
            final cached = await q.get(GetOptions(source: Source.cache));
            // Same number of documents as the last download = the cache is complete.
            if (cached.docs.length == ((m['n'] as num?)?.toInt() ?? -1)) return cached;
          }
        }
      } catch (_) {
        // fall through to the server
      }
    }
    try {
      final snap = await q.get().timeout(const Duration(seconds: 12));
      if (p != null) {
        try {
          await p.setString(k, jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'm': marker, 'n': snap.docs.length}));
        } catch (_) {}
      }
      return snap;
    } catch (_) {
      // Offline / slow: show what the phone already has, if anything.
      try {
        final cached = await q.get(GetOptions(source: Source.cache));
        if (cached.docs.isNotEmpty) return cached;
      } catch (_) {}
      rethrow;
    }
  }

  // Live list (Admin Panel, default) or cache-first list (students, cache: true).
  Stream<List<T>> _listStream<T>({
    required String key,
    required Query<Map<String, dynamic>> q,
    required T Function(String id, Map<String, dynamic> data) build,
    List<T> Function(List<T> list)? post,
    bool cache = false,
    bool force = false,
    Duration ttl = const Duration(hours: 2),
    List<String> markers = const [],
  }) {
    List<T> shape(QuerySnapshot<Map<String, dynamic>> snap) {
      final list = snap.docs.map((d) => build(d.id, d.data())).toList();
      return post == null ? list : post(list);
    }

    if (!cache) return q.snapshots().map(shape);
    // One download, but safe to listen to more than once (a screen may re-subscribe to the same stream).
    final result = _cachedGet(key, q, ttl: ttl, markers: markers, force: force).then(shape);
    result.then((_) {}, onError: (Object _) {}); // marks an unlistened error as handled
    return Stream<List<T>>.multi((c) {
      result.then((v) {
        c.add(v);
        c.close();
      }, onError: (Object e, StackTrace st) {
        c.addError(e, st);
        c.close();
      });
    });
  }

  // ---- small helpers ----

  // Admin "arrange" feature: saves a hand-made order by writing the position
  // number (0, 1, 2 ...) into each document's `order` field. Only this one
  // field is touched. Used for batches, banners, PDF / video / mock-test
  // folders and the PDFs / videos / tests inside them.
  static const _orderable = {
    'batches', 'banners', 'pdfFolders', 'pdfs', 'videoFolders', 'videos', 'mockTestFolders', 'mockTests',
  };

  Future<void> saveOrder(String collection, List<String> idsInOrder) async {
    if (!_orderable.contains(collection)) throw ArgumentError('Cannot arrange "$collection"');
    var batch = _db.batch();
    var pending = 0;
    for (var i = 0; i < idsInOrder.length; i++) {
      batch.update(_db.collection(collection).doc(idsInOrder[i]), {'order': i});
      pending++;
      if (pending >= 400) {
        await batch.commit();
        batch = _db.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
  }

  // Deletes every document a query returns (in chunks, so it also works for
  // big folders). Returns how many documents were deleted.
  Future<int> _deleteAll(Query<Map<String, dynamic>> q) async {
    final snap = await q.get();
    var deleted = 0;
    var pending = 0;
    var batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
      pending++;
      deleted++;
      if (pending >= 400) {
        await batch.commit();
        batch = _db.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
    return deleted;
  }

  // Keeps the "N PDFs / N videos" numbers on the batch card accurate.
  // Never throws: if the batch was already deleted the counter no longer
  // matters.
  Future<void> _bumpBatchCount(String? batchId, String field, int delta) async {
    if (batchId == null || batchId.isEmpty || batchId == kFreeVideoBatchId || delta == 0) return;
    try {
      await _db.collection('batches').doc(batchId).update({field: FieldValue.increment(delta)});
    } catch (_) {
      // ignore
    }
  }

  // Same as _bumpBatchCount, for every batch a (multi-batch) folder is in.
  Future<void> _bumpBatchCounts(Iterable<String?> batchIds, String field, int delta) async {
    for (final id in batchIds.toSet()) {
      await _bumpBatchCount(id, field, delta);
    }
  }

  // ---- "New content" red dots on the Home grid ----
  // Every time the admin adds something NEW, one timestamp field is written
  // (merge) into the existing doc appConfig/main. Students already read that
  // doc, so this costs no extra reads. Never throws: if it fails the upload
  // itself is still fine, the red dot just does not show.
  Future<void> _markUpdated(String field) async {
    try {
      await _db.collection('appConfig').doc('main').set({field: FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } catch (_) {
      // ignore
    }
  }

  bool _isPaidBatchId(String? id) => id != null && id.isNotEmpty && id != kFreeVideoBatchId;

  // After a new mock test: free folder -> Mock Tests dot, folder inside a
  // paid batch -> Paid Batches dot.
  Future<void> _markMockUpdated(String folderId) async {
    try {
      final doc = await _db.collection('mockTestFolders').doc(folderId).get().timeout(const Duration(seconds: 10));
      final ids = doc.data()?['batchIds'];
      final inBatch = ids is List && ids.isNotEmpty;
      await _markUpdated(inBatch ? 'newBatchesAt' : 'newMocksAt');
    } catch (_) {
      // ignore
    }
  }

  // Home grid: the 4 tiles listen to this one doc.
  Stream<ContentUpdates> streamContentUpdates() =>
      _db.collection('appConfig').doc('main').snapshots().map((d) => ContentUpdates.fromMap(d.data()));

  // Time of the newest notification (1 tiny read). Epoch 0 = none yet.
  Stream<DateTime> streamLatestNotificationTime() => _db
          .collection('notifications')
          .orderBy('sentAt', descending: true)
          .limit(1)
          .snapshots()
          .map((snap) {
        if (snap.docs.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
        final v = snap.docs.first.data()['sentAt'];
        return v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
      });

  // ---- Batches ----
  // The admin's hand-made order first, then anything never arranged (oldest
  // first). See compareOrderThenCreated.
  Stream<List<BatchModel>> streamBatches({bool cache = false, bool force = false}) => _listStream<BatchModel>(
        key: 'batches',
        q: _db.collection('batches'),
        build: BatchModel.fromMap,
        post: (list) {
          list.sort((a, b) => compareOrderThenCreated(a.order, b.order, a.createdAt, b.createdAt, a.title, b.title));
          return list;
        },
        cache: cache,
        force: force,
        ttl: const Duration(hours: 3),
        markers: const ['newBatchesAt'],
      );

  // One batch by id (used when a Home banner is tapped). null = deleted.
  Future<BatchModel?> getBatch(String id) async {
    final doc = await _db.collection('batches').doc(id).get().timeout(const Duration(seconds: 12));
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return BatchModel.fromMap(doc.id, data);
  }

  Future<void> addBatch(BatchModel b) async {
    await _db.collection('batches').add({...b.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    await _markUpdated('newBatchesAt');
  }

  // Partial update — only overwrites the fields actually passed in, so
  // editing just the price (say) never clobbers the icon or counts.
  Future<void> updateBatch(String id, {String? title, int? price, String? iconUrl, int? validityMonths}) {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (price != null) data['price'] = price;
    if (iconUrl != null) data['iconUrl'] = iconUrl;
    // 0 is a real value here (= lifetime), so only null means "leave as is".
    if (validityMonths != null) data['validityMonths'] = validityMonths;
    if (data.isEmpty) return Future.value();
    return _db.collection('batches').doc(id).update(data);
  }

  // Deletes the batch AND everything that belonged to it (PDFs, videos,
  // folders, pending requests and student access records), so nothing is
  // left behind as invisible "orphan" data.
  //
  // A PDF folder that is ALSO in another paid batch is NOT deleted - the
  // deleted batch is only taken out of its list, so the other batches keep
  // their PDFs.
  Future<void> deleteBatch(String id) async {
    final keepFolderIds = <String>{};
    final seen = <String>{};
    final folderDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final q in [
      _db.collection('pdfFolders').where('batchIds', arrayContains: id),
      _db.collection('pdfFolders').where('batchId', isEqualTo: id),
    ]) {
      final snap = await q.get();
      for (final d in snap.docs) {
        if (seen.add(d.id)) folderDocs.add(d);
      }
    }
    for (final d in folderDocs) {
      final f = PdfFolderModel.fromMap(d.id, d.data());
      final others = f.batchIds.where((b) => b != id).toList();
      if (others.isNotEmpty) {
        keepFolderIds.add(d.id);
        await d.reference.update({'batchIds': others, 'batchId': others.first});
      }
    }
    // PDFs of folders that survive are kept (they still belong to the other batches).
    final pdfSnap = await _db.collection('pdfs').where('batchId', isEqualTo: id).get();
    var batch = _db.batch();
    var pending = 0;
    for (final d in pdfSnap.docs) {
      if (keepFolderIds.contains(d.data()['folderId'])) continue;
      batch.delete(d.reference);
      pending++;
      if (pending >= 400) {
        await batch.commit();
        batch = _db.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
    // PDFs inside a folder that is being deleted (they may carry another batch id).
    for (final d in folderDocs) {
      if (keepFolderIds.contains(d.id)) continue;
      await _deleteAll(_db.collection('pdfs').where('folderId', isEqualTo: d.id));
      await d.reference.delete();
    }
    await _deleteAll(_db.collection('videos').where('batchId', isEqualTo: id));
    await _deleteAll(_db.collection('videoFolders').where('batchId', isEqualTo: id));
    await _deleteAll(_db.collection('accessRequests').where('batchId', isEqualTo: id));
    await _deleteAll(_db.collection('batchAccess').where('batchId', isEqualTo: id));
    await _db.collection('batches').doc(id).delete();
  }

  // ---- PDFs ----
  // batchIds = every paid batch the folder is in (so each batch's "N PDFs"
  // number goes up). Left empty, the PDF's own batchId is used.
  Future<void> addPdf(PdfModel p, {List<String> batchIds = const []}) async {
    await _db.collection('pdfs').add({...p.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    final ids = batchIds.isNotEmpty ? batchIds : <String>[if (p.batchId != null) p.batchId!];
    await _bumpBatchCounts(ids, 'pdfs', 1);
    await _markUpdated(ids.any(_isPaidBatchId) ? 'newBatchesAt' : 'newPdfsAt');
  }

  Future<void> deletePdf(String id, {String? batchId, List<String> batchIds = const []}) async {
    await _db.collection('pdfs').doc(id).delete();
    await _bumpBatchCounts(batchIds.isNotEmpty ? batchIds : <String?>[batchId], 'pdfs', -1);
  }

  // Rename a PDF folder (only the name field changes; PDFs stay linked by id).
  Future<void> renamePdfFolder(String id, String newName) =>
      _db.collection('pdfFolders').doc(id).update({'name': newName.trim()});

  // Deletes the folder together with all PDFs inside it.
  Future<void> deletePdfFolder(String id, {String? batchId, List<String> batchIds = const []}) async {
    final removed = await _deleteAll(_db.collection('pdfs').where('folderId', isEqualTo: id));
    await _db.collection('pdfFolders').doc(id).delete();
    await _bumpBatchCounts(batchIds.isNotEmpty ? batchIds : <String?>[batchId], 'pdfs', -removed);
  }

  // Admin: which paid batches a PDF folder belongs to (1 to 3, never empty).
  // The folder's PDFs are NOT copied - they are simply shown in every batch
  // of the list. Each batch's "N PDFs" number is fixed up too.
  Future<void> setPdfFolderBatches(String folderId, List<String> newIds, {required List<String> oldIds}) async {
    if (newIds.isEmpty) throw ArgumentError('A paid PDF folder needs at least one batch');
    await _db.collection('pdfFolders').doc(folderId).update({
      'type': 'batch',
      'batchIds': newIds,
      'batchId': newIds.first, // keeps older app versions working
    });
    var count = 0;
    try {
      final agg = await _db.collection('pdfs').where('folderId', isEqualTo: folderId).count().get();
      count = agg.count ?? 0;
    } catch (_) {
      // the numbers on the batch cards are not critical
    }
    final added = newIds.where((b) => !oldIds.contains(b)).toList();
    final removed = oldIds.where((b) => !newIds.contains(b)).toList();
    if (count > 0) {
      await _bumpBatchCounts(added, 'pdfs', count);
      await _bumpBatchCounts(removed, 'pdfs', -count);
    }
    if (added.isNotEmpty) await _markUpdated('newBatchesAt');
  }

  // ---- Videos ----
  // Free/public videos ONLY (batchId explicitly null in Firestore) — this
  // is what the "Video Classes" screen uses, so a paid batch's videos never
  // show up in the free section. Newest first. Videos the admin "hid"
  // (auto-fetched ones) are left out.
  //
  // limitYoutubeAuto: when set (students' Video Classes screen), only the
  // newest N auto-fetched YouTube-channel videos are kept. Videos the admin
  // added by hand are never cut. The Admin panel leaves it null = sees all.
  Stream<List<VideoModel>> streamFreeVideos({int? limitYoutubeAuto, bool cache = false, bool force = false}) => _listStream<VideoModel>(
        key: 'freeVideos',
        q: _db.collection('videos').where('batchId', isEqualTo: null),
        build: VideoModel.fromMap,
        post: (all) {
          final list = all.where((v) => !v.hidden).toList();
          list.sort(compareVideosNewestFirst);
          if (limitYoutubeAuto == null) return list;
          var autoSeen = 0;
          return list.where((v) {
            if (v.source != 'youtube_auto') return true;
            autoSeen++;
            return autoSeen <= limitYoutubeAuto;
          }).toList();
        },
        cache: cache,
        force: force,
        // The hourly YouTube script adds videos without a "new content" stamp, so refresh hourly.
        ttl: const Duration(hours: 1),
        markers: const ['newVideosAt'],
      );

  // Newest 10 auto-fetched YouTube videos for the Home strip. The GitHub
  // script keeps a ready-made "latest 10" list in appConfig/latestVideos
  // (one tiny read, always the newest, no Firestore index needed).
  Stream<List<VideoModel>> streamLatestVideos({int limit = 10}) => _db
          .collection('appConfig')
          .doc('latestVideos')
          .snapshots()
          .map((doc) {
        final data = doc.data();
        final raw = data == null ? null : data['items'];
        final out = <VideoModel>[];
        if (raw is List) {
          for (final item in raw) {
            if (item is Map) {
              final v = VideoModel.fromLatestMap(Map<String, dynamic>.from(item));
              if (v.youtubeLink.isNotEmpty) out.add(v);
              if (out.length >= limit) break;
            }
          }
        }
        return out;
      });

  // Fallback for the Home strip if the script hasn't written
  // appConfig/latestVideos yet: pulls a handful of auto-fetched videos and
  // sorts them newest first on the phone.
  Stream<List<VideoModel>> streamAutoFetchedVideos({int limit = 10, bool cache = false, bool force = false}) => _listStream<VideoModel>(
        key: 'autoVideos',
        q: _db.collection('videos').where('source', isEqualTo: 'youtube_auto').limit(50),
        build: VideoModel.fromMap,
        post: (all) {
          final list = all.where((v) => !v.hidden).toList();
          list.sort(compareVideosNewestFirst);
          return list.take(limit).toList();
        },
        cache: cache,
        force: force,
        ttl: const Duration(hours: 1),
      );

  Future<void> addVideo(VideoModel v) async {
    await _db.collection('videos').add({...v.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    await _bumpBatchCount(v.batchId, 'videos', 1);
    // The hourly YouTube auto-fetch never goes through here, so it can't
    // light the dot - only videos the admin adds by hand.
    if (v.source != 'youtube_auto') {
      await _markUpdated(_isPaidBatchId(v.batchId) ? 'newBatchesAt' : 'newVideosAt');
    }
  }

  // Auto-fetched YouTube videos are re-created by the hourly script if they
  // are deleted, so those are HIDDEN instead (the script never un-hides
  // them). Everything else is deleted for real.
  Future<void> deleteVideo(String id, {String? batchId, String source = 'upload'}) async {
    if (source == 'youtube_auto') {
      await _db.collection('videos').doc(id).update({'hidden': true});
      return;
    }
    await _db.collection('videos').doc(id).delete();
    await _bumpBatchCount(batchId, 'videos', -1);
  }

  // ---- Video folders (one batch per folder; batchId == 'free' for the
  // free Video Classes section) ----
  Stream<List<VideoFolderModel>> streamVideoFolders(String batchId, {bool cache = false, bool force = false}) => _listStream<VideoFolderModel>(
        key: 'videoFolders_$batchId',
        q: _db.collection('videoFolders').where('batchId', isEqualTo: batchId),
        build: VideoFolderModel.fromMap,
        post: (list) {
          list.sort((a, b) => compareOrderThenCreated(a.order, b.order, a.createdAt, b.createdAt, a.name, b.name));
          return list;
        },
        cache: cache,
        force: force,
        ttl: const Duration(hours: 6),
        markers: const ['newVideosAt', 'newBatchesAt'],
      );

  Stream<List<VideoFolderModel>> streamFreeVideoFolders({bool cache = false, bool force = false}) =>
      streamVideoFolders(kFreeVideoBatchId, cache: cache, force: force);

  Future<void> addVideoFolder(VideoFolderModel f) =>
      _db.collection('videoFolders').add({...f.toMap(), 'createdAt': FieldValue.serverTimestamp()});

  // Rename a video folder (only the name field changes; videos stay linked by id).
  Future<void> renameVideoFolder(String id, String newName) =>
      _db.collection('videoFolders').doc(id).update({'name': newName.trim()});

  // Deletes the folder together with all videos inside it.
  Future<void> deleteVideoFolder(String id) async {
    final ref = _db.collection('videoFolders').doc(id);
    String? batchId;
    try {
      final snap = await ref.get();
      final data = snap.data();
      batchId = data == null ? null : data['batchId'] as String?;
    } catch (_) {
      batchId = null;
    }
    final removed = await _deleteAll(_db.collection('videos').where('folderId', isEqualTo: id));
    await ref.delete();
    await _bumpBatchCount(batchId, 'videos', -removed);
  }

  // Number of videos inside a folder (server-side count). Uses the same
  // folderId query the folder screen uses, which the Firestore rules allow.
  Future<int> countVideosInFolder(String folderId) async {
    final agg = await _db.collection('videos').where('folderId', isEqualTo: folderId).count().get();
    return agg.count ?? 0;
  }

  Stream<List<VideoModel>> streamVideosInFolder(String folderId, {bool cache = false, bool force = false}) => _listStream<VideoModel>(
        key: 'videosIn_$folderId',
        q: _db.collection('videos').where('folderId', isEqualTo: folderId),
        build: VideoModel.fromMap,
        post: (all) {
          final list = all.where((v) => !v.hidden).toList();
          list.sort((a, b) => compareOrderThenCreated(a.order, b.order, a.createdAt, b.createdAt, a.title, b.title));
          return list;
        },
        cache: cache,
        force: force,
        ttl: const Duration(hours: 6),
        markers: const ['newVideosAt', 'newBatchesAt'],
      );

  // ---- News ----
  Stream<List<NewsItemModel>> streamNews(List<String> categories, {bool cache = false, bool force = false}) {
    return _listStream<NewsItemModel>(
      key: 'news_${categories.join(',')}',
      q: _db.collection('newsItems').where('category', whereIn: categories).orderBy('pubDate', descending: true).limit(30),
      build: NewsItemModel.fromMap,
      cache: cache,
      force: force,
      ttl: const Duration(minutes: 30),
    );
  }

  // ---- Daily current-affairs one-liners (auto-filled from PIB) ----
  // Ek din = ek document (dailyCA/{yyyy-MM-dd}) jisme 'items' list hai, taaki
  // free plan ki reads kam rahein (ek din dekhna = 1 read).
  Stream<List<DailyCAModel>> streamDailyCA(String dateKey) {
    return _db.collection('dailyCA').doc(dateKey).snapshots().map((snap) {
      final data = snap.data();
      final List<dynamic> raw = data == null ? <dynamic>[] : ((data['items'] as List<dynamic>?) ?? <dynamic>[]);
      final list = <DailyCAModel>[];
      for (final e in raw) {
        if (e is Map) {
          final item = DailyCAModel.fromMap(dateKey, Map<String, dynamic>.from(e));
          if (item.id.isNotEmpty && (item.en.isNotEmpty || item.hi.isNotEmpty)) list.add(item);
        }
      }
      list.sort((a, b) => b.sortKey.compareTo(a.sortKey));
      return list;
    });
  }

  // Admin-only (Firestore rules enforce it): ek galat line hatao.
  Future<void> deleteDailyCA(String dateKey, String id) async {
    final ref = _db.collection('dailyCA').doc(dateKey);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return;
      final List<dynamic> raw = (data['items'] as List<dynamic>?) ?? <dynamic>[];
      final kept = raw.where((e) => !(e is Map && e['id'] == id)).toList();
      tx.update(ref, {'items': kept});
    });
  }

  // ---- Student profile (students/{uid}) ----
  // uid = Firebase Auth uid, so security rules can do a simple
  // request.auth.uid == uid check — no email lookup needed.
  Future<void> saveStudentProfile(StudentModel student) =>
      _db.collection('students').doc(student.uid).set(student.toMap(), SetOptions(merge: true));

  Future<StudentModel?> getStudentProfile(String uid) async {
    final doc = await _db.collection('students').doc(uid).get().timeout(const Duration(seconds: 12));
    if (!doc.exists || doc.data() == null) return null;
    return StudentModel.fromMap(doc.id, doc.data()!);
  }

  Stream<StudentModel?> streamStudentProfile(String uid) => _db
      .collection('students')
      .doc(uid)
      .snapshots()
      .map((doc) => (doc.exists && doc.data() != null) ? StudentModel.fromMap(doc.id, doc.data()!) : null);

  // ---- Batch access (payment grant / revoke) ----
  // HONEST NOTE about security: students do log in now (Firebase Auth), but
  // the Firestore data of paid batches is still readable by every app user. The
  // email + code check below stops normal students from opening a batch
  // they have not paid for, but it is NOT strong protection against a
  // technical person who calls Firestore directly. Real protection needs
  // rules that tie paid content to a paid, logged-in account (and a paid
  // host for the files), which is a bigger change. See FIX_REPORT.md.
  //
  // Throws if there is no internet / the read fails — callers must catch.
  //
  // TIME LIMIT (batch validity): a grant can carry an `expiresAt` date.
  //  1. This method compares it with the phone's clock (works even before
  //     the new Firestore rules are published), and
  //  2. the Firestore rules refuse to hand out an expired access record at
  //     all (they compare with the SERVER's clock), so changing the phone's
  //     date does not bring an expired batch back. That refusal arrives here
  //     as "permission-denied", which is reported as expired.
  Future<AccessCheck> checkAccess(String email, String batchId, String code) async {
    try {
      final id = '${email.trim().toLowerCase()}_$batchId';
      final doc = await _db.collection('batchAccess').doc(id).get().timeout(const Duration(seconds: 12));
      final data = doc.data();
      if (!doc.exists || data == null || data['status'] != 'granted') return const AccessCheck();
      // The access code IS required: the admin gives it to the student after
      // verifying the payment. A granted record alone is not enough — without
      // the right code (empty / wrong) nothing is unlocked and nothing about
      // the record (e.g. its expiry) is revealed.
      // EXCEPTION: a grant the admin made by hand ("Manual grant") is saved
      // with codeRequired == false — the student's email alone is enough.
      // Every other grant (also all older ones) still needs the code.
      final codeRequired = data['codeRequired'] != false;
      if (codeRequired) {
        final savedCode = (data['accessCode'] ?? '').toString().trim();
        if (savedCode.isEmpty || savedCode != code.trim()) return const AccessCheck();
      }
      final exp = (data['expiresAt'] as Timestamp?)?.toDate();
      if (exp != null && !DateTime.now().isBefore(exp)) return AccessCheck(expired: true, expiresAt: exp);
      return AccessCheck(granted: true, expiresAt: exp);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return const AccessCheck(expired: true);
      rethrow;
    }
  }

  // Simple yes/no version (true only if the code is right and not expired).
  Future<bool> hasAccess(String email, String batchId, String code) async =>
      (await checkAccess(email, batchId, code)).granted;

  // Returns the freshly generated access code (and the date the access runs
  // out) so the caller (admin UI) can show it to the admin to pass along to
  // the student. [months] = how long the access lasts; 0 = lifetime.
  // Granting again (renewal) replaces the old record, so it gets a fresh
  // code and a fresh time limit.
  //
  // [requireCode] = true (default): a 6-digit code is made and the student
  // must enter it (this is the normal flow after an Access Request).
  // [requireCode] = false: Manual grant — no code is made and the student
  // does not need one; logging in with the same email is enough.
  Future<GrantResult> grantAccess(String email, String batchId, {int months = 0, bool requireCode = true}) async {
    final clean = email.trim();
    final id = '${clean.toLowerCase()}_$batchId';
    final code = requireCode ? (100000 + Random().nextInt(900000)).toString() : ''; // 6 digits
    final expiresAt = months > 0 ? addMonthsEndOfDay(DateTime.now(), months) : null;
    await _db.collection('batchAccess').doc(id).set({
      'studentEmail': clean,
      'batchId': batchId,
      'status': 'granted',
      'accessCode': code,
      'codeRequired': requireCode,
      'grantedAt': FieldValue.serverTimestamp(),
      'grantedBy': 'admin',
      'validityMonths': months,
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
    });
    // Clears the pending request (if the student used the in-app
    // "Check Access" flow) so it disappears from the admin's queue. No-op
    // (and no error) if no such request exists — e.g. manual grants.
    await _db.collection('accessRequests').doc(id).delete();
    return GrantResult(code, expiresAt, codeRequired: requireCode);
  }

  // Adds [months] to a student's access. Counted from today, or from the
  // current expiry date if that is still in the future (so a renewal made
  // early doesn't lose the days that were left). Returns the new expiry.
  Future<DateTime> extendAccess(String email, String batchId, int months) async {
    final ref = _db.collection('batchAccess').doc('${email.trim().toLowerCase()}_$batchId');
    final snap = await ref.get();
    final data = snap.data();
    if (!snap.exists || data == null) throw StateError('No access record found for this student.');
    final current = (data['expiresAt'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    final base = (current != null && current.isAfter(now)) ? current : now;
    final newExpiry = addMonthsEndOfDay(base, months);
    await ref.set({'expiresAt': Timestamp.fromDate(newExpiry)}, SetOptions(merge: true));
    return newExpiry;
  }

  // Removes the time limit of one student's access (lifetime).
  Future<void> makeAccessLifetime(String email, String batchId) => _db
      .collection('batchAccess')
      .doc('${email.trim().toLowerCase()}_$batchId')
      .set({'expiresAt': null, 'validityMonths': 0}, SetOptions(merge: true));

  // Every student who currently has access (for the admin "Granted
  // students" list, so access can be taken back).
  Stream<List<AccessGrantModel>> streamGrants() => _db
          .collection('batchAccess')
          .where('status', isEqualTo: 'granted')
          .snapshots()
          .map((snap) {
        final list = snap.docs.map((d) => AccessGrantModel.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => a.studentEmail.toLowerCase().compareTo(b.studentEmail.toLowerCase()));
        return list;
      });

  // Takes access back (the student is locked out the next time the batch
  // is opened).
  Future<void> revokeAccess(String email, String batchId) => _db
      .collection('batchAccess')
      .doc('${email.trim().toLowerCase()}_$batchId')
      .set({'status': 'revoked'}, SetOptions(merge: true));

  // For the "✅ Unlocked" badge on the Batches list only — NOT a security
  // check (that stays in hasAccess/BatchDetailScreen exactly as before).
  // batchAccess only allows a public single-document `get` (see
  // firestore.rules) — a `where(...)` query is a `list`, which the rules
  // correctly restrict to admin only (otherwise anyone could dump every
  // paying student's email). So this checks one doc per batch id (all in
  // parallel) instead of running a collection query.
  Future<Set<String>> grantedBatchIds(String email, List<String> batchIds) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty || batchIds.isEmpty) return const <String>{};
    final out = <String>{};
    final prefs = await SharedPreferences.getInstance();
    await Future.wait(batchIds.map((id) async {
      try {
        final doc = await _db.collection('batchAccess').doc('${clean}_$id').get().timeout(const Duration(seconds: 10));
        final data = doc.data();
        final exp = (data?['expiresAt'] as Timestamp?)?.toDate();
        final expired = exp != null && !DateTime.now().isBefore(exp);
        // Badge only when the student has entered the right code on this phone
        // (a manual grant has no code, so it shows the badge straight away).
        final savedCode = (prefs.getString('access_code_$id') ?? '').trim();
        final realCode = (data?['accessCode'] ?? '').toString().trim();
        final codeRequired = data?['codeRequired'] != false;
        final codeOk = codeRequired ? (realCode.isNotEmpty && realCode == savedCode) : true;
        if (data != null && data['status'] == 'granted' && !expired && codeOk) {
          out.add(id);
        }
      } catch (_) {
        // offline / no access doc for this batch — it just won't show the badge
      }
    }));
    return out;
  }

  // ---- Access requests (student submits after payment; admin sees a
  // pending queue in Grants tab instead of needing the email texted separately) ----
  Future<void> submitAccessRequest(String email, String batchId, String batchTitle, {String phone = '', String name = ''}) => _db
      .collection('accessRequests')
      .doc('${email.trim().toLowerCase()}_$batchId')
      .set({
        'studentName': name.trim(),
        'studentEmail': email.trim().toLowerCase(),
        'studentPhone': phone.trim(),
        'batchId': batchId,
        'batchTitle': batchTitle,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

  Stream<List<AccessRequestModel>> streamPendingRequests() => _db
      .collection('accessRequests')
      .orderBy('requestedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => AccessRequestModel.fromMap(d.id, d.data())).toList());

  Future<void> dismissAccessRequest(String requestId) => _db.collection('accessRequests').doc(requestId).delete();

  // ---- Install counter (only counting, no personal data) ----
  Future<void> recordInstall(String anonId) => _db.collection('installs').doc(anonId).set(
      {'firstOpenAt': FieldValue.serverTimestamp(), 'lastActiveAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  // "Active today" ping — the app calls this at most once per phone per day.
  // The security rules let an unauthenticated app change ONLY this field.
  Future<void> recordActive(String anonId) =>
      _db.collection('installs').doc(anonId).set({'lastActiveAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  // How many phones opened the app on/after [since] (server-side count, so it
  // costs only 1 read per 1000 matching phones).
  Future<int> activeCountSince(DateTime since) async {
    final agg = await _db
        .collection('installs')
        .where('lastActiveAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .count()
        .get();
    return agg.count ?? 0;
  }

  // Uses Firestore's server-side count, so it costs 1 read per 1000 installs
  // instead of downloading every install document.
  Future<int> installCount() async {
    final agg = await _db.collection('installs').count().get();
    return agg.count ?? 0;
  }

  // ---- Registered students (App + Web signups, counts only) ----
  // Both the App and the Web sign-up write students/{uid}. `source` says where
  // the account was created ('app' / 'web'); `createdAt` says when. Students
  // created before this field existed have neither, so "App" is worked out as
  // total - web instead of being counted directly.
  Future<void> markSignupSource(String uid, String source) => _db
      .collection('students')
      .doc(uid)
      .set({'source': source, 'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  Future<int> studentCount() async {
    final agg = await _db.collection('students').count().get();
    return agg.count ?? 0;
  }

  Future<int> studentCountFromSource(String source) async {
    final agg = await _db.collection('students').where('source', isEqualTo: source).count().get();
    return agg.count ?? 0;
  }

  Future<int> studentsSignedUpSince(DateTime since) async {
    final agg = await _db
        .collection('students')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .count()
        .get();
    return agg.count ?? 0;
  }

  // ---- PDF folders (Free PDFs vs Paid Batch PDFs) ----
  // batchId given = the folders shown inside that paid batch. A folder can
  // be in up to 3 batches (field `batchIds`); folders made before that only
  // have the single `batchId`, so both are matched (OR query).
  Stream<List<PdfFolderModel>> streamFolders({required String type, String? batchId, bool cache = false, bool force = false}) {
    final Query<Map<String, dynamic>> q = batchId != null
        ? _db.collection('pdfFolders').where(Filter.or(
              Filter('batchIds', arrayContains: batchId),
              Filter('batchId', isEqualTo: batchId),
            ))
        : _db.collection('pdfFolders').where('type', isEqualTo: type);
    return _listStream<PdfFolderModel>(
      key: 'pdfFolders_${type}_${batchId ?? ''}',
      q: q,
      build: PdfFolderModel.fromMap,
      post: (list) {
        list.sort((a, b) => compareOrderThenCreated(a.order, b.order, a.createdAt, b.createdAt, a.name, b.name));
        return list;
      },
      cache: cache,
      force: force,
      ttl: const Duration(hours: 6),
      markers: const ['newPdfsAt', 'newBatchesAt'],
    );
  }

  // Switch the monthly auto MCQ PDFs on / off for one FREE folder.
  Future<void> setPdfFolderAutoMcq(String folderId, bool on) =>
      _db.collection('pdfFolders').doc(folderId).update({'autoMonthlyMcq': on});

  Future<void> addFolder(PdfFolderModel f) =>
      _db.collection('pdfFolders').add({...f.toMap(), 'createdAt': FieldValue.serverTimestamp()});

  Stream<List<PdfModel>> streamPdfsInFolder(String folderId, {bool cache = false, bool force = false}) => _listStream<PdfModel>(
        key: 'pdfsIn_$folderId',
        q: _db.collection('pdfs').where('folderId', isEqualTo: folderId),
        build: PdfModel.fromMap,
        post: (list) {
          list.sort((a, b) => compareOrderThenCreated(a.order, b.order, a.createdAt, b.createdAt, a.title, b.title));
          return list;
        },
        cache: cache,
        force: force,
        ttl: const Duration(hours: 6),
        markers: const ['newPdfsAt', 'newBatchesAt'],
      );

  // ---- Notifications ----
  // "sent: false" lets the free GitHub Actions script (or the paid Cloud
  // Function, if you deploy that instead) find this and push it via FCM,
  // then flip it to true so it's never sent twice.
  // [topic] khali = sabhi students; 'exam_...' = sirf us exam ke students
  // (send-notifications.js usi FCM topic par bhejta hai).
  Future<void> sendNotification(String title, String body, {String topic = ''}) => _db.collection('notifications').add({
        'title': title,
        'body': body,
        if (topic.isNotEmpty) 'topic': topic,
        'sent': false,
        'sentAt': FieldValue.serverTimestamp(),
      });

  Stream<List<NotificationModel>> streamNotifications() {
    // App only shows the last 1 day of notifications. This is just a display
    // filter - it does not delete anything from Firebase. Change `days: 1`
    // here to show more/less without touching anything else.
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1)));
    return _db
        .collection('notifications')
        .where('sentAt', isGreaterThan: cutoff)
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => NotificationModel.fromMap(d.id, d.data())).toList());
  }

  // ---- Mock Tests ----
  Stream<List<MockTestFolderModel>> streamMockFolders({bool cache = false, bool force = false}) => _listStream<MockTestFolderModel>(
        key: 'mockFoldersAll',
        q: _db.collection('mockTestFolders'),
        build: MockTestFolderModel.fromMap,
        post: (list) {
          list.sort((a, b) => compareOrderThenCreated(a.order, b.order, a.createdAt, b.createdAt, a.examName, b.examName));
          return list;
        },
        cache: cache,
        force: force,
        ttl: const Duration(hours: 6),
        markers: const ['newMocksAt', 'newBatchesAt'],
      );

  Future<void> addMockFolder(String examName) =>
      _db.collection('mockTestFolders').add({'examName': examName, 'batchIds': <String>[], 'createdAt': FieldValue.serverTimestamp()});

  // Only the FREE folders (no batch) - for the public Mock Tests screen.
  Stream<List<MockTestFolderModel>> streamFreeMockFolders({bool cache = false, bool force = false}) =>
      streamMockFolders(cache: cache, force: force).map((list) => list.where((f) => f.batchIds.isEmpty).toList());

  // Folders added to one paid batch (shown in that batch's "Mocks" tab).
  Stream<List<MockTestFolderModel>> streamMockFoldersForBatch(String batchId, {bool cache = false, bool force = false}) => _listStream<MockTestFolderModel>(
        key: 'mockFoldersBatch_$batchId',
        q: _db.collection('mockTestFolders').where('batchIds', arrayContains: batchId),
        build: MockTestFolderModel.fromMap,
        post: (list) {
          list.sort((a, b) => compareOrderThenCreated(a.order, b.order, a.createdAt, b.createdAt, a.examName, b.examName));
          return list;
        },
        cache: cache,
        force: force,
        ttl: const Duration(hours: 6),
        markers: const ['newMocksAt', 'newBatchesAt'],
      );

  // Admin: which paid batches a folder belongs to ([] = free).
  Future<void> setMockFolderBatches(String folderId, List<String> batchIds) async {
    await _db.collection('mockTestFolders').doc(folderId).update({'batchIds': batchIds});
    // Folder just became free -> new for Mock Tests; just added to a batch -> new for Paid Batches.
    await _markUpdated(batchIds.isEmpty ? 'newMocksAt' : 'newBatchesAt');
  }

  // Rename an exam folder (only examName changes; tests stay linked by id).
  Future<void> renameMockFolder(String id, String newName) =>
      _db.collection('mockTestFolders').doc(id).update({'examName': newName.trim()});

  // Deletes the exam folder together with all tests inside it.
  Future<void> deleteMockFolder(String id) async {
    await _deleteAll(_db.collection('mockTests').where('folderId', isEqualTo: id));
    await _db.collection('mockTestFolders').doc(id).delete();
  }

  Stream<List<MockTestModel>> streamMockTests(String folderId, {bool cache = false, bool force = false}) => _listStream<MockTestModel>(
        key: 'mockTests_$folderId',
        q: _db.collection('mockTests').where('folderId', isEqualTo: folderId),
        build: MockTestModel.fromMap,
        post: (list) {
          list.sort((a, b) => compareOrderThenCreated(a.order, b.order, a.createdAt, b.createdAt, a.title, b.title));
          return list;
        },
        cache: cache,
        force: force,
        // Mock tests are big documents (all questions), so this is the most valuable list to cache.
        ttl: const Duration(hours: 3),
        markers: const ['newMocksAt', 'newBatchesAt'],
      );

  Future<void> saveMockTest(MockTestModel t) async {
    if (t.id.isEmpty) {
      await _db.collection('mockTests').add({...t.toMap(), 'createdAt': FieldValue.serverTimestamp()});
      await _markMockUpdated(t.folderId); // only NEW tests light the dot, not edits
      return;
    }
    await _db.collection('mockTests').doc(t.id).set(t.toMap(), SetOptions(merge: true));
  }

  // Move a test to another exam folder / subject, and optionally set its Prelims / Mains category.
  Future<void> moveMockTest(String id, String folderId, String subject, {String? examStage}) =>
      _db.collection('mockTests').doc(id).update({
        'folderId': folderId,
        'subject': subject.trim(),
        if (examStage != null) 'examStage': normalizeMockStage(examStage),
      });

  Future<void> deleteMockTest(String id) => _db.collection('mockTests').doc(id).delete();

  // studentName / subject / folderId are optional: they are only written when there is something to write,
  // and they need the matching Firestore rule (mockTestAttempts create) to allow these 3 extra fields.
  Future<void> saveMockAttempt({
    required String studentEmail,
    required String mockTestId,
    required String mockTestTitle,
    required int score,
    required int total,
    required List<int?> answers,
    String studentName = '',
    String subject = '',
    String folderId = '',
  }) =>
      _db.collection('mockTestAttempts').add({
        'studentEmail': studentEmail,
        if (studentName.trim().isNotEmpty) 'studentName': _cut(studentName, 100),
        'mockTestId': mockTestId,
        'mockTestTitle': mockTestTitle,
        if (subject.trim().isNotEmpty) 'subject': _cut(subject, 100),
        if (folderId.trim().isNotEmpty) 'folderId': _cut(folderId, 100),
        'score': score,
        'total': total,
        'answers': answers,
        'submittedAt': FieldValue.serverTimestamp(),
      });

  static String _cut(String s, int max) {
    final t = s.trim();
    return t.length <= max ? t : t.substring(0, max);
  }

  // Admin Attempts tab only: remembered for this app run, so a refresh does not read them again.
  final Map<String, String> _attemptFolderNames = {}; // folderId -> exam name
  final Map<String, ({String folderId, String subject})?> _attemptTests = {}; // testId -> folder + subject (null = test deleted)

  // Admin "Attempts" tab (latest first).
  // One-time read (get), NOT a live listener, so Firestore reads are only
  // used when the admin opens / refreshes the tab. Only the latest 25 are read.
  Future<List<MockTestAttemptModel>> fetchMockAttempts({int limit = 25}) async {
    final snap = await _db
        .collection('mockTestAttempts')
        .orderBy('submittedAt', descending: true)
        .limit(limit)
        .get();
    final attempts = snap.docs.map((d) => MockTestAttemptModel.fromMap(d.id, d.data())).toList();
    try {
      return await _withAttemptContext(attempts);
    } catch (_) {
      return attempts; // the list still shows, just without the exam / subject line
    }
  }

  // Adds "exam folder > subject" to every attempt. New attempts store folderId + subject themselves; for older
  // attempts the test is read once (and remembered). The exam folder names come from one read of the small
  // mockTestFolders collection, only when a folder name is not known yet.
  Future<List<MockTestAttemptModel>> _withAttemptContext(List<MockTestAttemptModel> attempts) async {
    final oldTestIds = {
      for (final a in attempts)
        if (a.folderId.isEmpty && a.mockTestId.isNotEmpty && !_attemptTests.containsKey(a.mockTestId)) a.mockTestId,
    };
    for (final id in oldTestIds) {
      try {
        final m = (await _db.collection('mockTests').doc(id).get().timeout(const Duration(seconds: 8))).data();
        _attemptTests[id] = m == null ? null : (folderId: (m['folderId'] ?? '').toString(), subject: (m['subject'] ?? '').toString().trim());
      } catch (_) {
        // not remembered: tried again on the next refresh
      }
    }

    String folderOf(MockTestAttemptModel a) => a.folderId.isNotEmpty ? a.folderId : (_attemptTests[a.mockTestId]?.folderId ?? '');
    final wanted = {for (final a in attempts) folderOf(a)}..remove('');
    if (wanted.any((id) => !_attemptFolderNames.containsKey(id))) {
      final folders = await _db.collection('mockTestFolders').get();
      for (final d in folders.docs) {
        _attemptFolderNames[d.id] = (d.data()['examName'] ?? '').toString().trim();
      }
    }

    return attempts.map((a) {
      final folderId = folderOf(a);
      final subject = a.subject.isNotEmpty ? a.subject : (_attemptTests[a.mockTestId]?.subject ?? '');
      return a.withContext(folderId: folderId, subject: subject, examName: _attemptFolderNames[folderId] ?? '');
    }).toList();
  }

  // ---- Home banners (16:9 auto-scroll carousel, Admin Panel -> Banners) ----
  Stream<List<BannerModel>> streamBanners({bool cache = false, bool force = false}) => _listStream<BannerModel>(
        key: 'banners',
        q: _db.collection('banners').orderBy('order'),
        build: BannerModel.fromMap,
        cache: cache,
        force: force,
        ttl: const Duration(hours: 6),
      );

  // Auto-assigns the next order (current max + 1) so new banners land at
  // the end of the slider instead of the admin having to pick a number.
  Future<void> addBanner(String imageUrl, {String? linkUrl, String? batchId}) async {
    final last = await _db.collection('banners').orderBy('order', descending: true).limit(1).get();
    final nextOrder = last.docs.isEmpty ? 0 : ((last.docs.first.data()['order'] as num?)?.toInt() ?? 0) + 1;
    await _db.collection('banners').add({
      'imageUrl': imageUrl,
      if (linkUrl != null) 'linkUrl': linkUrl,
      if (batchId != null) 'batchId': batchId,
      'order': nextOrder,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBanner(String id) => _db.collection('banners').doc(id).delete();

  // ---- App branding (logo + name/tagline/UPI id/social links) ----
  Stream<AppConfigModel> streamAppConfig() => _db
      .collection('appConfig')
      .doc('main')
      .snapshots()
      .map((doc) => AppConfigModel.fromMap(doc.data()));

  Future<void> setAppConfig(AppConfigModel c) =>
      _db.collection('appConfig').doc('main').set(c.toMap(), SetOptions(merge: true));

  Future<void> setAppLogoUrl(String url) =>
      _db.collection('appConfig').doc('main').set({'logoUrl': url}, SetOptions(merge: true));

  // ====================================================================
  // ---- COPY FOLDER (Admin Panel) ----
  // Copies a whole folder with everything inside it into one or more
  // places at once: a paid batch, or the FREE section. The copy is fully
  // independent (new folder + new items) - editing or deleting the copy
  // never touches the original, and the original stays where it was.
  //
  // [destinations]: a paid batch id, or kCopyFreeDest for the free section.
  // The items keep the order the admin arranged them in.
  // ====================================================================

  // Runs many writes in chunks (Firestore allows 500 per commit; mock tests
  // are big documents so their chunk is smaller to stay under the size limit).
  Future<void> _runWrites(List<void Function(WriteBatch b)> ops, {int chunk = 400}) async {
    var batch = _db.batch();
    var n = 0;
    for (final op in ops) {
      op(batch);
      n++;
      if (n >= chunk) {
        await batch.commit();
        batch = _db.batch();
        n = 0;
      }
    }
    if (n > 0) await batch.commit();
  }

  // PDF folder -> every destination. Returns how many PDFs were copied per
  // destination.
  Future<int> copyPdfFolder(String folderId, List<String> destinations) async {
    if (destinations.isEmpty) return 0;
    final folderSnap = await _db.collection('pdfFolders').doc(folderId).get();
    final fData = folderSnap.data();
    if (fData == null) throw StateError('The folder no longer exists.');
    final name = (fData['name'] ?? '').toString();
    final pdfSnap = await _db.collection('pdfs').where('folderId', isEqualTo: folderId).get();
    final pdfs = pdfSnap.docs.map((d) => PdfModel.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => compareOrderThenCreated(a.order, b.order, a.createdAt, b.createdAt, a.title, b.title));

    for (final dest in destinations.toSet()) {
      final isFree = dest == kCopyFreeDest;
      final folderRef = _db.collection('pdfFolders').doc();
      final ops = <void Function(WriteBatch b)>[
        (b) => b.set(folderRef, {
              'name': name,
              'type': isFree ? 'free' : 'batch',
              'batchId': isFree ? null : dest,
              'batchIds': isFree ? <String>[] : <String>[dest],
              'createdAt': FieldValue.serverTimestamp(),
            }),
      ];
      for (var i = 0; i < pdfs.length; i++) {
        final p = pdfs[i];
        ops.add((b) => b.set(_db.collection('pdfs').doc(), {
              'title': p.title,
              'iconUrl': p.iconUrl,
              'driveLink': p.driveLink,
              'batchId': isFree ? null : dest,
              'folderId': folderRef.id,
              'order': i,
              'createdAt': FieldValue.serverTimestamp(),
            }));
      }
      await _runWrites(ops);
      if (!isFree) await _bumpBatchCount(dest, 'pdfs', pdfs.length);
    }
    if (destinations.any((d) => d != kCopyFreeDest)) await _markUpdated('newBatchesAt');
    if (destinations.contains(kCopyFreeDest)) await _markUpdated('newPdfsAt');
    return pdfs.length;
  }

  // Video folder -> every destination (auto-fetched YouTube videos are never
  // inside folders, and hidden videos are skipped).
  Future<int> copyVideoFolder(String folderId, List<String> destinations) async {
    if (destinations.isEmpty) return 0;
    final folderSnap = await _db.collection('videoFolders').doc(folderId).get();
    final fData = folderSnap.data();
    if (fData == null) throw StateError('The folder no longer exists.');
    final name = (fData['name'] ?? '').toString();
    final vSnap = await _db.collection('videos').where('folderId', isEqualTo: folderId).get();
    final videos = vSnap.docs
        .map((d) => VideoModel.fromMap(d.id, d.data()))
        .where((v) => !v.hidden)
        .toList()
      ..sort((a, b) => compareOrderThenCreated(a.order, b.order, a.createdAt, b.createdAt, a.title, b.title));

    for (final dest in destinations.toSet()) {
      final isFree = dest == kCopyFreeDest;
      final folderRef = _db.collection('videoFolders').doc();
      final ops = <void Function(WriteBatch b)>[
        (b) => b.set(folderRef, {
              'name': name,
              'batchId': isFree ? kFreeVideoBatchId : dest,
              'createdAt': FieldValue.serverTimestamp(),
            }),
      ];
      for (var i = 0; i < videos.length; i++) {
        final v = videos[i];
        ops.add((b) => b.set(_db.collection('videos').doc(), {
              'title': v.title,
              'thumbUrl': v.thumbUrl,
              'youtubeLink': v.youtubeLink,
              'batchId': isFree ? null : dest, // free videos have batchId null
              'folderId': folderRef.id,
              'source': 'upload',
              'order': i,
              'createdAt': FieldValue.serverTimestamp(),
            }));
      }
      await _runWrites(ops);
      if (!isFree) await _bumpBatchCount(dest, 'videos', videos.length);
    }
    if (destinations.any((d) => d != kCopyFreeDest)) await _markUpdated('newBatchesAt');
    if (destinations.contains(kCopyFreeDest)) await _markUpdated('newVideosAt');
    return videos.length;
  }

  // Mock exam folder -> every destination. [onlySubject] = copy just one
  // subject folder of the exam (e.g. "Maths"); null = every test of the exam.
  // The new exam folder gets the same name and the tests keep their subject.
  Future<int> copyMockFolder(String folderId, List<String> destinations, {String? onlySubject}) async {
    if (destinations.isEmpty) return 0;
    final folderSnap = await _db.collection('mockTestFolders').doc(folderId).get();
    final fData = folderSnap.data();
    if (fData == null) throw StateError('The folder no longer exists.');
    final name = (fData['examName'] ?? '').toString();
    final tSnap = await _db.collection('mockTests').where('folderId', isEqualTo: folderId).get();
    var docs = tSnap.docs.toList();
    if (onlySubject != null) {
      final key = mockSubjectKey(onlySubject);
      docs = docs.where((d) => mockSubjectKey((d.data()['subject'] ?? '').toString()) == key).toList();
    }
    final tests = docs.map((d) => MapEntry(MockTestModel.fromMap(d.id, d.data()), d.data())).toList()
      ..sort((a, b) => compareOrderThenCreated(a.key.order, b.key.order, a.key.createdAt, b.key.createdAt, a.key.title, b.key.title));

    for (final dest in destinations.toSet()) {
      final isFree = dest == kCopyFreeDest;
      final folderRef = _db.collection('mockTestFolders').doc();
      final ops = <void Function(WriteBatch b)>[
        (b) => b.set(folderRef, {
              'examName': name,
              'batchIds': isFree ? <String>[] : <String>[dest],
              'createdAt': FieldValue.serverTimestamp(),
            }),
      ];
      for (var i = 0; i < tests.length; i++) {
        final raw = Map<String, dynamic>.from(tests[i].value); // every field (questions, timer, marks ...) is kept
        raw['folderId'] = folderRef.id;
        raw['order'] = i;
        raw['createdAt'] = FieldValue.serverTimestamp();
        ops.add((b) => b.set(_db.collection('mockTests').doc(), raw));
      }
      await _runWrites(ops, chunk: 8);
    }
    if (destinations.any((d) => d != kCopyFreeDest)) await _markUpdated('newBatchesAt');
    if (destinations.contains(kCopyFreeDest)) await _markUpdated('newMocksAt');
    return tests.length;
  }

  // ====================================================================
  // ---- FREE MCQs -> MOCK TESTS (Admin Panel > Free MCQs) ----
  // Copies the weekly sets of one Free MCQs exam folder into the Mock Tests
  // section (and / or paid batches) as real mock tests:
  //   exam folder  -> mock exam folder (same name)
  //   subject      -> mock subject folder (English has none)
  //   weekly set   -> one mock test (all questions, Hindi + explanation kept)
  // The timer / marks / negative marks come from [settings].
  // If the destination already has an exam folder with the same name it is
  // REUSED and tests that are already there (same subject + title) are
  // skipped, so copying again only adds the new weeks. The newest week is
  // shown first. Nothing is removed here - "Move" is done by the caller.
  // ====================================================================
  Future<({int added, int skipped})> copyFreeMcqExamToMocks({
    required FreeMcqChoice exam,
    required FreeMcqIndex index,
    required List<String> destinations,
    required FreeMcqSettings settings,
    String? onlySubjectId,
  }) async {
    if (destinations.isEmpty) return (added: 0, skipped: 0);
    var metas = index.setsForExam(exam.id); // newest week first
    if (onlySubjectId != null) metas = metas.where((m) => m.subjectId == onlySubjectId).toList();
    if (metas.isEmpty) throw StateError('This folder has no sets yet.');

    // 1) Read every set first, so nothing is written if one of them cannot be read.
    final svc = FreeMcqService();
    final sets = <FreeMcqSet>[];
    for (final m in metas) {
      sets.add(await svc.loadSet(m));
    }
    final tests = <MockTestModel>[];
    for (var i = 0; i < metas.length; i++) {
      tests.add(FreeMcqService.toMockTest(
        meta: metas[i],
        subjectName: index.subjectName(metas[i].subjectId),
        subject: exam.id == kEnglishFolderId ? '' : index.subjectName(metas[i].subjectId),
        set: sets[i],
        settings: settings,
        id: '',
        folderId: '',
      ));
    }

    // 2) Existing mock folders (to reuse a folder with the same name).
    final folderSnap = await _db.collection('mockTestFolders').get();
    final wantedName = exam.name.trim().toLowerCase();
    var added = 0;
    var skipped = 0;

    for (final dest in destinations.toSet()) {
      final isFree = dest == kCopyFreeDest;
      QueryDocumentSnapshot<Map<String, dynamic>>? existing;
      for (final d in folderSnap.docs) {
        final data = d.data();
        if ((data['examName'] ?? '').toString().trim().toLowerCase() != wantedName) continue;
        final ids = data['batchIds'] is List ? (data['batchIds'] as List).map((e) => e.toString()).toList() : <String>[];
        if (isFree ? ids.isEmpty : ids.contains(dest)) {
          existing = d;
          break;
        }
      }

      final folderRef = existing?.reference ?? _db.collection('mockTestFolders').doc();
      final doneKeys = <String>{};
      int? lowestOrder;
      if (existing != null) {
        final old = await _db.collection('mockTests').where('folderId', isEqualTo: folderRef.id).get();
        for (final d in old.docs) {
          final data = d.data();
          doneKeys.add('${mockSubjectKey((data['subject'] ?? '').toString())}|${(data['title'] ?? '').toString().trim().toLowerCase()}');
          final o = data['order'];
          if (o is num && (lowestOrder == null || o.toInt() < lowestOrder)) lowestOrder = o.toInt();
        }
      }

      final fresh = tests
          .where((t) => !doneKeys.contains('${mockSubjectKey(t.subject)}|${t.title.trim().toLowerCase()}'))
          .toList();
      skipped += tests.length - fresh.length;
      if (fresh.isEmpty) continue;

      final ops = <void Function(WriteBatch b)>[];
      if (existing == null) {
        ops.add((b) => b.set(folderRef, {
              'examName': exam.name.trim(),
              'batchIds': isFree ? <String>[] : <String>[dest],
              'createdAt': FieldValue.serverTimestamp(),
            }));
      }
      // New weeks go on top of what the folder already has.
      final base = (lowestOrder ?? 0) - fresh.length;
      for (var i = 0; i < fresh.length; i++) {
        final raw = <String, dynamic>{
          ...fresh[i].toMap(),
          'folderId': folderRef.id,
          'order': existing == null ? i : base + i,
          'createdAt': FieldValue.serverTimestamp(),
        };
        ops.add((b) => b.set(_db.collection('mockTests').doc(), raw));
      }
      await _runWrites(ops, chunk: 8);
      added += fresh.length;
    }
    if (added > 0) {
      if (destinations.any((d) => d != kCopyFreeDest)) await _markUpdated('newBatchesAt');
      if (destinations.contains(kCopyFreeDest)) await _markUpdated('newMocksAt');
    }
    return (added: added, skipped: skipped);
  }
}
