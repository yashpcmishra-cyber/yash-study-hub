import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Free image hosting via a GitHub repo (no Blaze/billing account needed).
///
/// HOW IT WORKS: images are committed as files into a public GitHub repo
/// using GitHub's Contents API, then served through jsDelivr's free CDN.
///
/// SECURITY NOTE: this needs a GitHub token inside the app so it can save
/// files. Use a "fine-grained" token limited to ONLY the images repo with
/// ONLY "Contents: Read and write". Worst case (someone extracts it from the
/// APK) they can only add/overwrite files in that one images-only repo.
///
/// The token is NOT written in this file (GitHub would auto-revoke it).
/// It is passed in when the APK is built:
///
///   1. Copy  env.json.example  to  env.json  (same folder as pubspec.yaml)
///      and paste the token inside it.
///   2. Build with:
///        flutter build apk --release --dart-define-from-file=env.json
///      (for a test run: flutter run --dart-define-from-file=env.json)
///
/// GitHub Actions build: add a repository secret named IMAGE_UPLOAD_TOKEN
/// (the workflow file already passes it in).
///
/// If the APK was built WITHOUT the token, image uploads (logo, banners,
/// batch/PDF icons, thumbnails) show a clear message instead of failing
/// silently. Everything else in the app keeps working.
class ImageUploadService {
  static const String githubOwner = 'yashpcmishra-cyber';
  static const String githubRepo = 'ysh-images'; // dedicated images-only repo
  static const String githubBranch = 'main';
  static const String githubToken = String.fromEnvironment('IMAGE_UPLOAD_TOKEN');

  bool get isConfigured =>
      githubToken.trim().isNotEmpty && githubToken != 'REPLACE_WITH_FINE_GRAINED_PAT';

  Future<String> uploadImage(File file) async {
    if (!isConfigured) {
      throw ImageUploadNotConfiguredException(
        'Image upload is not set up in this build. The APK must be built with the image token '
        '(flutter build apk --release --dart-define-from-file=env.json). See README.md, step "Image token".',
      );
    }
    final bytes = await file.readAsBytes();
    final base64Content = base64Encode(bytes);
    final ext = file.path.contains('.') ? file.path.split('.').last.toLowerCase() : 'jpg';
    final path = 'uploads/${DateTime.now().millisecondsSinceEpoch}.$ext';

    final uri = Uri.parse('https://api.github.com/repos/$githubOwner/$githubRepo/contents/$path');
    final http.Response response;
    try {
      response = await http
          .put(
            uri,
            headers: {
              'Authorization': 'Bearer $githubToken',
              'Accept': 'application/vnd.github+json',
            },
            body: jsonEncode({
              'message': 'Upload image via Yash Study Hub app',
              'content': base64Content,
              'branch': githubBranch,
            }),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw Exception('Image upload timed out. Check your internet connection and try again.');
    } on SocketException {
      throw Exception('No internet connection. Check your connection and try again.');
    }

    if (response.statusCode != 201 && response.statusCode != 200) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('The image token was rejected (expired, wrong, or no write permission). Create a new token and rebuild the app.');
      }
      if (response.statusCode == 404) {
        throw Exception('Image repo "$githubOwner/$githubRepo" was not found, or the token cannot access it.');
      }
      final body = response.body.length > 160 ? response.body.substring(0, 160) : response.body;
      throw Exception('Image upload failed (${response.statusCode}): $body');
    }

    // jsDelivr's free CDN — fast, cached, works right after the commit.
    return 'https://cdn.jsdelivr.net/gh/$githubOwner/$githubRepo@$githubBranch/$path';
  }
}

class ImageUploadNotConfiguredException implements Exception {
  final String message;
  ImageUploadNotConfiguredException(this.message);
  @override
  String toString() => message;
}
