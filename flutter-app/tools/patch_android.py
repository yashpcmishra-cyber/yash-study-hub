#!/usr/bin/env python3
"""
Yash Study Hub - one-time Android setup helper.

Run it ONCE right after `flutter create` has generated the android/ folder
(the GitHub build workflow runs it automatically):

    python3 tools/patch_android.py            (from the flutter-app folder)
    python3 tools/patch_android.py <folder>   (or give the project folder)

What it does (safe to run again and again):
  0. Bumps the Android Gradle Plugin, Kotlin plugin and Gradle wrapper
     versions in settings.gradle / gradle-wrapper.properties if they are
     older than a known-compatible, JDK-17-safe combination (AGP 8.3.2 /
     Kotlin 2.1.20 / Gradle 8.6, per Google's official AGP-Gradle
     compatibility table). Fixes build failures like "requires a newer
     version of the Kotlin Gradle plugin" or "Android Gradle Plugin Version
     Incompatible with Kotlin Gradle Plugin". Only ever raises versions.
  1. Sets the app id to  com.yashstudyhub.app  (must match Firebase).
  2. Makes sure the minimum Android version (minSdk) is at least 23, which
     the Firebase libraries need.
  3. Puts the correct AndroidManifest.xml in place (permissions, links,
     no screen-orientation lock so video fullscreen can rotate).
  4. Replaces the default Flutter launcher icon with the Yash Study Hub logo
     (ready-made PNGs in tools/icons/mipmap-*/).
  5. Push notifications: a small white status-bar icon (tools/notify_icons/)
     and the standard Firebase "google-services" setup (google-services.json
     is generated from lib/firebase_options.dart, so there is one source of
     truth). If anything about the Gradle files looks unexpected, step 5b is
     skipped completely - nothing is half-applied.
  6. Optional: if android/key.properties exists (see
     production-app-guide/RELEASE_SIGNING.md), wires up a real release
     signing config so every build - local or GitHub Actions - uses the same
     signing key. Without that file, this step does nothing and release
     builds keep using the debug key exactly as before.

It never touches lib/, pubspec.yaml or assets/.
"""
import os
import re
import shutil
import sys

APP_ID = "com.yashstudyhub.app"
MIN_SDK = 23


GMS_PLUGIN_VERSION = "4.3.15"  # works with the Android Gradle Plugin of Flutter 3.24


def read_android_firebase_options(root):
    """Reads the Android block of lib/firebase_options.dart. None if unusable."""
    path = os.path.join(root, "lib", "firebase_options.dart")
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8") as f:
        text = f.read()
    m = re.search(r"FirebaseOptions\s+android\s*=\s*FirebaseOptions\((.*?)\);", text, re.S)
    if not m:
        return None
    values = {}
    for key in ("apiKey", "appId", "messagingSenderId", "projectId", "storageBucket"):
        mm = re.search(key + r"\s*:\s*'([^']*)'", m.group(1))
        if not mm or not mm.group(1) or "REPLACE" in mm.group(1):
            return None
        values[key] = mm.group(1)
    return values


def build_google_services_json(v):
    import json

    data = {
        "project_info": {
            "project_number": v["messagingSenderId"],
            "project_id": v["projectId"],
            "storage_bucket": v["storageBucket"],
        },
        "client": [
            {
                "client_info": {
                    "mobilesdk_app_id": v["appId"],
                    "android_client_info": {"package_name": APP_ID},
                },
                "oauth_client": [],
                "api_key": [{"current_key": v["apiKey"]}],
                "services": {"appinvite_service": {"other_platform_oauth_client": []}},
            }
        ],
        "configuration_version": "1",
    }
    return json.dumps(data, indent=2) + "\n"


