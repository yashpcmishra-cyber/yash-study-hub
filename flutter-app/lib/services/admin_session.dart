import 'package:flutter/foundation.dart';

/// True jab is phone par Admin Panel khul chuka ho (aur logout nahi hua).
/// Daily CA screen isse delete button dikhati hai. Asli permission Firestore
/// rules deti hain: sirf admin account hi delete kar sakta hai.
final ValueNotifier<bool> adminSignedIn = ValueNotifier<bool>(false);
