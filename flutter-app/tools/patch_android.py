#!/usr/bin/env python3
"""
Yash Study Hub - one-time Android setup helper.

Run it ONCE right after `flutter create` has generated the android/ folder
(the GitHub build workflow runs it automatically):

    python3 tools/patch_android.py            (from the flutter-app folder)
    python3 tools/patch_android.py <folder>   (or give the project folder)

What it does (safe to run again and again):
  1. Sets the app id to  com.yashstudyhub.app  (must match Firebase).
  2. Makes sure the minimum Android version (minSdk) is at least 23, which
     the Firebase libraries need.
  3. Puts the correct AndroidManifest.xml in place (permissions, links,
     no screen-orientation lock so video fullscreen can rotate).
  4. Replaces the default Flutter launcher icon with the Yash Study Hub logo
     (ready-made PNGs in tools/icons/mipmap-*/).
  0. (Runs first) Works around a long-standing bug in some OLDER Flutter
     plugins: their own android/build.gradle (published by the plugin
     author, not us) reads compileSdkVersion the old way and crashes with
     "compileSdkVersion is not specified" against a current Flutter SDK.
     Seen so far in package_info_plus and wakelock_plus, but it can hit any
     old-enough plugin - this makes the value available everywhere such a
     plugin might look for it, so the next one also finds it.
  5. Push notifications: a small white status-bar icon (tools/notify_icons/)
     and the standard Firebase "google-services" setup (google-services.json
     is generated from lib/firebase_options.dart, so there is one source of
     truth). If anything about the Gradle files looks unexpected, step 5b is
     skipped completely - nothing is half-applied.
  6. STABLE SIGNING: if the CI workflow has already written
     android/key.properties (from the ANDROID_KEYSTORE_BASE64 /
     ANDROID_KEYSTORE_PASSWORD secrets), release builds are signed with that
     same key every time, so a new APK installs as an UPDATE over the old
     one instead of needing an uninstall. Purely additive - if key.properties
     is missing, nothing changes and the release build signs with the debug
     key exactly as before.
  7. Bumps the Kotlin Gradle plugin version (see KOTLIN_VERSION above) -
     the Firebase SDK versions this app depends on need a newer Kotlin than
     the one Flutter 3.24's own template ships by default.

It never touches lib/, pubspec.yaml or assets/.
"""
import os
import re
import shutil
import sys

APP_ID = "com.yashstudyhub.app"
MIN_SDK = 23
COMPAT_SDK = 34  # same number this project's own compileSdk resolves to


GMS_PLUGIN_VERSION = "4.4.2"  # 4.3.x can crash under AGP 8+ (Flutter 3.24 uses AGP 8); 4.4.x is the AGP-8-safe line
KOTLIN_VERSION = "1.9.24"  # the Firebase SDK versions this app uses need a newer Kotlin than the Flutter 3.24 template ships


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


def patch_legacy_plugin_compat(root):
    """Step 0 (see module docstring). Returns a short status string."""
    touched = []

    # A) android/local.properties - the flat "flutter.xVersion=NN" lines
    #    some old plugins still read directly, instead of the modern
    #    `flutter.compileSdkVersion` Gradle extension.
    local_props = os.path.join(root, "android", "local.properties")
    if os.path.isfile(local_props):
        with open(local_props, encoding="utf-8") as f:
            text = f.read()
        needed = {
            "flutter.compileSdkVersion": str(COMPAT_SDK),
            "flutter.targetSdkVersion": str(COMPAT_SDK),
            "flutter.minSdkVersion": str(MIN_SDK),
        }
        added = False
        for key, value in needed.items():
            if not re.search(r"(?m)^%s=" % re.escape(key), text):
                if text and not text.endswith("\n"):
                    text += "\n"
                text += "%s=%s\n" % (key, value)
                added = True
        if added:
            with open(local_props, "w", encoding="utf-8") as f:
                f.write(text)
            touched.append("local.properties")

    # B) android/build.gradle(.kts) - the ROOT one (android/app has its own,
    #    untouched by this). Old plugins also look here, via
    #    rootProject.ext.compileSdkVersion. Root project code runs before
    #    any plugin subproject is configured, so plain numbers set at the
    #    very top are visible to every plugin by the time it evaluates.
    root_gradle = None
    for name in ("build.gradle", "build.gradle.kts"):
        candidate = os.path.join(root, "android", name)
        if os.path.isfile(candidate):
            root_gradle = candidate
            break
    if root_gradle is not None:
        with open(root_gradle, encoding="utf-8") as f:
            text = f.read()
        if "YASH_STUDY_HUB_LEGACY_PLUGIN_COMPAT" not in text:
            if root_gradle.endswith(".kts"):
                block = (
                    "// YASH_STUDY_HUB_LEGACY_PLUGIN_COMPAT: some older plugins read these\n"
                    "// old-style values instead of the modern flutter.compileSdkVersion API.\n"
                    "extra[\"compileSdkVersion\"] = %d\n"
                    "extra[\"targetSdkVersion\"] = %d\n"
                    "extra[\"minSdkVersion\"] = %d\n\n"
                ) % (COMPAT_SDK, COMPAT_SDK, MIN_SDK)
            else:
                block = (
                    "// YASH_STUDY_HUB_LEGACY_PLUGIN_COMPAT: some older plugins read these\n"
                    "// old-style values instead of the modern flutter.compileSdkVersion API.\n"
                    "ext {\n"
                    "    compileSdkVersion = %d\n"
                    "    targetSdkVersion = %d\n"
                    "    minSdkVersion = %d\n"
                    "}\n\n"
                ) % (COMPAT_SDK, COMPAT_SDK, MIN_SDK)
            with open(root_gradle, "w", encoding="utf-8") as f:
                f.write(block + text)
            touched.append(os.path.basename(root_gradle))

    if not touched:
        return "already in place"
    return "added to " + " + ".join(touched)


