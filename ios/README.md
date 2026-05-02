# Kaden Racing — iOS (App Store)

The iOS app is **100% Swift**: **SwiftUI** for menus and HUD, **SceneKit** for the 3D track and cars. There is no `WKWebView` in the product target. Regenerate the Xcode project after structural changes: `cd ios && xcodegen generate`.

## Project layout (`KadenRacing/`)

| Folder | Purpose |
|--------|---------|
| **`App/`** | App entry point (`KadenRacingApp.swift`) and root view (`ContentView.swift`). |
| **`Game/`** | SceneKit runtime: `NativeRaceEngine`, `TrackSpline`, `SceneKitRaceView`. |
| **`Models/`** | Domain types and static data (`GameDefinitions` — cars, tracks, `GameRouteMode`, etc.). |
| **`Views/`** | SwiftUI screens, navigation, and session state (`NativeScreens`, `GameFlowState`). |
| **`Resources/`** | `Info.plist`, `PrivacyInfo.xcprivacy`, `LaunchScreen.storyboard`, `Assets.xcassets` (app icon + menu background image). |
| **`WebBundle/`** *(optional, excluded from target)* | Legacy HTML/JS assets only if you keep them for reference; not shipped in the app bundle. |

---

## Already included (technical App Store requirements)

| Item | Status |
|------|--------|
| **App Icon** | `Resources/Assets.xcassets` — single 1024×1024 **universal** iOS icon; Xcode generates device sizes |
| **Launch screen** | `Resources/LaunchScreen.storyboard` — black full-screen (all devices) |
| **Privacy manifest** | `Resources/PrivacyInfo.xcprivacy` — not tracking; no native data collection (update if you add SDKs) |
| **Export compliance (encryption)** | `ITSAppUsesNonExemptEncryption` = **NO** in `Resources/Info.plist` (App Store Connect encryption question) |
| **App category** | `LSApplicationCategoryType` = **Games** |
| **Versioning** | `CFBundleShortVersionString` (marketing) + `CFBundleVersion` (build) — bump for each App Store upload |
| **Device** | iPhone + iPad (`TARGETED_DEVICE_FAMILY`), **arm64** |
| **Orientation** | iPhone & iPad: **all four** (portrait, upside-down, both landscapes) in `Resources/Info.plist` |

**1024 App Store icon:** must have **no alpha channel**. If App Store Connect rejects the icon, re-export the PNG as opaque (e.g. flatten on a background in an image editor).

---

## You must provide in App Store Connect (listing)

These are **not** in the repo; Apple requires them at submission time.

| Field | Notes |
|------|--------|
| **Apple Developer Program** | Paid membership, agreements active |
| **App record** | Unique **Bundle ID** (match Xcode → Signing & Capabilities) |
| **Privacy Policy URL** | **Required** for most apps; host a simple page describing data practices for the **website** loaded in the WebView (cookies, localStorage, analytics if any) |
| **Support URL** | A contact or help page (can be the same site as the game, different path) |
| **Screenshots** | Required sizes for **6.7"**, **6.5"** (and others per Apple’s current list). Capture from Simulator or device (game plays in any orientation) |
| **Copyright / trade name** | e.g. `© 2026 Your Name` |
| **Age rating** | Complete the questionnaire (racing / mild violence, etc. as appropriate) |
| **App Privacy** | Nutrition labels: declare what the **loaded web content** may collect (or “Data Not Collected” only if truly accurate). Align with your Privacy Policy. |

**Export compliance wizard:** If you only use HTTPS like this app, answers typically match **“No”** to custom encryption and standard TLS — consistent with `ITSAppUsesNonExemptEncryption` = false.

---

## Build & upload

1. **Xcode 15+**, open `KadenRacing.xcodeproj` (or run `xcodegen generate` in this folder if you use `project.yml`).
2. **Signing:** select your **Team**; set a unique **Bundle ID** if you change it from `com.kaden.racing.championships`.
3. **Increment** build (`CFBundleVersion`) / version (`CFBundleShortVersionString`) in `Resources/Info.plist` (or target **General** in Xcode) for every upload.
4. **Product → Archive** → **Distribute App** → **App Store Connect**.

```bash
cd ios
xcodegen generate   # optional, if you edit project.yml
open KadenRacing.xcodeproj
```

---

## App Review tips (native game / 4.2)

- **Guideline 4.2 (Minimum Functionality):** the **SceneKit** racing experience should be a real, playable product on device.
- In **App Review Information**, you can note: *“Racing game implemented in SwiftUI + SceneKit; no third-party game engine required; works offline.”*
- **Demo account:** not required for a game with no login.
- Test on **cellular** and **Wi‑Fi** if you add networking later (analytics, multiplayer, etc.).

---

## Offline behavior

The app does not require network access for core gameplay. All code and art used in the binary ship in the app bundle (`App`, `Game`, `UI`, `Resources`). A separate **web** build of the game (repo root `index.html`) can still be hosted (e.g. Vercel) for browsers; that is independent of the iOS target.

---

## Regenerating the Xcode project

If you change `project.yml`:

```bash
cd ios
xcodegen generate
```

---

## Privacy manifest & your website

`Resources/PrivacyInfo.xcprivacy` covers **native** code only (currently: no tracking, no collected data types). Declare any additional practices in **App Store Connect → App Privacy** and your public **Privacy Policy** URL. If you add ads or analytics SDKs to the iOS target, update the manifest and labels.
