# Yash Study Hub — Flutter App (Firebase-connected)

Real source code, tumhare Firebase project (`yash-study-hub-450d2`) se connected.
Bugs/errors ki poori list aur kya-kya fix hua: **`../FIX_REPORT.md`**.

## APK banane ke 6 chhote steps (Android Studio / laptop wala tarika)

Zaroori: **Flutter 3.22 ya naya** (Flutter 3.24 best) + Android Studio (Android SDK ke liye).
Check karo: terminal me `flutter --version`.

Sab commands **is `flutter-app` folder ke andar** chalane hain.

1. **Android folder banao** (ek baar):
   ```
   flutter create --platforms=android --org com.yashstudyhub --project-name yash_study_hub .
   ```
   (Isse `lib/`, `pubspec.yaml`, `assets/` ko koi nuksaan nahi hota — sirf `android/` ki missing files ban jaati hain.)

2. **Android settings theek karo** (ek baar — app-id `com.yashstudyhub.app`, minSdk 23, sahi manifest):
   ```
   python3 tools/patch_android.py
   ```
   (Windows par `python tools\patch_android.py`. Python nahi hai to neeche "Bina Python ke" dekho.)

3. **`google-services.json`** — ab haath se rakhne ki zaroorat **nahi**. `tools/patch_android.py` (step 2) ise `lib/firebase_options.dart` ki values se apne aap banata hai aur Firebase ka google-services plugin laga deta hai (app band hone par push notification ke liye). Gradle files alag dikhein to ye step chupchaap skip ho jaata hai aur app pehle jaisa hi banta hai.

4. **Image token** (logo / banner / icon upload ke liye — 1 minute):
   - `env.json.example` ki copy banao aur naam rakho `env.json`
   - Usme `PASTE_YOUR_GITHUB_FINE_GRAINED_TOKEN_HERE` ki jagah apna token paste karo (`../production-app-guide/FREE_IMAGE_HOSTING.md` me token banana likha hai)
   - `env.json` ko **GitHub par kabhi upload mat karna** (`.gitignore` already block karta hai)

5. **Libraries lo**:
   ```
   flutter pub get
   ```

6. **APK banao**:
   ```
   flutter build apk --release --dart-define-from-file=env.json
   ```
   APK yahan milegi: `build/app/outputs/flutter-apk/app-release.apk`

> Token ke bina bhi build ho jaata hai (`--dart-define-from-file=env.json` hata do) — bas tab logo/banner/icon upload nahi chalega aur admin ko saaf message dikhega. Baaki sab kuch chalega.

### Bina Python ke (manual, 2 lines)
`android/app/build.gradle` (ya `build.gradle.kts`) kholo:
- `applicationId "com.example...."` ko badal kar `applicationId "com.yashstudyhub.app"` karo
- `minSdkVersion flutter.minSdkVersion` ko badal kar `minSdkVersion 23` karo (kts me `minSdk = 23`)
- `android/app/src/main/AndroidManifest.xml` ko `tools/AndroidManifest.xml` se replace kar do

### GitHub se APK (laptop ke bina)
`../production-app-guide/HOW_TO_BUILD_APK.md` — Option B. Wahan sab kuch automatic hai (ye 1-3 steps workflow khud kar deta hai).

## Agar build me error aaye
Poora error message copy karke bhej do. Sabse common cheezein:
- `Flutter version too old` → Flutter 3.22+ install karo
- `minSdkVersion ... cannot be smaller than version 23` → step 2 (patch) dubara chalao
- Image upload par "not set up in this build" → step 4/6 me `env.json` wali command use karo

## App chalne ke baad ek baar ye 6 cheezein phone par test kar lo
1. Admin Panel → **Branding** me UPI ID sahi hai? (default `yshpay@upi` sirf placeholder hai)
2. Admin login → Notify tab se ek test notification bhejo → 5-10 min me phone par push aana chahiye (app band ho tab bhi)
3. Ek batch banao → student side se "Check Access" → admin ko request dikhe → Grant → code se unlock
4. Ek mock test banao aur attempt karke Scorecard dekho (Attempts tab me score dikhna chahiye)
5. Video (YouTube link) chalao — fullscreen/rotate check karo
6. UPI "tap to pay" button ek baar real phone par try karo