def setup_release_signing(gradle, is_kts):
    """Step 6 (see module docstring). Purely additive: adds a `release`
    signingConfig, and only actually assigns it to buildTypes.release when
    android/key.properties exists at BUILD time. Never edits or removes
    anything the file already has, so a missing key.properties (secrets not
    added yet) leaves today's working debug-signed build untouched."""
    with open(gradle, encoding="utf-8") as f:
        text = f.read()
    if "YASH_STUDY_HUB_RELEASE_SIGNING" in text:
        return "already in place"

    if is_kts:
        signing_configs_block = (
            "\n    signingConfigs {\n"
            "        create(\"release\") {\n"
            "            val keyPropsFile = rootProject.file(\"key.properties\")\n"
            "            if (keyPropsFile.exists()) {\n"
            "                val keystoreProperties = java.util.Properties()\n"
            "                keystoreProperties.load(java.io.FileInputStream(keyPropsFile))\n"
            "                keyAlias = keystoreProperties[\"keyAlias\"]\n"
            "                keyPassword = keystoreProperties[\"keyPassword\"]\n"
            "                storeFile = rootProject.file(keystoreProperties[\"storeFile\"])\n"
            "                storePassword = keystoreProperties[\"storePassword\"]\n"
            "            }\n"
            "        }\n"
            "    }\n"
        )
        wire_up = (
            "\n// YASH_STUDY_HUB_RELEASE_SIGNING: only takes effect once the CI workflow\n"
            "// has written key.properties from the ANDROID_KEYSTORE_* secrets; until then\n"
            "// this block does nothing and the usual debug-signed build is unchanged.\n"
            "if (rootProject.file(\"key.properties\").exists()) {\n"
            "    android.buildTypes.getByName(\"release\").signingConfig = android.signingConfigs.getByName(\"release\")\n"
            "}\n"
        )
    else:
        signing_configs_block = (
            "\n    signingConfigs {\n"
            "        release {\n"
            "            def keyPropsFile = rootProject.file(\"key.properties\")\n"
            "            if (keyPropsFile.exists()) {\n"
            "                def keystoreProperties = new Properties()\n"
            "                keystoreProperties.load(new FileInputStream(keyPropsFile))\n"
            "                keyAlias keystoreProperties[\"keyAlias\"]\n"
            "                keyPassword keystoreProperties[\"keyPassword\"]\n"
            "                storeFile rootProject.file(keystoreProperties[\"storeFile\"])\n"
            "                storePassword keystoreProperties[\"storePassword\"]\n"
            "            }\n"
            "        }\n"
            "    }\n"
        )
        wire_up = (
            "\n// YASH_STUDY_HUB_RELEASE_SIGNING: only takes effect once the CI workflow\n"
            "// has written key.properties from the ANDROID_KEYSTORE_* secrets; until then\n"
            "// this block does nothing and the usual debug-signed build is unchanged.\n"
            "if (rootProject.file(\"key.properties\").exists()) {\n"
            "    android.buildTypes.release.signingConfig = android.signingConfigs.release\n"
            "}\n"
        )

    new_text, n = re.subn(r"(android\s*\{)", lambda m: m.group(1) + signing_configs_block, text, count=1)
    if not n:
        return "skipped (could not find the android {} block)"
    new_text = new_text.rstrip("\n") + "\n" + wire_up
    with open(gradle, "w", encoding="utf-8") as f:
        f.write(new_text)
    return "added (signs releases with key.properties when present)"