def setup_google_services(root, android_dir, app_gradle_path):
    """Step 5b. Returns a short status text. Never leaves things half-applied."""
    settings_path = None
    for name in ("settings.gradle", "settings.gradle.kts"):
        candidate = os.path.join(android_dir, name)
        if os.path.isfile(candidate):
            settings_path = candidate
            break
    if settings_path is None:
        return "skipped (android/settings.gradle not found)"

    with open(settings_path, encoding="utf-8") as f:
        settings_text = f.read()
    with open(app_gradle_path, encoding="utf-8") as f:
        app_text = f.read()

    json_path = os.path.join(os.path.dirname(app_gradle_path), "google-services.json")
    if "com.google.gms.google-services" in settings_text and "com.google.gms.google-services" in app_text:
        return "already set up"

    options = read_android_firebase_options(root)
    if options is None:
        return "skipped (could not read the Android block of lib/firebase_options.dart)"

    # settings.gradle(.kts): declare the plugin (apply false) next to the Android one
    m_settings = re.search(
        r'\n([ \t]*)id\s*(\()?\s*["\']com\.android\.application["\']\s*\)?\s+version\s+["\'][^"\']+["\']\s+apply\s+false',
        settings_text,
    )
    # app/build.gradle(.kts): apply the plugin right after the Android application plugin
    m_app = re.search(r'\n([ \t]*)id[ \t]*(\()?[ \t]*["\']com\.android\.application["\'][ \t]*\)?', app_text)
    if not m_settings or not m_app:
        return "skipped (the Gradle files look different from the expected Flutter 3.24 template)"

    def line_for(match, with_version):
        indent, paren = match.group(1), match.group(2)
        if paren:
            body = 'id("com.google.gms.google-services")'
            if with_version:
                body += ' version "%s" apply false' % GMS_PLUGIN_VERSION
        else:
            body = 'id "com.google.gms.google-services"'
            if with_version:
                body += ' version "%s" apply false' % GMS_PLUGIN_VERSION
        return "\n" + indent + body

    if "com.google.gms.google-services" not in settings_text:
        settings_text = settings_text[: m_settings.end()] + line_for(m_settings, True) + settings_text[m_settings.end():]
    if "com.google.gms.google-services" not in app_text:
        app_text = app_text[: m_app.end()] + line_for(m_app, False) + app_text[m_app.end():]

    # everything matched - now write (json first, so a plugin is never applied without it)
    with open(json_path, "w", encoding="utf-8") as f:
        f.write(build_google_services_json(options))
    with open(settings_path, "w", encoding="utf-8") as f:
        f.write(settings_text)
    with open(app_gradle_path, "w", encoding="utf-8") as f:
        f.write(app_text)
    return "done (google-services.json created + plugin %s applied)" % GMS_PLUGIN_VERSION


