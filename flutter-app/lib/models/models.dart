import 'package:cloud_firestore/cloud_firestore.dart';

/// Video folders that belong to the FREE "Video Classes" section (not to a
/// paid batch) store this value in their `batchId` field.
const String kFreeVideoBatchId = 'free';

DateTime? _dt(dynamic v) => v is Timestamp ? v.toDate() : null;

int _nonNeg(dynamic v) {
  final n = v is num ? v.toInt() : 0;
  return n < 0 ? 0 : n;
}

/// Adds calendar months to a date (31 Jan + 1 month = last day of Feb) and
/// returns the END of that day (23:59:59), so "valid till 24 Sep" really
/// means the whole of 24 Sep.
DateTime addMonthsEndOfDay(DateTime from, int months) {
  final total = from.month - 1 + months;
  final y = from.year + total ~/ 12;
  final m = total % 12 + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  final d = from.day > lastDay ? lastDay : from.day;
  return DateTime(y, m, d, 23, 59, 59);
}

String monthsText(int n) => n == 1 ? '1 month' : '$n months';

/// Oldest first (the order the admin added things). Old items that have no
/// `createdAt` yet come first, alphabetically.
int compareCreatedAsc(DateTime? a, DateTime? b, String titleA, String titleB) {
  final ta = titleA.toLowerCase();
  final tb = titleB.toLowerCase();
  if (a == null && b == null) return ta.compareTo(tb);
  if (a == null) return -1;
  if (b == null) return 1;
  final c = a.compareTo(b);
  return c != 0 ? c : ta.compareTo(tb);
}

class BatchModel {
  final String id;
  final String title;
  final int price;
  final String? iconUrl;
  final int videos;
  final int pdfs;
  final DateTime? createdAt;
  // How long a student's access lasts after it is granted, in months.
  // 0 = lifetime (also what every older batch without this field means).
  final int validityMonths;

  BatchModel({
    required this.id,
    required this.title,
    required this.price,
    this.iconUrl,
    this.videos = 0,
    this.pdfs = 0,
    this.createdAt,
    this.validityMonths = 0,
  });

  bool get hasValidity => validityMonths > 0;
  String get validityLabel => 'Valid for ${monthsText(validityMonths)}';

  factory BatchModel.fromMap(String id, Map<String, dynamic> m) => BatchModel(
        id: id,
        title: m['title'] ?? '',
        price: (m['price'] as num?)?.toInt() ?? 0,
        iconUrl: m['iconUrl'],
        videos: _nonNeg(m['videos']),
        pdfs: _nonNeg(m['pdfs']),
        createdAt: _dt(m['createdAt']),
        validityMonths: _nonNeg(m['validityMonths']),
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'price': price,
        'iconUrl': iconUrl,
        'videos': videos,
        'pdfs': pdfs,
        'isLocked': true,
        'validityMonths': validityMonths,
      };
}

class PdfFolderModel {
  final String id;
  final String name;
  final String type; // "free" | "batch"
  final String? batchId;
  final DateTime? createdAt;

  PdfFolderModel({required this.id, required this.name, required this.type, this.batchId, this.createdAt});