def bump_kotlin_version(root):
    """Step 7 (see module docstring). Raises the Kotlin Gradle plugin version
    wherever this project's generated files declare one, so it is new enough
    for the Firebase SDK versions in pubspec.yaml. Purely a version-number
    swap - nothing else in these files is touched."""
    touched = []

    # Modern style (Flutter 3.19+): android/settings.gradle(.kts)
    #   id "org.jetbrains.kotlin.android" version "1.9.10" apply false
    for name in ("settings.gradle", "settings.gradle.kts"):
        path = os.path.join(root, "android", name)
        if not os.path.isfile(path):
            continue
        with open(path, encoding="utf-8") as f:
            text = f.read()
        new_text, n = re.subn(
            r'(id\s*\(?\s*["\']org\.jetbrains\.kotlin\.android["\']\s*\)?\s+version\s+["\'])[^"\']+(["\'])',
            lambda m: m.group(1) + KOTLIN_VERSION + m.group(2),
            text,
        )
        if n:
            with open(path, "w", encoding="utf-8") as f:
                f.write(new_text)
            touched.append(name)

    # Older style (pre-3.19 templates, kept as a fallback): root
    # android/build.gradle(.kts) with a plain ext.kotlin_version assignment.
    for name in ("build.gradle", "build.gradle.kts"):
        path = os.path.join(root, "android", name)
        if not os.path.isfile(path):
            continue
        with open(path, encoding="utf-8") as f:
            text = f.read()
        if name.endswith(".kts"):
            pattern = r'(extra\[\s*["\']kotlin_version["\']\s*\]\s*=\s*["\'])[^"\']+(["\'])'
        else:
            pattern = r'(ext(?:\.kotlin_version|\[\s*["\']kotlin_version["\']\s*\])\s*=\s*["\'])[^"\']+(["\'])'
        new_text, n = re.subn(pattern, lambda m: m.group(1) + KOTLIN_VERSION + m.group(2), text)
        if n:
            with open(path, "w", encoding="utf-8") as f:
                f.write(new_text)
            touched.append(name)

    if not touched:
        return "skipped (no Kotlin version declaration found)"
    return "set to %s in %s" % (KOTLIN_VERSION, " + ".join(touched))


def main():
    root = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.getcwd()
    android_app = os.path.join(root, "android", "app")

    # Step 0, see module docstring and patch_legacy_plugin_compat() above.
    legacy_compat_status = patch_legacy_plugin_compat(root)
    kotlin_status = bump_kotlin_version(root)

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

    signing_status = setup_release_signing(gradle, is_kts)

    print("Patched: " + gradle)
    print("  old-plugin compileSdk fix -> %s" % legacy_compat_status)
    print("  Kotlin Gradle plugin      -> %s" % kotlin_status)
    print("  stable release signing    -> %s" % signing_status)
    print("  applicationId  -> %s   [%s]" % (APP_ID, "done" if n_app else "NOT FOUND - set it by hand"))
    print("  minSdk         -> at least %d   [%s]" % (MIN_SDK, "done" if (n_min or already_ok) else "NOT FOUND - set it by hand"))
    print("  AndroidManifest.xml -> %s" % ("replaced with the correct one" if manifest_ok else "left as it was (tools/AndroidManifest.xml missing)"))
    print("  launcher icon  -> %s" % ("logo set (%d sizes)" % icons_done if icons_done else "left as the default Flutter icon (tools/icons missing)"))
    print("  notification icon -> %s" % ("set (%d sizes)" % notify_done if notify_done else "not set (tools/notify_icons missing)"))
    print("  google-services   -> %s" % gms_status)
    if not n_app or not (n_min or already_ok):
        print("")
        print("MANUAL STEP: open android/app/build.gradle and set:")
        print('    applicationId "%s"   and   minSdkVersion %d' % (APP_ID, MIN_SDK))
    return 0


if __name__ == "__main__":
    sys.exit(main())