def setup_release_signing(android_dir, app_gradle_path, is_kts):
    """Optional step 6. Only runs if android/key.properties exists (written
    by the GitHub Actions workflow from repo secrets, or created by hand for
    a local build - see production-app-guide/RELEASE_SIGNING.md). Wires up a
    real release signing config so every build - local or GitHub Actions -
    uses the SAME signing key, which lets a new APK install straight over an
    older one. Without key.properties, nothing is touched and release builds
    keep using the debug key exactly as before. Never leaves things half
    applied: any unexpected template shape and this step is skipped with an
    explanation, same spirit as setup_google_services() above."""
    key_props_path = os.path.join(android_dir, "key.properties")
    if not os.path.isfile(key_props_path):
        return "skipped (android/key.properties not found - release still signed with the debug key)"

    with open(app_gradle_path, encoding="utf-8") as f:
        text = f.read()

    if "keystoreProperties" in text:
        return "already set up"

    # locate buildTypes { release { ... } } - assumes no braces inside it,
    # true for the stock Flutter template this script targets everywhere else
    m_release = re.search(r'release\s*\{([^{}]*)\}', text)
    if not m_release:
        return "skipped (could not find the release{} build type in build.gradle)"
    release_body = m_release.group(1)

    signing_ref = 'signingConfigs.getByName("release")' if is_kts else 'signingConfigs.release'
    assign = 'signingConfig = ' if is_kts else 'signingConfig '

    if "signingConfig" in release_body:
        new_release_body, n_ref = re.subn(
            r'signingConfig\s*=?\s*signingConfigs\.\w+(?:\([^)]*\))?',
            assign + signing_ref,
            release_body,
            count=1,
        )
        if n_ref == 0:
            return "skipped (release{} has an unexpected signingConfig line - set it to %s by hand)" % signing_ref
    else:
        new_release_body = release_body.rstrip() + "\n            " + assign + signing_ref + "\n        "

    text = text[: m_release.start(1)] + new_release_body + text[m_release.end(1):]

    m_android = re.search(r'\nandroid\s*\{', text)
    if not m_android:
        return "skipped (could not find the android { } block)"

    if is_kts:
        signing_configs_block = (
            "\n    signingConfigs {\n"
            '        create("release") {\n'
            '            keyAlias = keystoreProperties["keyAlias"] as String\n'
            '            keyPassword = keystoreProperties["keyPassword"] as String\n'
            '            storeFile = file(keystoreProperties["storeFile"] as String)\n'
            '            storePassword = keystoreProperties["storePassword"] as String\n'
            "        }\n"
            "    }\n"
        )
        loader = (
            "val keystoreProperties = java.util.Properties()\n"
            'val keystorePropertiesFile = rootProject.file("key.properties")\n'
            "if (keystorePropertiesFile.exists()) {\n"
            "    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))\n"
            "}\n\n"
        )
    else:
        signing_configs_block = (
            "\n    signingConfigs {\n"
            "        release {\n"
            '            keyAlias keystoreProperties["keyAlias"]\n'
            '            keyPassword keystoreProperties["keyPassword"]\n'
            '            storeFile keystoreProperties["storeFile"] ? file(keystoreProperties["storeFile"]) : null\n'
            '            storePassword keystoreProperties["storePassword"]\n'
            "        }\n"
            "    }\n"
        )
        loader = (
            "def keystoreProperties = new Properties()\n"
            'def keystorePropertiesFile = rootProject.file("key.properties")\n'
            "if (keystorePropertiesFile.exists()) {\n"
            "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
            "}\n\n"
        )

    text = text[: m_android.end()] + signing_configs_block + text[m_android.end():]
    text = text[: m_android.start()] + "\n" + loader + text[m_android.start():]

    with open(app_gradle_path, "w", encoding="utf-8") as f:
        f.write(text)
    return "done (release build now signed with android/upload-keystore.jks)"


def _bump_version_in_file(path, name_pattern, target_version, label):
    """Finds `name_pattern version "X.Y.Z"` (Groovy or Kotlin DSL, quotes
    either style) in the file at path and raises it to target_version if it
    is currently lower. Returns a one-line status string; never raises."""
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8") as f:
        text = f.read()
    pattern = name_pattern + r'["\']\)?\s*version\s*["\']([\d.]+)["\']'
    m = re.search(pattern, text)
    if not m:
        return None
    current = tuple(int(p) for p in m.group(1).split("."))
    target = tuple(int(p) for p in target_version.split("."))
    if current >= target:
        return "%s already up to date (%s)" % (label, m.group(1))
    new_text = text[: m.start(1)] + target_version + text[m.end(1):]
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_text)
    return "%s %s -> %s" % (label, m.group(1), target_version)


