# Kaden Racing — iOS WebView shell (App Store)

This folder wraps the hosted **HTML5 game** in `WKWebView` so you can archive and submit to **App Store Connect**.

The game itself loads from **`GAME_WEB_URL`** in `KadenRacing/Info.plist` (HTTPS only). Default points at the Vercel project name `kaden-car-championships`; change it to your production domain if different.

## Requirements

- macOS with **Xcode 15+**
- Apple Developer Program membership ($99/yr) for App Store upload
- Valid **bundle identifier** (unique to your team), icons, and signing in Xcode

## Generate the Xcode project

Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) (one-time):

```bash
brew install xcodegen
```

From this `ios` directory:

```bash
cd ios
xcodegen generate
open KadenRacing.xcodeproj
```

If you prefer not to use XcodeGen: create a new **iOS App** in Xcode (SwiftUI, iOS 15), delete the template views, and add the Swift files from `KadenRacing/` manually; copy keys from `Info.plist` into the target’s Info tab.

## App icons

1. In Xcode: **Assets.xcassets → App Icon**.
2. Drag your **1024×1024** master (use `../app-icon.png` from the repo as source; Xcode can generate sizes or use an asset generator).

App Store Connect requires a 1024×1024 icon without alpha for the store listing.

## Configure URL & bundle ID

| Setting | Where |
|--------|--------|
| Game URL | `KadenRacing/Info.plist` → `GAME_WEB_URL` |
| Bundle ID | Xcode → Target → **Signing & Capabilities** (must match App Store Connect app record) |

Keep **HTTPS** so App Transport Security stays satisfied.

## Build for device / Archive

1. Select **Any iOS Device (arm64)** or a plugged-in iPhone.
2. **Product → Archive**.
3. **Distribute App** → App Store Connect.

## Privacy & compliance

- You load remote web content: declare **Privacy Nutrition** as appropriate (e.g. if the site sets cookies / analytics, disclose). If the game is first-party static hosting with no trackers, many teams select minimal data collection—confirm against your actual deployment.
- Ensure **audio**: Web Audio unlock on first tap is already handled in the web game; no extra native code required.

## App Review note

Apple sometimes scrutinizes **minimal WebView shells** (Guideline **4.2** — Minimum Functionality). Your shipped web game should be substantive; keep metadata accurate and ensure the app behaves well offline-start (clear error or splash), stable audio, and full-screen gameplay.

## Offline / errors

This shell **requires network access** to play. There is no bundled `index.html` copy; always ship after verifying `GAME_WEB_URL` loads on cellular Safari.

To bundle local HTML later, add files to the target and load `file://` URLs — not included here to avoid duplicating the live site.

## Orientation

Landscape is primary for gameplay (`Info.plist`). iPad allows all orientations for App Review flexibility; adjust if you want phone portrait.
