<div align="center">

  <img src="https://raw.githubusercontent.com/doodaddude/Phonebar/main/Support/AppIcon.png" width="128" height="128" alt="PhoneBar App Icon" style="border-radius: 28px; box-shadow: 0 10px 30px rgba(0,0,0,0.35);" />

  # PhoneBar for macOS

  ### *Your phone, floating natively on your Mac desktop.*

  [![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-black?style=for-the-badge&logo=apple)](https://github.com/doodaddude/Phonebar)
  [![Developer ID Signed](https://img.shields.io/badge/Signed-Developer%20ID-blue?style=for-the-badge&logo=apple)](https://github.com/doodaddude/Phonebar/releases)
  [![Release](https://img.shields.io/github/v/release/doodaddude/Phonebar?style=for-the-badge&color=success)](https://github.com/doodaddude/Phonebar/releases/latest)
  [![License](https://img.shields.io/badge/License-MIT-amber?style=for-the-badge)](LICENSE)

  <p align="center">
    <b>PhoneBar</b> brings a sleek, interactive mobile viewport to macOS. Designed with a custom frosted <i>Liquid Glass</i> aesthetic, floating bubble docks, and instant app switching: run your essential mobile apps, AI assistants, and video feeds without reaching for your phone.
  </p>

</div>

---

## 🌟 Key Highlights

- **🍫 Artisan Confectionery Design:** Styled with our signature *Classic Chocolate Bar Phone* icon with beveled chocolate block geometry and peel-back gold foil accents.
- **🫧 Liquid Glass Floating Docks:** Magnetic floating bubbles that dock anywhere along your screen edges with fluid velocity physics.
- **⚡️ Zero-Distraction Workflow:** Access mobile interfaces (Gemini, ChatGPT, Instagram, Messenger, TikTok, Tapo Cams, and custom links) directly from your menu bar or floating HUD.
- **🔏 Apple Developer ID Pre-Signed:** Hardened runtime, signed by Apple Developer ID (*Dakota Hilchey*) with full Gatekeeper compatibility.

---

## 📱 Features & Functions

### 1. Liquid Glass Menu Bar Hub
- **Status Bar Integration:** Compact lens & phone indicator living unobtrusively in your macOS menu bar.
- **One-Click Launcher:** Instantly reveals mobile app cards, device orientation switchers, and proxy/network status indicators.
- **Dynamic Height Adjustment:** Smoothly resize the menu bar flyout from the bottom edge; remembers your preferred height across reboots.

### 2. Floating "Bubble" App Dock
- **True Liquid Glass Physics:** Translucent glass bubbles with refractive highlights and subtle drop shadows.
- **Edge Snapping:** Magnetic suction points along screen borders with smooth spring animations that never fight cursor velocity.
- **Persistent Coordinates:** Remember exact custom coordinates when toggling apps open or closed: bubbles stay where you put them.
- **Live Favicon Cache:** Automatically queries and caches the high-res favicon for each active mobile web application.

### 3. Native Mobile Viewport Engine
- **Custom User-Agent & Device Emulation:** Runs web apps in authentic iPhone/Android mobile viewports with touch-gesture emulation.
- **Smart Keyboard Event Routing:** Pressing `Enter` automatically performs an instant chat submit on messaging and AI platforms (e.g. Gemini, ChatGPT) rather than adding an unexpected line break.
- **Ad & Tracker Blocking:** Built-in network rules to strip ad banners, trackers, and unnecessary mobile popups for clean viewing.

### 4. Advanced Privacy & Spoofing Toolkit
- **Geographic Location Spoofing:** Mock your GPS coordinates on a per-app basis for localized testing or regional content.
- **Proxy & Tor Network Tunneling:** Configure SOCKS5 or HTTP proxies directly inside the app for isolated network routes.
- **Multi-Account Container Profiles:** Isolated cookie and cache partitions per app card to keep personal, work, and secondary accounts separated.

---

## ⌨️ Shortcuts & Hotkeys

| Action | Shortcut | Behavior |
| :--- | :--- | :--- |
| **Toggle Phone Window** | `⌘ + ⇧ + P` | Show/hide the floating phone viewport |
| **Quick-Peek (Solid Focus)** | `Hold F1` | Instantly brings window to top at 100% solid opacity |
| **Release Quick-Peek** | `Release F1` | Immediately restores ghost/transparency level |
| **Reload Current App** | `⌘ + R` | Hard reload the active mobile viewport |
| **Preferences & Hotkeys** | `⌘ + ,` | Open multi-tab settings panel |
| **Close Active Bubble** | `⌘ + W` | Minimize floating viewport back into the bubble dock |

---

## 🚀 Installation

### Option 1: Direct Download (Pre-built & Signed)
1. Download the latest **[`PhoneBar-for-mac.zip`](https://github.com/doodaddude/Phonebar/releases/latest/download/PhoneBar-for-mac.zip)** from the Releases page.
2. Unzip and drag `PhoneBar.app` into your **Applications** folder:
   ```bash
   unzip PhoneBar-for-mac.zip -d /Applications/
   ```
3. Launch `PhoneBar` from Spotlight or Launchpad.

### Option 2: Build From Source (Swift Package Manager)
**Prerequisites:** macOS 13.0+ and Xcode Command Line Tools.

```bash
# Clone the repository
git clone https://github.com/doodaddude/Phonebar.git
cd Phonebar

# Package and sign the release build
./scripts/package_release.sh

# Launch the app
open build/PhoneBar.app
```

---

## 🛠️ Architecture & Tech Stack

```
PhoneBar/
├── Sources/PhoneBar/
│   ├── Models/               # WebAppConfig, DevicePreset, AccountProfile, SpoofProfile
│   ├── ViewModels/           # AppStore, WebViewModel (WebKit bridge & input routing)
│   ├── Views/                # MenuContentView, PhoneWebContainer (Liquid Glass UI)
│   ├── Windows/              # BubbleHubController, PhoneWindowController, WindowManager
│   └── Services/             # AdBlockService, FaviconService, ProxyService
├── Support/
│   ├── AppIcon.icns          # Multi-scale Retina Apple Iconset (Option 1 Chocolate Phone)
│   ├── Info.plist            # App metadata & microphone/camera usage strings
│   └── PhoneBar.entitlements # Sandboxed networking & audio/video permissions
└── scripts/
    ├── build_app.sh          # Swift compiler build pipeline
    └── package_release.sh    # Developer ID codesign & zip packager
```

- **Languages & Frameworks:** Swift 5.9+, SwiftUI, AppKit, WebKit.
- **Rendering:** CoreGraphics, NSVisualEffectView with `.underWindowBackground` blending.
- **Distribution:** Standalone macOS universal binary signed with Apple Developer ID.

---

## 🤝 Contributing

Contributions, feature suggestions, and bug reports are welcome!
1. Fork the Project.
2. Create your Feature Branch (`git checkout -b feature/NewFeature`).
3. Commit your Changes (`git commit -m 'Add NewFeature'`).
4. Push to the Branch (`git push origin feature/NewFeature`).
5. Open a Pull Request.

---

## 📄 License

Distributed under the **MIT License**. See `LICENSE` for more information.

<p align="center">
  Made with ☕️ and 🍫 by <a href="https://github.com/doodaddude"><b>Doodad Dude</b></a>
</p>