def bump_gradle_toolchain(android_dir):
    """Step 0 - always runs. A freshly generated project's Android Gradle
    Plugin (AGP) / Kotlin plugin / Gradle wrapper versions can lag behind
    what current JDKs and Kotlin need, which shows up as build failures like
    "[!] Your project requires a newer version of the Kotlin Gradle plugin"
    or "Android Gradle Plugin Version Incompatible with Kotlin Gradle
    Plugin". This bumps all three together to a combination Google's own
    compatibility table confirms works with JDK 17:
      AGP 8.3.2 (JDK 17 is its own minimum) needs Gradle >= 8.4 -> use 8.6
      Kotlin 2.1.20 needs AGP >= 7.3.1, comfortably met by 8.3.2
    Only ever raises versions, never lowers them, and is safe to run again."""
    AGP_VERSION = "8.3.2"
    KOTLIN_VERSION = "2.1.20"
    GRADLE_WRAPPER_VERSION = "8.6"
    results = []

    for rel in ("settings.gradle", "settings.gradle.kts"):
        path = os.path.join(android_dir, rel)
        r = _bump_version_in_file(path, r'com\.android\.application', AGP_VERSION, "AGP")
        if r:
            results.append(r + " in " + rel)
        r = _bump_version_in_file(path, r'org\.jetbrains\.kotlin\.android', KOTLIN_VERSION, "kotlin plugin")
        if r:
            results.append(r + " in " + rel)

    wrapper_path = os.path.join(android_dir, "gradle", "wrapper", "gradle-wrapper.properties")
    if os.path.isfile(wrapper_path):
        with open(wrapper_path, encoding="utf-8") as f:
            wtext = f.read()
        m = re.search(r'gradle-([\d.]+)-(all|bin)\.zip', wtext)
        if m:
            current = tuple(int(p) for p in m.group(1).split("."))
            target = tuple(int(p) for p in GRADLE_WRAPPER_VERSION.split("."))
            if current >= target:
                results.append("gradle wrapper already up to date (%s)" % m.group(1))
            else:
                new_wtext = (
                    wtext[: m.start(1)] + GRADLE_WRAPPER_VERSION + wtext[m.end(1):]
                )
                with open(wrapper_path, "w", encoding="utf-8") as f:
                    f.write(new_wtext)
                results.append("gradle wrapper %s -> %s" % (m.group(1), GRADLE_WRAPPER_VERSION))

    if not results:
        return "skipped (could not find AGP/kotlin plugin lines or gradle-wrapper.properties)"
    return "; ".join(results)


