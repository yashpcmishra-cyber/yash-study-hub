import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Direct phone-storage upload for LARGE FILES (PDFs, videos) — this uploads
/// a picked file to Firebase Storage. It ONLY works once your project is on
/// the Blaze plan and Storage is enabled in the Firebase Console. Until
/// then, this throws a clear StorageNotReadyException so the UI can show a
/// friendly message and fall back to the Drive/YouTube-link method, instead
/// of silently failing.
///
/// For IMAGES (icons, thumbnails, app logo), use ImageUploadService instead
/// (image_upload_service.dart) — that one is free forever via GitHub +
/// jsDelivr, no Blaze needed at all.
class StorageNotReadyException implements Exception {
  final String message;
  StorageNotReadyException(this.message);
  @override
  String toString() => message;
}

class StorageService {
  Future<String> uploadFile(File file, String folderPath) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('$folderPath/${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}');
      final task = await ref.putFile(file);
      return await task.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      // Only these specific codes reliably mean "Storage isn't enabled /
      // project isn't on Blaze yet".
      const notReadyCodes = {
        'bucket-not-found',
        'project-not-found',
      };
      if (notReadyCodes.contains(e.code)) {
        throw StorageNotReadyException('Storage isn\u2019t turned on for this Firebase project yet (needs the Blaze plan). Use a Drive/YouTube link instead for now.');
      }
      // Any other Firebase Storage error — show the real reason.
      throw StorageNotReadyException('Upload failed: ${e.message ?? e.code}. Check your internet connection and try again, or use a Drive/YouTube link instead.');
    } on SocketException {
      throw StorageNotReadyException('No internet connection. Check your connection and try again.');
    }
  }
}
