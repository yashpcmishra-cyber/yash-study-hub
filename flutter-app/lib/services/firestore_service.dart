import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import '../models/models.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ---- small helpers ----

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

  // ---- Batches ----
  // Oldest first (the order the admin added them).
  Stream<List<BatchModel>> streamBatches() => _db.collection('batches').snapshots().map((snap) {
        final list = snap.docs.map((d) => BatchModel.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => compareCreatedAsc(a.createdAt, b.createdAt, a.title, b.title));
        return list;
      });

  Future<void> addBatch(BatchModel b) =>
      _db.collection('batches').add({...b.toMap(), 'createdAt': FieldValue.serverTimestamp()});

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
  Future<void> deleteBatch(String id) async {
    await _deleteAll(_db.collection('pdfs').where('batchId', isEqualTo: id));
    await _deleteAll(_db.collection('videos').where('batchId', isEqualTo: id));
    await _deleteAll(_db.collection('pdfFolders').where('batchId', isEqualTo: id));
    await _deleteAll(_db.collection('videoFolders').where('batchId', isEqualTo: id));
    await _deleteAll(_db.collection('accessRequests').where('batchId', isEqualTo: id));
    await _deleteAll(_db.collection('batchAccess').where('batchId', isEqualTo: id));
    await _db.collection('batches').doc(id).delete();
  }

  // ---- PDFs ----
  Future<void> addPdf(PdfModel p) async {
    await _db.collection('pdfs').add({...p.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    await _bumpBatchCount(p.batchId, 'pdfs', 1);
  }

  Future<void> deletePdf(String id, {String? batchId}) async {
    await _db.collection('pdfs').doc(id).delete();
    await _bumpBatchCount(batchId, 'pdfs', -1);
  }

  // Deletes the folder together with all PDFs inside it.
  Future<void> deletePdfFolder(String id, {String? batchId}) async {
    final removed = await _deleteAll(_db.collection('pdfs').where('folderId', isEqualTo: id));
    await _db.collection('pdfFolders').doc(id).delete();
    await _bumpBatchCount(batchId, 'pdfs', -removed);
  }

  // ---- Videos ----
  // Free/public videos ONLY (batchId explicitly null in Firestore) — this
  // is what the "Video Classes" screen uses, so a paid batch's videos never
  // show up in the free section. Newest first. Videos the admin "hid"
  // (auto-fetched ones) are left out.
  Stream<List<VideoModel>> streamFreeVideos() => _db
          .collection('videos')
          .where('batchId', isEqualTo: null)
          .snapshots()
          .map((snap) {
        final list = snap.docs
            .map((d) => VideoModel.fromMap(d.id, d.data()))
            .where((v) => !v.hidden)
            .toList();
        list.sort(compareVideosNewestFirst);
        return list;
      });

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
  Stream<List<VideoModel>> streamAutoFetchedVideos({int limit = 10}) => _db
          .collection('videos')
          .where('source', isEqualTo: 'youtube_auto')
          .limit(50)
          .snapshots()
          .map((snap) {
        final list = snap.docs
            .map((d) => VideoModel.fromMap(d.id, d.data()))
            .where((v) => !v.hidden)
            .toList();
        list.sort(compareVideosNewestFirst);
        return list.take(limit).toList();
      });

  Future<void> addVideo(VideoModel v) async {
    await _db.collection('videos').add({...v.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    await _bumpBatchCount(v.batchId, 'videos', 1);
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
  Stream<List<VideoFolderModel>> streamVideoFolders(String batchId) => _db
          .collection('videoFolders')
          .where('batchId', isEqualTo: batchId)
          .snapshots()
          .map((snap) {
        final list = snap.docs.map((d) => VideoFolderModel.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => compareCreatedAsc(a.createdAt, b.createdAt, a.name, b.name));
        return list;
      });

  Stream<List<VideoFolderModel>> streamFreeVideoFolders() => streamVideoFolders(kFreeVideoBatchId);

  Future<void> addVideoFolder(VideoFolderModel f) =>
      _db.collection('videoFolders').add({...f.toMap(), 'createdAt': FieldValue.serverTimestamp()});

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

  Stream<List<VideoModel>> streamVideosInFolder(String folderId) => _db
          .collection('videos')
          .where('folderId', isEqualTo: folderId)
          .snapshots()
          .map((snap) {
        final list = snap.docs
            .map((d) => VideoModel.fromMap(d.id, d.data()))
            .where((v) => !v.hidden)
            .toList();
        list.sort((a, b) => compareCreatedAsc(a.createdAt, b.createdAt, a.title, b.title));
        return list;
      });

  // ---- News ----
  Stream<List<NewsItemModel>> streamNews(List<String> categories) {
    return _db
        .collection('newsItems')
        .where('category', whereIn: categories)
        .orderBy('pubDate', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map((d) => NewsItemModel.fromMap(d.id, d.data())).toList());
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
      final stored = (data['accessCode'] as String?) ?? '';
      if (stored.isEmpty || stored != code.trim()) return const AccessCheck();
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
  Future<GrantResult> grantAccess(String email, String batchId, {int months = 0}) async {
    final clean = email.trim();
    final id = '${clean.toLowerCase()}_$batchId';
    final code = (100000 + Random().nextInt(900000)).toString(); // 6 digits
    final expiresAt = months > 0 ? addMonthsEndOfDay(DateTime.now(), months) : null;
    await _db.collection('batchAccess').doc(id).set({
      'studentEmail': clean,
      'batchId': batchId,
      'status': 'granted',
      'accessCode': code,
      'grantedAt': FieldValue.serverTimestamp(),
      'grantedBy': 'admin',
      'validityMonths': months,
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
    });
    // Clears the pending request (if the student used the in-app
    // "Check Access" flow) so it disappears from the admin's queue. No-op
    // (and no error) if no such request exists — e.g. manual grants.
    await _db.collection('accessRequests').doc(id).delete();
    return GrantResult(code, expiresAt);
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

  // For the "\u2705 Unlocked" badge on the Batches list only — NOT a security
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
    await Future.wait(batchIds.map((id) async {
      try {
        final doc = await _db.collection('batchAccess').doc('${clean}_$id').get().timeout(const Duration(seconds: 10));
        final data = doc.data();
        final exp = (data?['expiresAt'] as Timestamp?)?.toDate();
        final expired = exp != null && !DateTime.now().isBefore(exp);
        if (data != null && data['status'] == 'granted' && !expired) out.add(id);
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

  // ---- PDF folders (Free PDFs vs Paid Batch PDFs) ----
  Stream<List<PdfFolderModel>> streamFolders({required String type, String? batchId}) {
    Query<Map<String, dynamic>> q = _db.collection('pdfFolders').where('type', isEqualTo: type);
    if (batchId != null) q = q.where('batchId', isEqualTo: batchId);
    return q.snapshots().map((snap) {
      final list = snap.docs.map((d) => PdfFolderModel.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => compareCreatedAsc(a.createdAt, b.createdAt, a.name, b.name));
      return list;
    });
  }

  Future<void> addFolder(PdfFolderModel f) =>
      _db.collection('pdfFolders').add({...f.toMap(), 'createdAt': FieldValue.serverTimestamp()});

  Stream<List<PdfModel>> streamPdfsInFolder(String folderId) => _db
          .collection('pdfs')
          .where('folderId', isEqualTo: folderId)
          .snapshots()
          .map((snap) {
        final list = snap.docs.map((d) => PdfModel.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => compareCreatedAsc(a.createdAt, b.createdAt, a.title, b.title));
        return list;
      });

  // ---- Notifications ----
  // "sent: false" lets the free GitHub Actions script (or the paid Cloud
  // Function, if you deploy that instead) find this and push it via FCM,
  // then flip it to true so it's never sent twice.
  Future<void> sendNotification(String title, String body) =>
      _db.collection('notifications').add({'title': title, 'body': body, 'sent': false, 'sentAt': FieldValue.serverTimestamp()});

  Stream<List<NotificationModel>> streamNotifications() => _db
      .collection('notifications')
      .orderBy('sentAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map((d) => NotificationModel.fromMap(d.id, d.data())).toList());

  // ---- Mock Tests ----
  Stream<List<MockTestFolderModel>> streamMockFolders() => _db.collection('mockTestFolders').snapshots().map((snap) {
        final list = snap.docs.map((d) => MockTestFolderModel.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => compareCreatedAsc(a.createdAt, b.createdAt, a.examName, b.examName));
        return list;
      });

  Future<void> addMockFolder(String examName) =>
      _db.collection('mockTestFolders').add({'examName': examName, 'createdAt': FieldValue.serverTimestamp()});

  // Deletes the exam folder together with all tests inside it.
  Future<void> deleteMockFolder(String id) async {
    await _deleteAll(_db.collection('mockTests').where('folderId', isEqualTo: id));
    await _db.collection('mockTestFolders').doc(id).delete();
  }

  Stream<List<MockTestModel>> streamMockTests(String folderId) => _db
          .collection('mockTests')
          .where('folderId', isEqualTo: folderId)
          .snapshots()
          .map((snap) {
        final list = snap.docs.map((d) => MockTestModel.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => compareCreatedAsc(a.createdAt, b.createdAt, a.title, b.title));
        return list;
      });

  Future<void> saveMockTest(MockTestModel t) {
    if (t.id.isEmpty) {
      return _db.collection('mockTests').add({...t.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    }
    return _db.collection('mockTests').doc(t.id).set(t.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteMockTest(String id) => _db.collection('mockTests').doc(id).delete();

  Future<void> saveMockAttempt({
    required String studentEmail,
    required String mockTestId,
    required String mockTestTitle,
    required int score,
    required int total,
    required List<int?> answers,
  }) =>
      _db.collection('mockTestAttempts').add({
        'studentEmail': studentEmail,
        'mockTestId': mockTestId,
        'mockTestTitle': mockTestTitle,
        'score': score,
        'total': total,
        'answers': answers,
        'submittedAt': FieldValue.serverTimestamp(),
      });

  // Admin "Attempts" tab (latest first).
  Stream<List<MockTestAttemptModel>> streamMockAttempts({int limit = 100}) => _db
      .collection('mockTestAttempts')
      .orderBy('submittedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map((d) => MockTestAttemptModel.fromMap(d.id, d.data())).toList());

  // ---- Home banners (16:9 auto-scroll carousel, Admin Panel -> Banners) ----
  Stream<List<BannerModel>> streamBanners() => _db
      .collection('banners')
      .orderBy('order')
      .snapshots()
      .map((snap) => snap.docs.map((d) => BannerModel.fromMap(d.id, d.data())).toList());

  // Auto-assigns the next order (current max + 1) so new banners land at
  // the end of the slider instead of the admin having to pick a number.
  Future<void> addBanner(String imageUrl, {String? linkUrl}) async {
    final last = await _db.collection('banners').orderBy('order', descending: true).limit(1).get();
    final nextOrder = last.docs.isEmpty ? 0 : ((last.docs.first.data()['order'] as num?)?.toInt() ?? 0) + 1;
    await _db.collection('banners').add({
      'imageUrl': imageUrl,
      if (linkUrl != null) 'linkUrl': linkUrl,
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
}
