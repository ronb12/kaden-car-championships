# Kaden Racing — iOS WebView shell (App Store)

The native app loads your hosted **HTML5 game** in `WKWebView` so you can **Archive** and submit to **App Store Connect**.

**Game URL:** set `GAME_WEB_URL` in `KadenRacing/Info.plist` (HTTPS). Default: `https://kaden-car-championships.vercel.app`.

---

## Already included (technical App Store requirements)

| Item | Status |
|------|--------|
| **App Icon** | `Assets.xcassets` — single 1024×1024 **universal** iOS icon (from `app-icon.png`); Xcode generates device sizes |
| **Launch screen** | `LaunchScreen.storyboard` — black full-screen (all devices) |
| **Privacy manifest** | `PrivacyInfo.xcprivacy` — not tracking; no native data collection (update if you add SDKs) |
| **Export compliance (encryption)** | `ITSAppUsesNonExemptEncryption` = **NO** in `Info.plist` — only standard HTTPS to your server (aligns with *“No*” in App Store Connect for standard encryption) |
| **App category** | `LSApplicationCategoryType` = **Games** |
| **Versioning** | `CFBundleShortVersionString` (marketing) + `CFBundleVersion` (build) — bump for each App Store upload |
| **Device** | iPhone + iPad (`TARGETED_DEVICE_FAMILY`), **arm64** |
| **Orientation** | iPhone & iPad: **all four** (portrait, upside-down, both landscapes) in `Info.plist` |

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
3. **Increment** build (`CFBundleVersion`) / version (`CFBundleShortVersionString`) in **Info.plist** (or target **General** in Xcode) for every upload.
4. **Product → Archive** → **Distribute App** → **App Store Connect**.

```bash
cd ios
xcodegen generate   # optional, if you edit project.yml
open KadenRacing.xcodeproj
```

---

## App Review tips (WebView / 4.2)

- **Guideline 4.2 (Minimum Functionality):** the **game in the browser** should be a real, playable product; the native binary is a shell.
- In **App Review Information**, explain: *“The app is a full-screen WebView that loads our game at [URL]. Network required.”*
- **Demo account:** not required unless your **web** game hide content behind login.
- Test on **cellular** and **Wi‑Fi**; load time should be acceptable.

---

## Offline behavior

The app **does not** embed `index.html`; the game is loaded from `GAME_WEB_URL`. If the device is offline, the user sees a blank or WebKit error page. For a better experience later, you can add a native “No connection” view in Swift (not implemented here).

---

## Regenerating the Xcode project

If you change `project.yml`:

```bash
cd ios
xcodegen generate
```

---

## Privacy manifest & your website

`PrivacyInfo.xcprivacy` covers **native** code only (currently: no tracking, no collected data types). Data handling by **JavaScript / your host** is declared in **App Store Connect App Privacy** and your **Privacy Policy**, not only in this file. If you add ads or analytics SDKs to the iOS target, update the manifest and labels.