def main():
    root = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.getcwd()
    android_app = os.path.join(root, "android", "app")

    # 0) Android Gradle Plugin / Kotlin plugin / Gradle wrapper versions ----
    try:
        toolchain_status = bump_gradle_toolchain(os.path.join(root, "android"))
    except Exception as exc:  # never break the whole build because of an optional step
        toolchain_status = "skipped (%s)" % exc

    gradle = None
    for name in ("build.gradle", "build.gradle.kts"):
        candidate = os.path.join(android_app, name)
        if os.path.isfile(candidate):
            gradle = candidate
            break
    if gradle is None:
        print("ERROR: android/app/build.gradle not found in: " + root)
        print("Run `flutter create --platforms=android .` first, then run this script again.")
        return 1

    is_kts = gradle.endswith(".kts")
    with open(gradle, encoding="utf-8") as f:
        text = f.read()

    # 1) application id ---------------------------------------------------
    text, n_app = re.subn(
        r'applicationId\s*=?\s*["\'][^"\']*["\']',
        'applicationId = "%s"' % APP_ID,
        text,
        count=1,
    )

    # 2) minimum Android version -----------------------------------------
    max_expr = "maxOf(flutter.minSdkVersion, %d)" % MIN_SDK if is_kts else "Math.max(flutter.minSdkVersion, %d)" % MIN_SDK
    text, n_min = re.subn(
        r'(minSdk(?:Version)?\s*=?\s*)flutter\.minSdkVersion',
        lambda m: m.group(1) + max_expr,
        text,
        count=1,
    )
    if n_min == 0:
        # a fixed number such as "minSdkVersion 21"
        def bump(m):
            return m.group(1) + str(max(int(m.group(2)), MIN_SDK))

        text, n_min = re.subn(r'(minSdk(?:Version)?\s*=?\s*)(\d+)', bump, text, count=1)
    already_ok = ("Math.max(flutter.minSdkVersion" in text) or ("maxOf(flutter.minSdkVersion" in text)

    with open(gradle, "w", encoding="utf-8") as f:
        f.write(text)

    # 3) manifest ------------------------------------------------------------
    manifest_dst = os.path.join(android_app, "src", "main", "AndroidManifest.xml")
    manifest_src = os.path.join(os.path.dirname(os.path.abspath(__file__)), "AndroidManifest.xml")
    manifest_ok = False
    if os.path.isfile(manifest_src):
        os.makedirs(os.path.dirname(manifest_dst), exist_ok=True)
        shutil.copyfile(manifest_src, manifest_dst)
        manifest_ok = True
    elif os.path.isfile(manifest_dst):
        with open(manifest_dst, encoding="utf-8") as f:
            mtext = f.read()
        mtext = re.sub(r'\s+package="[^"]*"', "", mtext, count=1)
        with open(manifest_dst, "w", encoding="utf-8") as f:
            f.write(mtext)

    # 4) launcher icon (the phone's app-drawer icon) ------------------------
    icons_src = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
    icons_done = 0
    if os.path.isdir(icons_src):
        for density in sorted(os.listdir(icons_src)):
            src_png = os.path.join(icons_src, density, "ic_launcher.png")
            if density.startswith("mipmap-") and os.path.isfile(src_png):
                dst_dir = os.path.join(android_app, "src", "main", "res", density)
                os.makedirs(dst_dir, exist_ok=True)
                shutil.copyfile(src_png, os.path.join(dst_dir, "ic_launcher.png"))
                icons_done += 1

    # 5a) small white status-bar icon for push notifications --------------
    notify_src = os.path.join(os.path.dirname(os.path.abspath(__file__)), "notify_icons")
    notify_done = 0
    if os.path.isdir(notify_src):
        for density in sorted(os.listdir(notify_src)):
            src_png = os.path.join(notify_src, density, "ic_stat_notify.png")
            if density.startswith("drawable-") and os.path.isfile(src_png):
                dst_dir = os.path.join(android_app, "src", "main", "res", density)
                os.makedirs(dst_dir, exist_ok=True)
                shutil.copyfile(src_png, os.path.join(dst_dir, "ic_stat_notify.png"))
                notify_done += 1
    if notify_done and os.path.isfile(manifest_dst):
        with open(manifest_dst, encoding="utf-8") as f:
            mtext = f.read()
        if "default_notification_icon" not in mtext and "</application>" in mtext:
            meta = (
                '        <meta-data\n'
                '            android:name="com.google.firebase.messaging.default_notification_icon"\n'
                '            android:resource="@drawable/ic_stat_notify" />\n'
                '    </application>'
            )
            mtext = mtext.replace("</application>", meta, 1)
            with open(manifest_dst, "w", encoding="utf-8") as f:
                f.write(mtext)

    # 5b) Firebase google-services (push notifications when the app is closed)
    try:
        gms_status = setup_google_services(root, os.path.join(root, "android"), gradle)
    except Exception as exc:  # never break the whole build because of an optional step
        gms_status = "skipped (%s)" % exc

    # 6) Real release signing key (only if android/key.properties exists)
    try:
        signing_status = setup_release_signing(os.path.join(root, "android"), gradle, is_kts)
    except Exception as exc:  # never break the whole build because of an optional step
        signing_status = "skipped (%s)" % exc

    print("Patched: " + gradle)
    print("  gradle toolchain  -> %s" % toolchain_status)
    print("  applicationId  -> %s   [%s]" % (APP_ID, "done" if n_app else "NOT FOUND - set it by hand"))
    print("  minSdk         -> at least %d   [%s]" % (MIN_SDK, "done" if (n_min or already_ok) else "NOT FOUND - set it by hand"))
    print("  AndroidManifest.xml -> %s" % ("replaced with the correct one" if manifest_ok else "left as it was (tools/AndroidManifest.xml missing)"))
    print("  launcher icon  -> %s" % ("logo set (%d sizes)" % icons_done if icons_done else "left as the default Flutter icon (tools/icons missing)"))
    print("  notification icon -> %s" % ("set (%d sizes)" % notify_done if notify_done else "not set (tools/notify_icons missing)"))
    print("  google-services   -> %s" % gms_status)
    print("  release signing   -> %s" % signing_status)
    if not n_app or not (n_min or already_ok):
        print("")
        print("MANUAL STEP: open android/app/build.gradle and set:")
        print('    applicationId "%s"   and   minSdkVersion %d' % (APP_ID, MIN_SDK))
    return 0


if __name__ == "__main__":
    sys.exit(main())
