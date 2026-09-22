# NET77 for Android and iOS

Flutter app that opens https://net77.cc/ in a native Android WebView / iOS WKWebView.

## Features

- Rejects new windows and popunders. Trusted site links with `target="_blank"` open in the existing view when intercepted by the page script.
- Restricts top-level browsing to HTTPS net77.cc and its subdomains. Other domains are permitted as embedded video frames, except known ad hosts.
- Filters a small, editable list of advertising domains using native content blockers.
- Enables native video controls and fullscreen playback. Tap the player's fullscreen button; rotate the phone for landscape. App controls hide during native fullscreen and return on exit.
- Back, home, reload, expanded-page view, progress indicator, and retry after network/HTTP errors or renderer termination.

Fullscreen playback requires a user gesture. The toolbar's expand button expands the whole page; the video's own fullscreen button expands the video.

## Run and build

Use Flutter 3.44 / Dart 3.12 or compatible newer versions.

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d <android-or-ios-device-id>
flutter build apk --debug
```

Android APK: `build/app/outputs/flutter-apk/app-debug.apk`.

For iOS, on a Mac with Xcode and CocoaPods:

```sh
flutter pub get
flutter build ios --simulator
# For a signed device build, choose your team in Runner's Signing & Capabilities:
open ios/Runner.xcworkspace
flutter build ipa
```

The iOS deployment target is 13.0. The WebView dependency currently uses CocoaPods; the Podfile and xcconfig includes are provided. Flutter integrates the pods during the iOS build. iOS cannot be compiled on Windows.

This project still uses the generated `com.example.net77` application identifiers and Android debug signing. Configure your own identifiers and release signing before distributing a production build.

## Filter maintenance and limitations

Edit `trustedHosts` and `adHosts` in `lib/web_policy.dart`. Add a verified site redirect domain to `trustedHosts` if the site changes domains. Avoid adding video CDNs to `adHosts`.

Ad blocking is best effort: this is a curated domain list, not a comprehensive subscription filter. First-party ads, newly rotated advertising hosts, and ads embedded in a video stream may remain. Unknown top-level redirects and all native new-window requests are rejected. Native Android navigation callbacks do not cover every POST redirect. The count in the protection panel counts native rejected navigations only, not blocked resources or JavaScript-suppressed popups.

Third-party login flows that require external pages/new windows are intentionally unavailable with this single-site policy. No certificate bypass or broad insecure HTTP exception is configured. Website availability, DRM, codecs, iframe permissions, and anti-WebView restrictions can affect playback.

Implementation reference: https://inappwebview.dev/docs/webview/in-app-webview/ and https://inappwebview.dev/docs/webview/content-blockers/.

## Device verification checklist

1. Open the home page, browse to a title, navigate back, reload, and return home.
2. Tap a play button that normally opens an ad; confirm no other tab/app appears.
3. Start a video, enter fullscreen, rotate, and exit using the player's control or Android Back. Confirm playback and app controls recover.
4. Repeat for third-party iframe players on Android and iPhone.
5. Disconnect networking, reload, reconnect, and retry.

Automated tests cover navigation filtering, domain-boundary matching, embedded media exceptions, and the app's protection information. Real-site video playback and iOS behavior need device verification; the initial automated site inspection returned HTTP 403.