  factory PdfFolderModel.fromMap(String id, Map<String, dynamic> m) => PdfFolderModel(
        id: id,
        name: m['name'] ?? '',
        type: m['type'] ?? 'free',
        batchId: m['batchId'],
        createdAt: _dt(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {'name': name, 'type': type, 'batchId': batchId};
}

class PdfModel {
  final String id;
  final String title;
  final String? iconUrl;
  final String driveLink; // Drive link OR Firebase Storage download URL (both work the same way)
  final String? batchId;
  final String? folderId;
  final DateTime? createdAt;

  PdfModel({
    required this.id,
    required this.title,
    this.iconUrl,
    required this.driveLink,
    this.batchId,
    this.folderId,
    this.createdAt,
  });

  factory PdfModel.fromMap(String id, Map<String, dynamic> m) => PdfModel(
        id: id,
        title: m['title'] ?? '',
        iconUrl: m['iconUrl'],
        driveLink: m['driveLink'] ?? '',
        batchId: m['batchId'],
        folderId: m['folderId'],
        createdAt: _dt(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {'title': title, 'iconUrl': iconUrl, 'driveLink': driveLink, 'batchId': batchId, 'folderId': folderId};
}

class VideoFolderModel {
  final String id;
  final String name;
  final String batchId; // a paid batch id, or kFreeVideoBatchId for the free section
  final DateTime? createdAt;

  VideoFolderModel({required this.id, required this.name, required this.batchId, this.createdAt});

  factory VideoFolderModel.fromMap(String id, Map<String, dynamic> m) => VideoFolderModel(
        id: id,
        name: m['name'] ?? '',
        batchId: m['batchId'] ?? '',
        createdAt: _dt(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {'name': name, 'batchId': batchId};
}

class VideoModel {
  final String id;
  final String title;
  final String? thumbUrl;
  final String youtubeLink;
  final String? batchId;
  final String? folderId;
  final String source; // "upload" | "youtube_auto"
  final DateTime? publishedAt; // set by the YouTube auto-fetch script
  final DateTime? createdAt;
  final bool hidden; // true = admin hid an auto-fetched video

  VideoModel({
    required this.id,
    required this.title,
    this.thumbUrl,
    required this.youtubeLink,
    this.batchId,
    this.folderId,
    this.source = 'upload',
    this.publishedAt,
    this.createdAt,
    this.hidden = false,
  });

  factory VideoModel.fromMap(String id, Map<String, dynamic> m) => VideoModel(
        id: id,
        title: m['title'] ?? '',
        thumbUrl: m['thumbUrl'],
        youtubeLink: m['youtubeLink'] ?? '',
        batchId: m['batchId'],
        folderId: m['folderId'],
        source: m['source'] ?? 'upload',
        publishedAt: _dt(m['publishedAt']),
        createdAt: _dt(m['createdAt']),
        hidden: m['hidden'] == true,
      );

  /// One entry of the `appConfig/latestVideos` list written by the
  /// fetch-videos script.
  factory VideoModel.fromLatestMap(Map<String, dynamic> m) => VideoModel(
        id: (m['id'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        thumbUrl: m['thumbUrl'] is String ? m['thumbUrl'] as String : null,
        youtubeLink: (m['youtubeLink'] ?? '').toString(),
        source: 'youtube_auto',
        publishedAt: DateTime.tryParse((m['publishedAt'] ?? '').toString()),
      );

  Map<String, dynamic> toMap() => {'title': title, 'thumbUrl': thumbUrl, 'youtubeLink': youtubeLink, 'batchId': batchId, 'folderId': folderId, 'source': source};
}

/// Newest video first. Videos with no date go last.
int compareVideosNewestFirst(VideoModel a, VideoModel b) {
  final da = a.publishedAt ?? a.createdAt;
  final dbb = b.publishedAt ?? b.createdAt;
  if (da == null && dbb == null) {
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }
  if (da == null) return 1;
  if (dbb == null) return -1;
  return dbb.compareTo(da);
}

class NewsItemModel {
  final String id;
  final String category;
  final String categoryLabel;
  final String title;
  final String link;
  final String? image;

  NewsItemModel({required this.id, required this.category, required this.categoryLabel, required this.title, required this.link, this.image});

  factory NewsItemModel.fromMap(String id, Map<String, dynamic> m) => NewsItemModel(
        id: id,
        category: m['category'] ?? '',
        categoryLabel: m['categoryLabel'] ?? '',
        title: m['title'] ?? '',
        link: m['link'] ?? '',
        image: m['image'],
      );
}

class AccessRequestModel {
  final String id; // format: {studentEmail}_{batchId}, same pattern as batchAccess
  final String studentName;
  final String studentEmail;
  final String studentPhone; // optional — WhatsApp/SMS number student can give so admin can actually reach them
  final String batchId;
  final String batchTitle;
  final DateTime? requestedAt;

  AccessRequestModel({required this.id, this.studentName = '', required this.studentEmail, this.studentPhone = '', required this.batchId, required this.batchTitle, this.requestedAt});

  factory AccessRequestModel.fromMap(String id, Map<String, dynamic> m) => AccessRequestModel(
        id: id,
        studentName: m['studentName'] ?? '',
        studentEmail: m['studentEmail'] ?? '',
        studentPhone: m['studentPhone'] ?? '',
        batchId: m['batchId'] ?? '',
        batchTitle: m['batchTitle'] ?? '',
        requestedAt: _dt(m['requestedAt']),
      );
}

/// A student who has been granted access to a paid batch (batchAccess doc).
class AccessGrantModel {
  final String id; // {studentEmail}_{batchId}
  final String studentEmail;
  final String batchId;
  final DateTime? grantedAt;
  final DateTime? expiresAt; // null = lifetime access

  AccessGrantModel({required this.id, required this.studentEmail, required this.batchId, this.grantedAt, this.expiresAt});

  factory AccessGrantModel.fromMap(String id, Map<String, dynamic> m) => AccessGrantModel(
        id: id,
        studentEmail: m['studentEmail'] ?? '',
        batchId: m['batchId'] ?? '',
        grantedAt: _dt(m['grantedAt']),
        expiresAt: _dt(m['expiresAt']),
      );

  bool get isExpired => expiresAt != null && !DateTime.now().isBefore(expiresAt!);
}

/// Result of checking one student's access to one paid batch.
/// [granted] = the code is right AND the access has not run out.
/// [expired] = the access existed, but its time limit is over.
class AccessCheck {
  final bool granted;
  final bool expired;
  final DateTime? expiresAt; // null = lifetime, or not known
  const AccessCheck({this.granted = false, this.expired = false, this.expiresAt});
}

/// What the admin gets back after granting access: the code to share, and
/// the date the access runs out (null = lifetime).
class GrantResult {
  final String code;
  final DateTime? expiresAt;
  const GrantResult(this.code, this.expiresAt);
}

/// A student's own profile (students/{uid}, uid = Firebase Auth uid).
/// `profileComplete` gates the mandatory Login -> Profile Setup -> Home
/// flow in splash_screen.dart: it only flips to true once the student has
/// filled State/District/Gender/Qualification at least once.
class StudentModel {
  final String uid;
  final String name;
  final String email;
  final String state;
  final String district;
  final String gender;
  final String qualification;
  final bool profileComplete;
  final DateTime? createdAt;

  StudentModel({
    required this.uid,
    this.name = '',
    this.email = '',
    this.state = '',
    this.district = '',
    this.gender = '',
    this.qualification = '',
    this.profileComplete = false,
    this.createdAt,
  });

  factory StudentModel.fromMap(String uid, Map<String, dynamic> m) => StudentModel(
        uid: uid,
        name: m['name'] ?? '',
        email: m['email'] ?? '',
        state: m['state'] ?? '',
        district: m['district'] ?? '',
        gender: m['gender'] ?? '',
        qualification: m['qualification'] ?? '',
        profileComplete: m['profileComplete'] == true,
        createdAt: _dt(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'state': state,
        'district': district,
        'gender': gender,
        'qualification': qualification,
        'profileComplete': profileComplete,
      };

  StudentModel copyWith({
    String? name,
    String? state,
    String? district,
    String? gender,
    String? qualification,
    bool? profileComplete,
  }) =>
      StudentModel(
        uid: uid,
        name: name ?? this.name,
        email: email,
        state: state ?? this.state,
        district: district ?? this.district,
        gender: gender ?? this.gender,
        qualification: qualification ?? this.qualification,
        profileComplete: profileComplete ?? this.profileComplete,
        createdAt: createdAt,
      );
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime? sentAt;

  NotificationModel({required this.id, required this.title, required this.body, this.sentAt});

  factory NotificationModel.fromMap(String id, Map<String, dynamic> m) => NotificationModel(
        id: id,
        title: m['title'] ?? '',
        body: m['body'] ?? '',
        sentAt: _dt(m['sentAt']),
      );
}

class MockTestFolderModel {
  final String id;
  final String examName; // e.g. "SSC CGL", "Banking PO"
  final DateTime? createdAt;

  MockTestFolderModel({required this.id, required this.examName, this.createdAt});

  factory MockTestFolderModel.fromMap(String id, Map<String, dynamic> m) =>
      MockTestFolderModel(id: id, examName: m['examName'] ?? '', createdAt: _dt(m['createdAt']));

  Map<String, dynamic> toMap() => {'examName': examName};
}

class MockQuestion {
  final String text;
  final List<String> options; // exactly 4
  final int correctIndex;

  MockQuestion({required this.text, required this.options, required this.correctIndex});

  factory MockQuestion.fromMap(Map<String, dynamic> m) => MockQuestion(
        text: m['text'] ?? '',
        options: List<String>.from(m['options'] ?? []),
        correctIndex: (m['correctIndex'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {'text': text, 'options': options, 'correctIndex': correctIndex};
}

// Home-screen auto-scroll banner (16:9 image, optional tap-through link).
// Ordered by `order` (lower first) so admin can control slide sequence —
// new banners get the next integer automatically (see addBanner()).
class BannerModel {
  final String id;
  final String imageUrl;
  final String? linkUrl;
  final int order;
  final DateTime? createdAt;

  BannerModel({required this.id, required this.imageUrl, this.linkUrl, this.order = 0, this.createdAt});

  factory BannerModel.fromMap(String id, Map<String, dynamic> m) => BannerModel(
        id: id,
        imageUrl: m['imageUrl'] ?? '',
        linkUrl: (m['linkUrl'] as String?)?.trim().isNotEmpty == true ? m['linkUrl'] : null,
        order: (m['order'] as num?)?.toInt() ?? 0,
        createdAt: _dt(m['createdAt']),
      );
}

// Backs the `appConfig/main` document. Defaults below are used until the
// admin edits something in the Branding tab.
// IMPORTANT: check the UPI ID below (and the links) in Admin > Branding
// before going live — 'yshpay@upi' is only a placeholder.
class AppConfigModel {
  final String? logoUrl;
  final String appName;
  final String tagline;
  final String upiId;
  final String telegramUrl;
  final String paymentTelegramUrl;
  final String whatsappUrl;
  final String youtubeUrl;

  const AppConfigModel({
    this.logoUrl,
    this.appName = 'Yash Study Hub',
    this.tagline = 'COMPETITIVE EXAM PREP',
    this.upiId = 'yshpay@upi',
    this.telegramUrl = 'https://t.me/YashStudyHub',
    this.paymentTelegramUrl = 'https://t.me/YSHinfo',
    this.whatsappUrl = 'https://whatsapp.com/channel/0029VbCnzSvKmCPLxoMBuk33',
    this.youtubeUrl = 'https://www.youtube.com/c/YashStudyHub',
  });

  factory AppConfigModel.fromMap(Map<String, dynamic>? m) {
    const d = AppConfigModel();
    if (m == null) return d;
    return AppConfigModel(
      logoUrl: m['logoUrl'],
      appName: (m['appName'] as String?)?.trim().isNotEmpty == true ? m['appName'] : d.appName,
      tagline: (m['tagline'] as String?)?.trim().isNotEmpty == true ? m['tagline'] : d.tagline,
      upiId: (m['upiId'] as String?)?.trim().isNotEmpty == true ? m['upiId'] : d.upiId,
      telegramUrl: (m['telegramUrl'] as String?)?.trim().isNotEmpty == true ? m['telegramUrl'] : d.telegramUrl,
      paymentTelegramUrl: (m['paymentTelegramUrl'] as String?)?.trim().isNotEmpty == true ? m['paymentTelegramUrl'] : d.paymentTelegramUrl,
      whatsappUrl: (m['whatsappUrl'] as String?)?.trim().isNotEmpty == true ? m['whatsappUrl'] : d.whatsappUrl,
      youtubeUrl: (m['youtubeUrl'] as String?)?.trim().isNotEmpty == true ? m['youtubeUrl'] : d.youtubeUrl,
    );
  }

  Map<String, dynamic> toMap() => {
        if (logoUrl != null) 'logoUrl': logoUrl,
        'appName': appName,
        'tagline': tagline,
        'upiId': upiId,
        'telegramUrl': telegramUrl,
        'paymentTelegramUrl': paymentTelegramUrl,
        'whatsappUrl': whatsappUrl,
        'youtubeUrl': youtubeUrl,
      };

  AppConfigModel copyWith({String? logoUrl, String? appName, String? tagline, String? upiId, String? telegramUrl, String? paymentTelegramUrl, String? whatsappUrl, String? youtubeUrl}) =>
      AppConfigModel(
        logoUrl: logoUrl ?? this.logoUrl,
        appName: appName ?? this.appName,
        tagline: tagline ?? this.tagline,
        upiId: upiId ?? this.upiId,
        telegramUrl: telegramUrl ?? this.telegramUrl,
        paymentTelegramUrl: paymentTelegramUrl ?? this.paymentTelegramUrl,
        whatsappUrl: whatsappUrl ?? this.whatsappUrl,
        youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      );
}

// A saved mock-test attempt. Powers the admin "Attempts" viewer.
// The time is stored in the `submittedAt` field (same name is read back here).
class MockTestAttemptModel {
  final String id;
  final String mockTestId;
  final String mockTestTitle;
  final String studentEmail; // email, or the name the student typed, or "anonymous"
  final int score;
  final int total;
  final DateTime? submittedAt;

  MockTestAttemptModel({
    required this.id,
    required this.mockTestId,
    required this.mockTestTitle,
    required this.studentEmail,
    required this.score,
    required this.total,
    this.submittedAt,
  });

  factory MockTestAttemptModel.fromMap(String id, Map<String, dynamic> m) => MockTestAttemptModel(
        id: id,
        mockTestId: m['mockTestId'] ?? '',
        mockTestTitle: m['mockTestTitle'] ?? '',
        studentEmail: m['studentEmail'] ?? 'anonymous',
        score: (m['score'] as num?)?.toInt() ?? 0,
        total: (m['total'] as num?)?.toInt() ?? 0,
        submittedAt: _dt(m['submittedAt']),
      );
}

class MockTestModel {
  final String id;
  final String folderId;
  final String title;
  final List<MockQuestion> questions;
  final DateTime? createdAt;

  MockTestModel({required this.id, required this.folderId, required this.title, required this.questions, this.createdAt});

  factory MockTestModel.fromMap(String id, Map<String, dynamic> m) => MockTestModel(
        id: id,
        folderId: m['folderId'] ?? '',
        title: m['title'] ?? '',
        questions: ((m['questions'] ?? []) as List).map((q) => MockQuestion.fromMap(Map<String, dynamic>.from(q))).toList(),
        createdAt: _dt(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'folderId': folderId,
        'title': title,
        'questions': questions.map((q) => q.toMap()).toList(),
      };
}
